#!/usr/bin/env python3
"""One ten-second post-interruption reuse check; no channel requalification."""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import time
import traceback
from firefly1_v5_oneway_remote import Diagnostic, require
from firefly1_v5_all12_remote import records, stop
from firefly1_v5_managed_receive_remote import compact
from milestone3_12hour_external_soak import FpgaMailbox


def claim(name):
    os.close(os.open(name,os.O_CREAT|os.O_EXCL|os.O_WRONLY,0o600))


def controls(tx,rx):
    for name,device,address in (('F1TX',tx,52),('F2RX',rx,52),('F2RX-output',rx,54)):
        value=bytes(device.read_reg(address,size=2))
        print('CONTROL %s address=%d raw=%s'%(name,address,value.hex()),flush=True)
        require(len(value)==2 and not int.from_bytes(value,'big')&0xfff,'module control not restored')


def run(source,receiver,sleep=time.sleep,clock=time.monotonic):
    source.healthy(15,0);receiver.healthy(22,7)
    # Archive run7 before a new request replaces the frozen publication.
    for endpoint in (source,receiver): endpoint.evidence('closeout-preflight')
    started=clock()
    try:
        for endpoint,seq,previous,oldrun in ((source,16,15,0),(receiver,23,22,7)):
            endpoint.submit(seq,previous,2,180000,0xfff)
            endpoint.response(seq,0,oldrun,5)
        sleep(20)
        source.healthy(16,0,active=True);receiver.healthy(23,7,active=True)
        require(clock()-started<80,'insufficient lease margin')
        receiver.submit(24,23,0x10501,10000,0xfff)
        receiver.response(24,0x000c0c01,8,40)
        compact(receiver)
        captured=records(receiver,8)
        sleep(12)
        source.healthy(16,0,active=True);receiver.healthy(24,8,active=True)
    finally:
        failures=[]
        for endpoint,previous,oldrun in ((receiver,22,7),(source,15,0)):
            try: compact(endpoint)
            except Exception as error: print('SNAPSHOT_ERROR '+str(error),flush=True)
            try: stop(endpoint,previous,oldrun)
            except Exception as error: failures.append(str(error))
        for endpoint in (receiver,source): endpoint.evidence('closeout-final')
        require(not failures,'cleanup failure '+repr(failures))
    source.healthy(17,0);receiver.healthy(25,8)
    require(records(receiver,8)==captured,'publication changed across stops')
    print('PASS CLOSEOUT: new request reacquired and measured all12 clean; no external reset/reload. Not in-run automatic recovery or channel requalification.',flush=True)


def worker():
    claim('worker.started')
    try:
        require(Path('/tmp/firefly1-v5-alarm-20260916/worker.completed').exists(),'prior observation incomplete')
        sys.path.insert(0,'/home/cms/25G')
        from cm_interface.registry import Registry
        from cm_interface.device.firefly import FireflyTx,FireflyRx
        registry=Registry(setup='tf',dev_path='/dev/ttyUL4')
        tx=FireflyTx(registry.uart,0x20,'F1_1_Tx')
        rx=FireflyRx(registry.uart,0x2b,'F2_1_Rx')
        controls(tx,rx)
        run(Diagnostic(FpgaMailbox(registry.fpgas['F1']),site='F1'),
            Diagnostic(FpgaMailbox(registry.fpgas['F2']),site='F2'))
        controls(tx,rx)
        claim('worker.passed')
    except BaseException:
        traceback.print_exc();claim('worker.failed');raise


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage',choices=('start','worker','status','results'))
    args=parser.parse_args()
    if args.stage=='start':
        claim('start.claimed')
        with open('worker.log','x') as log:
            p=subprocess.Popen([sys.executable,'-u',str(Path(__file__).resolve()),'worker'],
                stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,start_new_session=True,close_fds=True)
        print('CLOSEOUT_WORKER_STARTED pid=%d'%p.pid)
    elif args.stage=='worker': worker()
    else:
        passed,failed=Path('worker.passed').exists(),Path('worker.failed').exists()
        print('CLOSEOUT_STATE '+('PASS' if passed else 'FAIL' if failed else 'RUNNING_OR_PENDING'))
        lines=Path('worker.log').read_text().splitlines()
        print('\n'.join(lines if args.stage=='results' else lines[-18:]))
        require(not failed and (args.stage!='results' or passed),'not passed; preserve evidence')


if __name__=='__main__': main()
