#!/usr/bin/env python3
"""One fresh two-v5, one-way diagnostic; never replay or reset."""
import argparse
import sys
import time
from firefly1_v5_oneway_remote import Diagnostic, claim_start, require, SESSION_MASK, RX_MASK, SUMMARY
from milestone3_12hour_external_soak import FpgaMailbox


def rssi(device):
    raw = bytes(device.read_block(0x01ce, 24))
    require(len(raw) == 24, 'short RSSI block')
    values = [int.from_bytes(raw[2*(11-c):2*(12-c)], 'big') / 10.0 for c in range(12)]
    print('RSSI F2_1 raw=%s Rx00_to_Rx11_uW=%r' % (raw.hex(), values), flush=True)
    return values


def run(source, receiver, read_power, sleep=time.sleep):
    source.healthy(0, 0)
    receiver.healthy(0, 0)
    source.evidence('fresh-F1')
    receiver.evidence('fresh-F2')
    before = read_power()
    try:
        for endpoint in (source, receiver):
            endpoint.submit(1, 0, 2, 180000, SESSION_MASK)
            endpoint.response(1, 0, 0, 5)
            endpoint.healthy(1, 0, active=True)
        sleep(1)
        during = read_power()
        for channel in range(12):
            if channel != 2:
                require(during[channel] > 100 and during[channel] - before[channel] > 100,
                        'RSSI light-on gate failed Rx%02d; no RX request' % channel)
        print('PASS RSSI: eleven selected optical channels show light-on increase', flush=True)
        source.healthy(1, 0, active=True)
        receiver.healthy(1, 0, active=True)
        receiver.submit(2, 1, 0x10501, 10000, RX_MASK)
        receiver.response(2, SUMMARY, 1, 40)
        receiver.evidence('published-before-cleanup')
        sleep(12)
        source.healthy(1, 0, active=True)
        receiver.healthy(2, 1, active=True)
        records = receiver.records()
    finally:
        # Attempt both independent safe stops even if one transport fails.
        failures = []
        for endpoint in (receiver, source):
            endpoint.evidence('before-stop')
            try:
                endpoint.stop_if_safe()
            except Exception as error:
                failures.append(str(error))
                print('STOP_ERROR %s %s' % (endpoint.site, error), flush=True)
            endpoint.evidence('final')
        read_power()
        require(not failures, 'safe stop failure: ' + repr(failures))
    source.healthy(3, 0)
    receiver.healthy(3, 1)
    require(receiver.records() == records, 'F2 publication changed across stops')
    print('PASS MANAGED_ONEWAY: F1 TX -> F2 eleven-lane RX, ten seconds; both sessions off', flush=True)


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
