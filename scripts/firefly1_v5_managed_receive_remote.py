#!/usr/bin/env python3
"""Fixed seq4/5 receive diagnostic; RSSI is observational, never a BER gate."""
import argparse
import sys
import time
from firefly1_v5_oneway_remote import Diagnostic, claim_start, require, CAP, ACTIVE, SESSION_MASK, RX_MASK, SUMMARY
from firefly1_v5_managed_oneway_remote import rssi
from milestone3_12hour_external_soak import FpgaMailbox, read_overview, print_platform_diagnostics


def safe_stop(endpoint):
    endpoint.identity()
    b = endpoint.box
    state, seq, ack, run = [b.read_u32(a) for a in (0xc8, 0xa0, 0xf0, 0xf8)]
    allowed = ((4, 0),) if endpoint.site == 'F1' else ((4, 0), (5, 1))
    if state == CAP | ACTIVE and seq == ack and (seq, run) in allowed:
        stop_seq = 5 if endpoint.site == 'F1' else 6
        endpoint.submit(stop_seq, seq, 3, 0, SESSION_MASK)
        endpoint.response(stop_seq, 0, run, 5)
        require(b.read_u32(0xc8) == CAP, endpoint.site + ' session did not stop')
    else:
        print('NO_STOP %s state=%#x seq=%d ack=%d run=%d; no reset/abort/replay' %
              (endpoint.site, state, seq, ack, run), flush=True)


def compact(endpoint):
    print('COMPACT ' + endpoint.site, flush=True)
    read_overview(endpoint.box)
    print_platform_diagnostics(endpoint.box)


def run(source, receiver, read_power, sleep=time.sleep, clock=time.monotonic):
    for endpoint in (source, receiver):
        endpoint.healthy(3, 0)
        endpoint.evidence('preflight-sequence3')
    print('RSSI_BASELINE time=%.6f' % clock(), flush=True)
    read_power()
    start = clock()
    try:
        for endpoint in (source, receiver):
            endpoint.submit(4, 3, 2, 180000, SESSION_MASK)
            endpoint.response(4, 0, 0, 5)
            endpoint.healthy(4, 0, active=True)
        for offset in (1, 5, 10, 20):
            sleep(max(0, start + offset - clock()))
            for endpoint in (source, receiver):
                endpoint.healthy(4, 0, active=True)
            print('RSSI_SESSION_ACTIVE elapsed=%.6f' % (clock() - start), flush=True)
            read_power()  # No power threshold or delta-based refusal.
        require(clock() - start < 80, 'insufficient lease margin; no RX request')
        receiver.submit(5, 4, 0x10501, 10000, RX_MASK)
        receiver.response(5, SUMMARY, 1, 40)
        compact(receiver)
        sleep(12)
        source.healthy(4, 0, active=True)
        receiver.healthy(5, 1, active=True)
        records = receiver.records()
        print('RSSI_AFTER_RX elapsed=%.6f' % (clock() - start), flush=True)
        read_power()
    finally:
        errors = []
        # Preserve small response/fault snapshot before stops overwrite response.
        for endpoint in (receiver, source):
            try:
                compact(endpoint)
            except Exception as error:
                print('SNAPSHOT_ERROR ' + str(error), flush=True)
            try:
                safe_stop(endpoint)
            except Exception as error:
                errors.append(str(error))
                print('STOP_ERROR %s %s' % (endpoint.site, error), flush=True)
        for endpoint in (receiver, source):
            endpoint.evidence('final-after-stop-attempts')
        print('RSSI_FINAL time=%.6f' % clock(), flush=True)
        read_power()
        require(not errors, 'stop failure: ' + repr(errors))
    source.healthy(5, 0)
    receiver.healthy(6, 1)
    require(receiver.records() == records, 'publication changed across session stops')
    print('PASS MANAGED_RECEIVE: eleven lanes ten seconds, both PRBS sessions stopped', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage', choices=('start', 'status'))
    args = parser.parse_args()
    if args.stage == 'start':
        claim_start('.')
    sys.path.insert(0, '/home/cms/25G')
    from cm_interface.registry import Registry
    from cm_interface.device.firefly import FireflyRx
    registry = Registry(setup='tf', dev_path='/dev/ttyUL4')
    source = Diagnostic(FpgaMailbox(registry.fpgas['F1']), site='F1')
    receiver = Diagnostic(FpgaMailbox(registry.fpgas['F2']), site='F2')
    device = FireflyRx(registry.uart, 0x2b, 'F2_1_Rx')
    if args.stage == 'start':
        run(source, receiver, lambda: rssi(device))
    else:
        source.evidence('status')
        receiver.evidence('status')
        rssi(device)


if __name__ == '__main__':
    main()
