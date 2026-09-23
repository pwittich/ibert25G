#!/usr/bin/env python3
"""One fixed TX02 interruption; characterization, not a clean BER gate."""
import argparse
import os
from pathlib import Path
import signal
import subprocess
import sys
import time
import traceback
from firefly1_v5_oneway_remote import Diagnostic, require, CAP, ACTIVE
from firefly1_v5_managed_oneway_remote import rssi
from firefly1_v5_managed_receive_remote import compact
from firefly1_v5_all12_remote import stop
from firefly1_v5_soak1h_remote import records as soak_records
from milestone3_12hour_external_soak import FpgaMailbox, read_lane


def claim(name):
    os.close(os.open(name, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600))


def pulse(tx, read_power, original, sleep=time.sleep, clock=time.monotonic):
    """Exactly one disable attempt; always attempt restoration, even lost ACK."""
    require(bytes(tx.read_reg(52, size=2)) == original, 'TX mask changed')
    require(len(original) == 2 and not (int.from_bytes(original, 'big') & 0xfff),
            'pre-existing disabled TX channels')
    begin = clock()
    samples = []
    try:
        print('DISABLE_ATTEMPT TX02 epoch=%.6f original=%s' % (time.time(), original.hex()), flush=True)
        tx.write_reg(53, bytes([original[1] | 4]))
        require(bytes(tx.read_reg(52, size=2)) == bytes([original[0], original[1] | 4]), 'disable readback')
        for offset in (1, 5, 9):
            sleep(max(0, begin + offset - clock()))
            print('DISABLED_RSSI elapsed=%.6f' % (clock()-begin), flush=True)
            samples.append(read_power())
        sleep(max(0, begin + 10 - clock()))
    finally:
        # Restore before any potentially slow evidence capture. Only byte53
        # was touched; byte52 (including reserved bits) must remain unchanged.
        signal.setitimer(signal.ITIMER_REAL, 0)
        tx.write_reg(53, original[1:2])
        require(bytes(tx.read_reg(52, size=2)) == original, 'CRITICAL: TX restore not verified')
        print('RESTORED original=%s elapsed=%.6f' % (original.hex(), clock()-begin), flush=True)
    return samples


def classify(before, during, after):
    # Conservative relative mapping criterion, not an optical calibration.
    # Require both late samples to agree; no one-second hard gate.
    changed = [i for i in range(12) if before[i] > 0 and
               all(v[i] < before[i] * .25 for v in during[-2:])]
    require(len(changed) == 1, 'RSSI mapping inconclusive: ' + repr(changed))
    channel = changed[0]
    print('MAPPING TX02 -> RX%02d -> testlane%d X0Y%d (RX02 was hypothesis only)' %
          (channel, 11-channel, 15-channel), flush=True)
    for i in range(12):
        require(after[i] > before[i] * .5, 'RSSI did not recover channel%d' % i)
        if i != channel:
            require(all(v[i] > before[i] * .5 for v in during[-2:]), 'neighbor RSSI disturbance')
    return 11-channel


def capture(receiver):
    b = receiver.box
    run, summary = b.read_u32(0xf8), b.read_u32(0xfc)
    values = {i: read_lane(b, i) for i in range(12)}
    for i, value in values.items():
        print('LOSS_LANE %d %r' % (i, value), flush=True)
    require((b.read_u32(0xf8), b.read_u32(0xfc)) == (run, summary), 'unstable publication')
    return run, summary, values


def validate(captured, lane):
    run, summary, values = captured
    require(run == 5 and summary & 0xff == 1, 'non-normal/synthetic publication')
    for i, v in values.items():
        require(v['id_status'] & 0xff == i and v['id_status'] & 0x800,
                'invalid/unselected record')
        require(v['tested_bits'] == 80*v['valid_cycles'] and v['valid_cycles'] > 0,
                'invalid denominator')
        if i != lane:
            require(v['id_status'] == 0x1800+i and v['errors'] == 0 and v['lock_losses'] == 0,
                    'unexpected neighbor errors/losses lane%d' % i)
            require(abs(v['valid_cycles']-322265625*60) < 322265625*.6, 'neighbor duration')
    require(values[lane]['errors'] > 0 or values[lane]['lock_losses'] > 0,
            'mapped lane did not record interruption')


def run(source, receiver, tx, read_power, sleep=time.sleep, clock=time.monotonic):
    source.healthy(11, 0)
    receiver.healthy(15, 4)
    soak_records(receiver)
    require(tx.read_reg(127) == b'\x00', 'unexpected TX page')
    original = bytes(tx.read_reg(52, size=2))
    require(not (int.from_bytes(original, 'big') & 0xfff), 'TX channels already disabled')
    print('TX_IDENTITY part=%s original=%s' % (tx.part_id, original.hex()), flush=True)
    for endpoint in (source, receiver):
        endpoint.evidence('loss-preflight')
    try:
        for endpoint, sequence, previous, oldrun in ((source,12,11,0), (receiver,16,15,4)):
            endpoint.submit(sequence, previous, 2, 180000, 0xfff)
            endpoint.response(sequence, 0, oldrun, 5)
        settled = clock()
        sleep(20)
        before = read_power()
        require(len(before) == 12 and all(v > 0 for v in before), 'unusable settled RSSI baseline; no stimulus')
        source.healthy(12, 0, active=True)
        receiver.healthy(16, 4, active=True)
        require(clock()-settled < 40, 'insufficient lease margin')
        receiver.submit(17,16,0x10501,60000,0xfff)
        b = receiver.box
        deadline = clock()+15
        while b.read_u32(0xc8) != CAP | ACTIVE | 2:
            require(b.read_u32(0xf0) == 16 and clock() < deadline, 'no RUN: no stimulus')
            sleep(.1)
        sleep(5)
        require(b.read_u32(0xc8) == CAP | ACTIVE | 2 and b.read_u32(0xf0) == 16,
                'RUN ended before stimulus')
        source.healthy(12,0,active=True)
        # A stuck UART read must not indefinitely delay the restoration path.
        # This cannot guarantee restoration under process/MCU/power failure.
        signal.setitimer(signal.ITIMER_REAL, 12)
        try:
            during = pulse(tx, read_power, original, sleep, clock)
        finally:
            signal.setitimer(signal.ITIMER_REAL, 0)
        sleep(20)
        after = read_power()
        deadline = clock()+60
        while b.read_u32(0xf0) != 17:
            require(clock() < deadline, 'publication timeout; no retry')
            sleep(.2)
        compact(receiver)
        captured = capture(receiver)
        sleep(12)
        source.healthy(12,0,active=True)
        receiver.healthy(17,5,active=True)
        lane = classify(before, during, after)
        validate(captured,lane)
    finally:
        errors = []
        # Neither stop retries a request or touches module controls.
        for endpoint, previous, oldrun in ((receiver,15,4),(source,11,0)):
            try:
                compact(endpoint)
            except Exception as error:
                print('SNAPSHOT_ERROR '+str(error),flush=True)
            try:
                stop(endpoint,previous,oldrun)
            except Exception as error:
                errors.append(str(error))
        for endpoint in (receiver,source):
            endpoint.evidence('loss-final')
        require(bytes(tx.read_reg(52,size=2)) == original,'CRITICAL: final mask mismatch')
        require(not errors,'session cleanup failed '+repr(errors))
    source.healthy(13,0)
    receiver.healthy(18,5)
    require(capture(receiver) == captured,'records changed after stops')
    print('PASS CHARACTERIZATION: isolated interruption observed; controls restored; sessions stopped. Recovery baseline pending.',flush=True)


def alarm_handler(signum, frame):
    raise TimeoutError('stimulus deadline; restore immediately')


def worker():
    claim('worker.started')
    signal.signal(signal.SIGALRM, alarm_handler)
    try:
        require(Path('/tmp/firefly1-v5-soak1h-20260916/worker.passed').exists(), 'hour PASS missing')
        sys.path.insert(0,'/home/cms/25G')
        from cm_interface.registry import Registry
        from cm_interface.device.firefly import FireflyTx, FireflyRx
        registry = Registry(setup='tf',dev_path='/dev/ttyUL4')
        source = Diagnostic(FpgaMailbox(registry.fpgas['F1']),site='F1')
        receiver = Diagnostic(FpgaMailbox(registry.fpgas['F2']),site='F2')
        tx = FireflyTx(registry.uart,0x20,'F1_1_Tx')
        rx = FireflyRx(registry.uart,0x2b,'F2_1_Rx')
        run(source,receiver,tx,lambda:rssi(rx))
        claim('worker.passed')
    except BaseException:
        traceback.print_exc()
        claim('worker.failed')
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage',choices=('start','worker','status','results'))
    args = parser.parse_args()
    if args.stage == 'start':
        claim('start.claimed')
        with open('worker.log','x') as log:
            process = subprocess.Popen([sys.executable,'-u',str(Path(__file__).resolve()),'worker'],
                stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,start_new_session=True,close_fds=True)
        print('LOSS_WORKER_STARTED pid=%d; log-only status while worker owns UART' % process.pid)
    elif args.stage == 'worker':
        worker()
    else:
        passed, failed = Path('worker.passed').exists(), Path('worker.failed').exists()
        print('LOSS_STATE '+('PASS' if passed else 'FAIL' if failed else 'RUNNING_OR_PENDING'))
        lines = Path('worker.log').read_text().splitlines()
        print('\n'.join(lines if args.stage == 'results' else lines[-18:]))
        require(not failed and (args.stage != 'results' or passed),'test not passed; preserve evidence')


if __name__ == '__main__':
    main()
