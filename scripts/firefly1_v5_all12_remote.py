#!/usr/bin/env python3
"""Two fixed, unique all-twelve-lane gates. Repeat only after first PASS."""
import argparse
import os
import sys
import time
from firefly1_v5_oneway_remote import Diagnostic, require, CAP, ACTIVE, EXPECTED_CYCLES, CYCLE_TOLERANCE
from firefly1_v5_managed_oneway_remote import rssi
from firefly1_v5_managed_receive_remote import compact
from milestone3_12hour_external_soak import FpgaMailbox, read_lane

SUMMARY = 0x000c0c01
# F1 predecessor, F2 predecessor, previous F2 measurement run.
PROFILES = {'start': (5, 6, 1), 'repeat': (7, 9, 2)}


def records(endpoint, run):
    b = endpoint.box
    require(b.read_u32(0xfc) == SUMMARY and b.read_u32(0xf8) == run, 'summary/run mismatch')
    result = {}
    for lane in range(12):
        value = read_lane(b, lane)
        print('ALL12 lane=%d %r' % (lane, value), flush=True)
        require(value['id_status'] == 0x1800 + lane and value['errors'] == 0 and
                value['lock_losses'] == 0, 'lane%d status/errors/losses' % lane)
        require(value['tested_bits'] == 80 * value['valid_cycles'] and
                abs(value['valid_cycles'] - EXPECTED_CYCLES) <= CYCLE_TOLERANCE,
                'lane%d denominator/duration' % lane)
        result[lane] = value
    require(b.read_u32(0xfc) == SUMMARY and b.read_u32(0xf8) == run, 'publication changed')
    return result


def stop(endpoint, previous, oldrun):
    endpoint.identity()
    b = endpoint.box
    state, seq, ack, run = [b.read_u32(a) for a in (0xc8, 0xa0, 0xf0, 0xf8)]
    source = endpoint.site == 'F1'
    allowed = ((previous+1, oldrun),) if source else ((previous+1, oldrun), (previous+2, oldrun+1))
    if state == CAP | ACTIVE and seq == ack and (seq, run) in allowed:
        stopseq = previous + (2 if source else 3)
        endpoint.submit(stopseq, seq, 3, 0, 0xfff)
        endpoint.response(stopseq, 0, run, 5)
        require(b.read_u32(0xc8) == CAP, 'session stop failed')
    else:
        print('NO_STOP %s state=%#x seq=%d ack=%d run=%d; bounded lease, no reset/replay' %
              (endpoint.site, state, seq, ack, run), flush=True)


def run(source, receiver, read_power, profile, sleep=time.sleep, clock=time.monotonic):
    p1, p2, prior_run = PROFILES[profile]
    source.healthy(p1, 0)
    receiver.healthy(p2, prior_run)
    if profile == 'repeat':
        records(receiver, prior_run)  # Prior all12 publication must still PASS.
    for endpoint in (source, receiver):
        endpoint.evidence('all12-preflight-' + profile)
    print('RSSI_BASELINE %.6f' % clock(), flush=True)
    read_power()
    started = clock()
    try:
        for endpoint, previous, oldrun in ((source, p1, 0), (receiver, p2, prior_run)):
            endpoint.submit(previous+1, previous, 2, 180000, 0xfff)
            endpoint.response(previous+1, 0, oldrun, 5)
            endpoint.healthy(previous+1, oldrun, active=True)
        for offset in (1, 5, 10, 20):
            sleep(max(0, started + offset - clock()))
            source.healthy(p1+1, 0, active=True)
            receiver.healthy(p2+1, prior_run, active=True)
            print('RSSI_ACTIVE elapsed=%.6f' % (clock()-started), flush=True)
            read_power()
        require(clock()-started < 80, 'insufficient lease margin')
        receiver.submit(p2+2, p2+1, 0x10501, 10000, 0xfff)
        receiver.response(p2+2, SUMMARY, prior_run+1, 40)
        compact(receiver)
        sleep(12)
        source.healthy(p1+1, 0, active=True)
        receiver.healthy(p2+2, prior_run+1, active=True)
        captured = records(receiver, prior_run+1)
        read_power()
    finally:
        errors = []
        for endpoint, previous, oldrun in ((receiver, p2, prior_run), (source, p1, 0)):
            try:
                compact(endpoint)
            except Exception as error:
                print('SNAPSHOT_ERROR ' + str(error), flush=True)
            try:
                stop(endpoint, previous, oldrun)
            except Exception as error:
                errors.append(str(error))
                print('STOP_ERROR ' + str(error), flush=True)
        for endpoint in (receiver, source):
            endpoint.evidence('all12-final-' + profile)
        read_power()
        require(not errors, 'cleanup failure ' + repr(errors))
    source.healthy(p1+2, 0)
    receiver.healthy(p2+3, prior_run+1)
    require(records(receiver, prior_run+1) == captured, 'records changed across stop')
    print('PASS ALL12 %s: twelve lanes ten seconds; both PRBS sessions stopped' % profile, flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage', choices=('start', 'repeat', 'status'))
    args = parser.parse_args()
    if args.stage in PROFILES:
        if args.stage == 'repeat':
            require(os.path.exists('start.passed'), 'first all12 gate did not pass')
        fd = os.open(args.stage + '.started', os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        os.close(fd)
    sys.path.insert(0, '/home/cms/25G')
    from cm_interface.registry import Registry
    from cm_interface.device.firefly import FireflyRx
    registry = Registry(setup='tf', dev_path='/dev/ttyUL4')
    source = Diagnostic(FpgaMailbox(registry.fpgas['F1']), site='F1')
    receiver = Diagnostic(FpgaMailbox(registry.fpgas['F2']), site='F2')
    device = FireflyRx(registry.uart, 0x2b, 'F2_1_Rx')
    if args.stage in PROFILES:
        run(source, receiver, lambda: rssi(device), args.stage)
        fd = os.open(args.stage + '.passed', os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        os.close(fd)
    else:
        source.evidence('status')
        receiver.evidence('status')
        rssi(device)


if __name__ == '__main__':
    main()
