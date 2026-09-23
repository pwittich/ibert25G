#!/usr/bin/env python3
"""Fixed autonomous one-hour F1->F2 all12 soak. No reload/reset/retry."""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import time
import traceback
from firefly1_v5_oneway_remote import Diagnostic, require, CAP, ACTIVE
from firefly1_v5_all12_remote import records as prior_records, stop
from firefly1_v5_managed_receive_remote import compact
from firefly1_v5_managed_oneway_remote import rssi
from milestone3_12hour_external_soak import FpgaMailbox, read_lane

DURATION_MS = 3600000
LEASE_MS = 3900000
SUMMARY = 0x000c0c01
CYCLES = 322265625 * 3600


def claim(name):
    fd = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    os.close(fd)


def records(endpoint):
    b = endpoint.box
    require(b.read_u32(0xfc) == SUMMARY and b.read_u32(0xf8) == 4, 'soak summary/run')
    result = {}
    for lane in range(12):
        row = read_lane(b, lane)
        print('SOAK_LANE %d %r' % (lane, row), flush=True)
        require(row['id_status'] == 0x1800+lane and row['errors'] == 0 and row['lock_losses'] == 0,
                'lane%d status/error/loss failure' % lane)
        require(row['tested_bits'] == row['valid_cycles']*80 and
                abs(row['valid_cycles']-CYCLES) <= CYCLES//100, 'lane%d duration/denominator' % lane)
        result[lane] = row
    require(b.read_u32(0xfc) == SUMMARY and b.read_u32(0xf8) == 4, 'publication changed')
    return result


def run(source, receiver, read_power, sleep=time.sleep, clock=time.monotonic):
    source.healthy(9, 0)
    receiver.healthy(12, 3)
    prior_records(receiver, 3)
    source.evidence('soak-preflight')
    receiver.evidence('soak-preflight')
    read_power()
    started = clock()
    try:
        for endpoint, previous, oldrun in ((source,9,0),(receiver,12,3)):
            endpoint.submit(previous+1, previous, 2, LEASE_MS, 0xfff)
            endpoint.response(previous+1, 0, oldrun, 5)
            endpoint.healthy(previous+1, oldrun, active=True)
        sleep(20)
        read_power()
        source.healthy(10, 0, active=True)
        receiver.healthy(13, 3, active=True)
        require(clock()-started < 80, 'lease startup margin exceeded')
        receiver.submit(14, 13, 0x10501, DURATION_MS, 0xfff)
        submitted = clock()
        print('SOAK_SUBMITTED epoch=%.3f duration_ms=%d sequence=14 run_expected=4' % (time.time(),DURATION_MS), flush=True)
        saw_run = False
        while True:
            b = receiver.box
            receiver.identity()
            source.healthy(10, 0, active=True)
            ack = b.read_u32(0xf0)
            if ack == 14:
                receiver.response(14, SUMMARY, 4, 1)
                break
            state, run_id = b.read_u32(0xc8), b.read_u32(0xf8)
            # Publication can advance between separate MCU reads.
            if b.read_u32(0xf0) == 14:
                continue
            require(ack == 13 and run_id == 3 and b.read_u32(0xa0) == 14,
                    'unexpected in-flight sequence/run')
            require(state & (CAP|ACTIVE) == CAP|ACTIVE and not state & 0x0d0000,
                    'receiver session/platform failure')
            require(b.read_u32(0x9c) == 0x434da501, 'receiver clock monitor invalid')
            require(abs(b.read_u32(0x5c)-322266) < 323, 'receiver reference clock invalid')
            elapsed = clock()-submitted
            if state & 0xf == 2:
                saw_run = True
            require(saw_run or elapsed < 45, 'receiver never entered RUN')
            require(elapsed < 3660, 'soak completion timeout; no retry')
            print('SOAK_PROGRESS epoch=%.3f elapsed=%.3f state=%#x ack=%d published_run=%d' %
                  (time.time(),elapsed,state,ack,run_id), flush=True)
            sleep(10 if not saw_run else 30)
        compact(receiver)
        sleep(12)
        source.healthy(10, 0, active=True)
        receiver.healthy(14, 4, active=True)
        captured = records(receiver)
        read_power()
    finally:
        errors=[]
        for endpoint,previous,oldrun in ((receiver,12,3),(source,9,0)):
            try:
                compact(endpoint)
            except Exception as error:
                print('SNAPSHOT_ERROR '+str(error), flush=True)
            try:
                stop(endpoint,previous,oldrun)
            except Exception as error:
                errors.append(str(error))
                print('STOP_ERROR '+str(error), flush=True)
        for endpoint in (receiver,source):
            endpoint.evidence('soak-final')
        read_power()
        require(not errors,'cleanup failure '+repr(errors))
    source.healthy(11,0)
    receiver.healthy(15,4)
    require(records(receiver)==captured,'records changed across stops')
    print('PASS SOAK1H: all12 one-hour PRBS31 zeroerrors/losses; sessions stopped',flush=True)


def worker():
    claim('worker.started')
    try:
        sys.path.insert(0,'/home/cms/25G')
        from cm_interface.registry import Registry
        from cm_interface.device.firefly import FireflyRx
        registry=Registry(setup='tf',dev_path='/dev/ttyUL4')
        source=Diagnostic(FpgaMailbox(registry.fpgas['F1']),site='F1')
        receiver=Diagnostic(FpgaMailbox(registry.fpgas['F2']),site='F2')
        device=FireflyRx(registry.uart,0x2b,'F2_1_Rx')
        run(source,receiver,lambda:rssi(device))
        claim('worker.passed')
    except BaseException:
        traceback.print_exc()
        claim('worker.failed')
        raise


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage',choices=('start','worker','status','results'))
    args=parser.parse_args()
    if args.stage=='start':
        claim('start.claimed')
        with open('worker.log','x') as log:
            process=subprocess.Popen([sys.executable,'-u',str(Path(__file__).resolve()),'worker'],
                                     stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,
                                     start_new_session=True,close_fds=True)
        with open('worker.pid','x') as pid:
            pid.write(str(process.pid)+'\n')
        print('SOAK_WORKER_STARTED pid=%d; use status (log-only, no concurrent MCU access)'%process.pid)
    elif args.stage=='worker':
        worker()
    else:
        passed=Path('worker.passed').exists()
        failed=Path('worker.failed').exists()
        print('SOAK_STATE '+('PASS' if passed else 'FAIL' if failed else 'PENDING_OR_RUNNING'))
        lines=Path('worker.log').read_text().splitlines()
        print('\n'.join(lines if args.stage=='results' else lines[-12:]))
        if args.stage=='results':
            require(passed,'soak has not passed; preserve evidence')
        elif failed:
            raise RuntimeError('soak worker failed; no retry')


if __name__=='__main__': main()
