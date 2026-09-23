#!/usr/bin/env python3
"""Fixed dual-site v5 gates: fresh PMA, then two external baselines. No retries."""
import argparse
import os
import sys
import time
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('stage', choices=('status', 'pma', 'external', 'optics-api', 'optics'))
args = parser.parse_args()
sys.path.insert(0, '/home/cms/25G')
from cm_interface.registry import Registry
from milestone3_12hour_external_soak import FpgaMailbox, read_lane, read_overview, print_platform_diagnostics

registry = Registry(setup='tf', dev_path='/dev/ttyUL4')
if args.stage == 'optics-api':
    # Read installed API definitions only; no module control/alarm access.
    import inspect
    from cm_interface.device import firefly
    print(inspect.getsource(firefly), flush=True)
    print(inspect.getsource(Registry), flush=True)
    print('REGISTRY_FIELDS ' + repr(sorted(vars(registry))), flush=True)
    for name in dir(Registry):
        if 'firefly' in name.lower():
            member = getattr(Registry, name)
            if inspect.isfunction(member):
                print(inspect.getsource(member), flush=True)
    raise SystemExit(0)
if args.stage == 'optics':
    # Fixed FireFly-1 endpoints, controls/identity/telemetry reads only.
    # Do not read clear-on-read alarms after TX shutdown or change pages.
    print('FIREFLY_LAYOUT ' + repr(registry.firefly_layout), flush=True)
    print('FIREFLY_NAMES ' + repr(sorted(registry.fireflies)), flush=True)
    from cm_interface.device.firefly import FireflyTx, FireflyRx
    # Installed tf preset is sparse and renumbers addresses. Use the physical
    # 20-endpoint map from Registry._populate_fireflies_generic instead.
    for site in ('F1', 'F2'):
        for direction in ('Tx', 'Rx'):
            name = site + '_1_' + direction
            address = (0x20 if site == 'F1' else 0x2a) + (direction == 'Rx')
            device = (FireflyTx if direction == 'Tx' else FireflyRx)(registry.uart, address, name)
            print('OPTICS %s class=%s address=%#x' % (name, type(device).__name__, device.address), flush=True)
            page = device.read_reg(127)[0]
            print('PAGE %d' % page, flush=True)
            if page != 0:
                raise RuntimeError('unexpected optics page; no page write permitted')
            print('PART ' + device.part_id, flush=True)
            print('TEMPERATURE %s %s' % (name, device.temperature), flush=True)
            for address, size in ((52, 2), (54, 2), (56, 2), (58, 2), (75, 2)):
                print('%s control_%02x=%s' % (name, address, device.read_reg(address, size=size).hex()), flush=True)
    raise SystemExit(0)
boxes = {site: FpgaMailbox(registry.fpgas[site]) for site in ('F1', 'F2')}
CAP = 1 << 20
ACTIVE = 1 << 17
EXPIRED = 1 << 18
REJECTED = 1 << 19

def check(condition, message):
    if not condition:
        raise RuntimeError(message)

def overview(site):
    box = boxes[site]
    print('\nSITE ' + site, flush=True)
    read_overview(box)
    print_platform_diagnostics(box)
    print('%s clock_status=%#010x' % (site, box.read_u32(0x9c)), flush=True)
    for register in range(2, 39):
        print('%s r%02d clock_khz=%d' % (site, register, box.read_u32(register * 4)), flush=True)

def ready(site, sequence, run):
    box = boxes[site]
    check(box.read_u32(0xc0) == 0x20304 and box.read_u32(0xc4) == 0x20304, site + ' wrong version')
    check(box.read_u32(0xc8) == CAP, site + ' not idle/session-off/clear')
    check(box.read_u32(0xa0) == sequence and box.read_u32(0xf0) == sequence and box.read_u32(0xf8) == run,
          site + ' wrong predecessor sequence/run')
    check(box.read_u32(0x9c) == 0x434da501, site + ' invalid clock monitor')
    for address, nominal in ((0x24, 100000), (0x28, 325000), (0x5c, 322266)):
        check(abs(box.read_u32(address) - nominal) < nominal * 0.001, site + ' required clock invalid')
    box.write_u32(0xcc, 0xfe)
    check(box.read_u32(0xd0) == 0x40 and box.read_u32(0xec) == 0, site + ' platform not healthy')
    prbs = box.read_u32(0xd4)
    check(prbs & 0x40000000 and not (prbs & 0x8000001f), site + ' controller not idle')

def submit(site, sequence, previous, command, duration):
    box = boxes[site]
    check(box.read_u32(0xa0) == previous and box.read_u32(0xf0) == previous, site + ' unexpected sequence')
    check(box.read_u32(0xc8) & 0x1ffff == 0, site + ' busy/fault before submit')
    for address, value in ((0xa4, command), (0xa8, duration), (0xac, 0),
                           (0xb0, 0xfff), (0xb4, 0), (0xb8, 0), (0xbc, 0)):
        box.write_u32(address, value)
        check(box.read_u32(address) == value, site + ' descriptor verification failed')
    # The sole doorbell write: never repeat it, including on transport failure.
    print('SUBMIT %s sequence=%d command=%#x duration_ms=%d' % (site, sequence, command, duration), flush=True)
    box.write_u32(0xa0, sequence)

def response(site, sequence, code, run, timeout=40):
    box = boxes[site]
    deadline = time.monotonic() + timeout
    while box.read_u32(0xf0) != sequence:
        check(time.monotonic() < deadline, site + ' bounded response timeout; no retry')
        time.sleep(0.05)
    check(box.read_u32(0xf4) == code and box.read_u32(0xf8) == run, site + ' response/run failure')

def clean_records(site, run):
    box = boxes[site]
    check(box.read_u32(0xfc) == 0xc0c01 and box.read_u32(0xf8) == run, site + ' summary/run mismatch')
    for lane in range(12):
        record = read_lane(box, lane)
        print('%s run=%d lane=%d %r' % (site, run, lane, record), flush=True)
        check(record['id_status'] == 0x1800 + lane and record['errors'] == 0 and
              record['lock_losses'] == 0 and record['tested_bits'] > 0 and record['valid_cycles'] > 0,
              site + ' lane record failure')

def receive_gate(sequence, previous, run, command):
    for site in boxes:
        submit(site, sequence, previous, command, 10000)
    for site in boxes:
        response(site, sequence, 0xc0c01, run)
    # Retain the v4 cleanup observation boundary; not merely mailbox IDLE.
    time.sleep(12)
    for site in boxes:
        clean_records(site, run)
        overview(site)
        state = boxes[site].read_u32(0xc8)
        check(state == (CAP if command == 0x11501 else CAP | ACTIVE), site + ' post-measurement state invalid')
        boxes[site].write_u32(0xcc, 0xfe)
        check(boxes[site].read_u32(0xd0) == 0x40 and boxes[site].read_u32(0xec) == 0,
              site + ' retained platform fault')

if args.stage == 'status':
    for site in boxes:
        overview(site)
else:
    # Remote sentinel prevents a second invocation even if the first SSH drops.
    fd = os.open(args.stage + '.started', os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    os.close(fd)
    try:
        for site in boxes:
            ready(site, 0 if args.stage == 'pma' else 1, 0 if args.stage == 'pma' else 1)
        if args.stage == 'pma':
            receive_gate(1, 0, 1, 0x11501)
            print('PASS: v5 dual PMA gates', flush=True)
        else:
            try:
                for site in boxes:
                    submit(site, 2, 1, 2, 180000)
                    response(site, 2, 0, 1, timeout=5)
                    check(boxes[site].read_u32(0xc8) == CAP | ACTIVE, site + ' TX session did not enable')
                time.sleep(0.1)  # TX-domain CDC settling; not a receive measurement.
                receive_gate(3, 2, 2, 0x10501)
                receive_gate(4, 3, 3, 0x10501)
            finally:
                # No reset/abort/retry. Stop each live session only when idle;
                # otherwise the hardware 180-second lease bounds transmission.
                for site, box in boxes.items():
                    try:
                        state = box.read_u32(0xc8)
                        sequence = box.read_u32(0xa0)
                        if state & ACTIVE and state & 0x1ffff == 0 and sequence in (2, 3, 4):
                            run = box.read_u32(0xf8)
                            submit(site, 5, sequence, 3, 0)
                            response(site, 5, 0, run, timeout=5)
                        else:
                            print('%s cleanup state=%#x; no new request, lease remains bounded' % (site, state), flush=True)
                    except Exception as error:
                        print('%s cleanup failed: %s; do not retry, watchdog remains active' % (site, error), flush=True)
            for site in boxes:
                ready(site, 5, 3)
                clean_records(site, 3)
            print('PASS: v5 two dual external baselines, TX sessions stopped', flush=True)
    finally:
        for site in boxes:
            try:
                overview(site)
                for lane in range(12):
                    print('%s FINAL lane=%d %r' % (site, lane, read_lane(boxes[site], lane)), flush=True)
            except Exception as error:
                print('%s evidence read failed: %s' % (site, error), flush=True)
