#!/usr/bin/env python3
"""Fixed recovery baseline and TX02 alarm observation; polling remains on."""
import argparse
from pathlib import Path
import signal
import subprocess
import sys
import time
import traceback
from firefly1_v5_oneway_remote import Diagnostic, require, CAP, ACTIVE
from firefly1_v5_managed_oneway_remote import rssi
from firefly1_v5_managed_receive_remote import compact
from firefly1_v5_loss_remote import claim, pulse, alarm_handler, capture
from milestone3_12hour_external_soak import FpgaMailbox


def alarm_sample(rx, label):
    raw_los = bytes(rx.read_reg(7,size=2))
    raw_lol = bytes(rx.read_reg(20,size=2))
    require(len(raw_los) == len(raw_lol) == 2,'short alarm read')
    los, lol = int.from_bytes(raw_los,'big'), int.from_bytes(raw_lol,'big')
    require(not (los & 0xf000 or lol & 0xf000),'invalid reserved alarm bits/read failure')
    print('ALARMS %s epoch=%.6f LOS=%03x CDR_LOL=%03x raw=%s/%s' %
          (label,time.time(),los,lol,raw_los.hex(),raw_lol.hex()),flush=True)
    return los,lol


def check_records(captured, run, seconds, clean):
    actual, summary, values = captured
    require(actual == run and summary & 255 == 1,'non-normal publication')
    for lane,v in values.items():
        require(v['id_status'] & 255 == lane and v['id_status'] & 0x800,'unselected/wrong lane')
        require(v['tested_bits'] == v['valid_cycles']*80 and v['valid_cycles'] > 0,'invalid denominator')
        if clean or lane != 9:
            require(v['id_status'] == 0x1800+lane and v['errors'] == v['lock_losses'] == 0,
                    'unexpected errors/losses lane%d' % lane)
            require(abs(v['valid_cycles']-322265625*seconds) < 322265625*seconds*.01,'duration mismatch')
    if clean:
        require(summary == 0x000c0c01,'clean summary mismatch')
    else:
        require(values[9]['errors'] or values[9]['lock_losses'],'no target disturbance recorded')


def safe_stop(endpoint):
    endpoint.identity()
    b=endpoint.box
    state,seq,ack,run=[b.read_u32(a) for a in (0xc8,0xa0,0xf0,0xf8)]
    allowed=((14,0),) if endpoint.site=='F1' else ((19,5),(20,6),(21,7))
    stopseq=15 if endpoint.site=='F1' else 22
    if state==CAP|ACTIVE and seq==ack and (seq,run) in allowed:
        endpoint.submit(stopseq,seq,3,0,0xfff)
        endpoint.response(stopseq,0,run,5)
        require(b.read_u32(0xc8)==CAP,'stop failed')
    else:
        print('NO_STOP %s state=%x seq=%d ack=%d run=%d; lease bounds session' %
              (endpoint.site,state,seq,ack,run),flush=True)


def run(source,receiver,tx,rx,sleep=time.sleep,clock=time.monotonic):
    source.healthy(13,0)
    receiver.healthy(18,5)
    for endpoint in (source,receiver): endpoint.evidence('alarm-preflight')
    original=bytes(tx.read_reg(52,size=2))
    require(len(original)==2 and not int.from_bytes(original,'big')&0xfff,'TX disable precondition')
    require(tx.read_reg(127)==b'\x00' and rx.read_reg(127)==b'\x00','unexpected page')
    controls={a:bytes(rx.read_reg(a,size=2)) for a in (52,54,74,95,108)}
    print('RX_CONTROLS '+repr({a:v.hex() for a,v in controls.items()}),flush=True)
    require(not int.from_bytes(controls[52],'big')&0xfff and
            not int.from_bytes(controls[54],'big')&0xfff,'RX disabled')
    require(int.from_bytes(controls[74],'big')&4,'RX02 CDR bypassed; no stimulus')
    print('MONITORING_REMAINS_ENABLED; zero alarm samples cannot exclude an event',flush=True)
    begun=clock()
    try:
        for e,seq,prev,oldrun in ((source,14,13,0),(receiver,19,18,5)):
            e.submit(seq,prev,2,180000,0xfff);e.response(seq,0,oldrun,5)
        sleep(20)
        source.healthy(14,0,active=True);receiver.healthy(19,5,active=True)
        rssi(rx)
        alarm_sample(rx,'settled-history-read-clears')
        receiver.submit(20,19,0x10501,10000,0xfff)
        receiver.response(20,0x000c0c01,6,40)
        baseline=capture(receiver)
        check_records(baseline,6,10,True)
        sleep(12)
        source.healthy(14,0,active=True);receiver.healthy(20,6,active=True)
        print('PASS CLEAN_RECOVERY_BASELINE seq20/run6 all12',flush=True)
        alarm_sample(rx,'pre-stimulus-history')
        sleep(1)
        los,lol=alarm_sample(rx,'pre-stimulus-recheck')
        require(not (los|lol)&4,'pre-existing target alarm; no stimulus')
        require(clock()-begun<65,'insufficient lease margin; no stimulus')
        receiver.submit(21,20,0x10501,60000,0xfff)
        b=receiver.box;deadline=clock()+15
        while b.read_u32(0xc8)!=CAP|ACTIVE|2:
            require(b.read_u32(0xf0)==20 and clock()<deadline,'no RUN; no stimulus')
            sleep(.1)
        sleep(5)
        require(b.read_u32(0xc8)==CAP|ACTIVE|2 and b.read_u32(0xf0)==20,'not RUN before stimulus')
        source.healthy(14,0,active=True)
        samples=[]
        def observed():
            samples.append(alarm_sample(rx,'disabled'))
            return rssi(rx)
        signal.setitimer(signal.ITIMER_REAL,12)
        try:
            pulse(tx,observed,original,sleep,clock)
        finally:
            signal.setitimer(signal.ITIMER_REAL,0)
        alarm_sample(rx,'first-restored-latched-history')
        sleep(5)
        alarm_sample(rx,'restored-5s')
        sleep(15)
        alarm_sample(rx,'restored-20s')
        rssi(rx)
        deadline=clock()+60
        while b.read_u32(0xf0)!=21:
            require(clock()<deadline,'publication timeout');sleep(.2)
        compact(receiver)
        interrupted=capture(receiver)
        check_records(interrupted,7,60,False)
        sleep(12)
        source.healthy(14,0,active=True);receiver.healthy(21,7,active=True)
        seen_los=any(los&4 for los,lol in samples)
        seen_lol=any(lol&4 for los,lol in samples)
        print('OBSERVED_RX02 LOS=%s CDR_LOL=%s; False means not captured, NOT no event' % (seen_los,seen_lol),flush=True)
    finally:
        errors=[]
        for endpoint in (receiver,source):
            try: compact(endpoint)
            except Exception as error: print('SNAPSHOT_ERROR '+str(error),flush=True)
            try: safe_stop(endpoint)
            except Exception as error: errors.append(str(error))
        for endpoint in (receiver,source): endpoint.evidence('alarm-final')
        require(bytes(tx.read_reg(52,size=2))==original,'CRITICAL final TX mask mismatch')
        require(not errors,'cleanup failure '+repr(errors))
    source.healthy(15,0);receiver.healthy(22,7)
    require(capture(receiver)==interrupted,'publication changed across stops')
    print('COMPLETE ALARM OBSERVATION; no post-interruption recovery baseline or retries',flush=True)


def worker():
    claim('worker.started');signal.signal(signal.SIGALRM,alarm_handler)
    try:
        sys.path.insert(0,'/home/cms/25G')
        from cm_interface.registry import Registry
        from cm_interface.device.firefly import FireflyTx,FireflyRx
        registry=Registry(setup='tf',dev_path='/dev/ttyUL4')
        run(Diagnostic(FpgaMailbox(registry.fpgas['F1']),site='F1'),
            Diagnostic(FpgaMailbox(registry.fpgas['F2']),site='F2'),
            FireflyTx(registry.uart,0x20,'F1_1_Tx'),FireflyRx(registry.uart,0x2b,'F2_1_Rx'))
        claim('worker.completed')
    except BaseException:
        traceback.print_exc();claim('worker.failed');raise


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage',choices=('start','worker','status','results'))
    args=parser.parse_args()
    if args.stage=='start':
        claim('start.claimed')
        with open('worker.log','x') as log:
            p=subprocess.Popen([sys.executable,'-u',str(Path(__file__).resolve()),'worker'],stdin=subprocess.DEVNULL,
                               stdout=log,stderr=subprocess.STDOUT,start_new_session=True,close_fds=True)
        print('ALARM_WORKER_STARTED pid=%d'%p.pid)
    elif args.stage=='worker': worker()
    else:
        complete,failed=Path('worker.completed').exists(),Path('worker.failed').exists()
        print('ALARM_STATE '+('COMPLETE' if complete else 'FAIL' if failed else 'RUNNING_OR_PENDING'))
        lines=Path('worker.log').read_text().splitlines()
        print('\n'.join(lines if args.stage=='results' else lines[-18:]))
        require(not failed and (args.stage!='results' or complete),'not completed; preserve evidence')


if __name__=='__main__': main()
