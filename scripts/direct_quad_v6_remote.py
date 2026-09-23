#!/usr/bin/env python3
"""Fixed v6 q222/q233 PMA and bidirectional external gates; never retry."""
import argparse
import os
import sys
import time

from milestone3_12hour_external_soak import FpgaMailbox, read_lane, read_overview, print_platform_diagnostics

CAP, ACTIVE = 1 << 20, 1 << 17
SUMMARY = 0x00040401
EXPECTED_CYCLES = 322265625 * 10
CYCLE_TOLERANCE = EXPECTED_CYCLES // 100
PROFILES = {
    'F1': {'version': 0x00020400, 'lanes': (60, 61, 62, 63),
           'mask': (0, 0xf0000000, 0, 0), 'ref_address': 0x30},
    'F2': {'version': 0x00020403, 'lanes': (104, 105, 106, 107),
           'mask': (0, 0, 0, 0x00000f00), 'ref_address': 0x38},
}


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


class Endpoint:
    def __init__(self, box, site, sleep=time.sleep, clock=time.monotonic):
        self.box, self.site = box, site
        self.profile = PROFILES[site]
        self.sleep, self.clock = sleep, clock

    def identity(self):
        expected = self.profile['version']
        require(self.box.read_u32(0xc0) == expected and self.box.read_u32(0xc4) == expected,
                self.site + ' identity mismatch')

    def healthy(self, sequence, run, active=False):
        self.identity()
        expected_state = CAP | (ACTIVE if active else 0)
        require(self.box.read_u32(0xc8) == expected_state, self.site + ' state/session mismatch')
        require((self.box.read_u32(0xa0), self.box.read_u32(0xf0), self.box.read_u32(0xf8)) ==
                (sequence, sequence, run), self.site + ' sequence/run mismatch')
        require(self.box.read_u32(0x9c) == 0x434da501, self.site + ' invalid clock monitor')
        for address, nominal in ((0x24, 100000), (0x28, 325000),
                                 (self.profile['ref_address'], 322266)):
            value = self.box.read_u32(address)
            require(abs(value - nominal) < nominal * .001,
                    '%s required clock %#x invalid: %d' % (self.site, address, value))
        self.box.write_u8(0xcc, 0xfe)
        require(self.box.read_u32(0xd0) == 0x40 and self.box.read_u32(0xec) == 0,
                self.site + ' retained platform fault')
        prbs = self.box.read_u32(0xd4)
        require(prbs & 0x40000000 and not (prbs & 0x8000001f),
                self.site + ' controller not IDLE')

    def submit(self, sequence, previous, command, duration):
        self.identity()
        require(self.box.read_u32(0xa0) == previous and self.box.read_u32(0xf0) == previous,
                self.site + ' unexpected predecessor')
        require(self.box.read_u32(0xc8) & 0x1ffff == 0, self.site + ' busy/faulted')
        values = ((0xa4, command), (0xa8, duration), (0xac, 0),
                  (0xb0, self.profile['mask'][0]), (0xb4, self.profile['mask'][1]),
                  (0xb8, self.profile['mask'][2]), (0xbc, self.profile['mask'][3]))
        for address, value in values:
            self.box.write_u32(address, value)
            require(self.box.read_u32(address) == value, self.site + ' descriptor mismatch')
        print('SUBMIT %s sequence=%d command=%#x duration_ms=%d' %
              (self.site, sequence, command, duration), flush=True)
        self.box.write_u32(0xa0, sequence)

    def response(self, sequence, code, run, timeout=40):
        deadline = self.clock() + timeout
        while self.box.read_u32(0xf0) != sequence:
            require(self.clock() < deadline, self.site + ' response timeout; no retry')
            self.sleep(.05)
        actual = (self.box.read_u32(0xf4), self.box.read_u32(0xf8))
        print('RESPONSE %s sequence=%d code=%#x run=%d' %
              ((self.site, sequence) + actual), flush=True)
        require(actual == (code, run), self.site + ' response/run failure')

    def records(self, run):
        require(self.box.read_u32(0xfc) == SUMMARY and self.box.read_u32(0xf8) == run,
                self.site + ' summary/run mismatch')
        result = {}
        for lane in self.profile['lanes']:
            record = dict(read_lane(self.box, lane))
            result[lane] = record
            print('VALIDATE %s lane=%d %r' % (self.site, lane, record), flush=True)
            require(record['id_status'] == 0x1800 + lane and record['errors'] == 0 and
                    record['lock_losses'] == 0 and record['tested_bits'] > 0 and
                    record['valid_cycles'] > 0, self.site + ' lane record failure')
            require(record['tested_bits'] == record['valid_cycles'] * 80,
                    self.site + ' denominator mismatch')
            require(abs(record['valid_cycles'] - EXPECTED_CYCLES) <= CYCLE_TOLERANCE,
                    self.site + ' duration outside tolerance')
        require(self.box.read_u32(0xfc) == SUMMARY and self.box.read_u32(0xf8) == run,
                self.site + ' publication changed')
        return result

    def evidence(self, label):
        print('EVIDENCE %s %s' % (self.site, label), flush=True)
        actions = [lambda: read_overview(self.box), lambda: print_platform_diagnostics(self.box)]
        actions += [lambda lane=lane: print('%s lane=%d %r' %
                    (self.site, lane, read_lane(self.box, lane)), flush=True)
                    for lane in self.profile['lanes']]
        for action in actions:
            try:
                action()
            except Exception as error:
                print('EVIDENCE_READ_ERROR %s %s' % (self.site, error), flush=True)

    def stop_if_safe(self):
        self.identity()
        state, sequence, ack, run = [self.box.read_u32(a) for a in (0xc8, 0xa0, 0xf0, 0xf8)]
        if state == CAP | ACTIVE and sequence == ack and sequence in (2, 3, 4):
            self.submit(5, sequence, 3, 0)
            self.response(5, 0, run, timeout=5)
            require(self.box.read_u32(0xc8) == CAP, self.site + ' TX did not stop')
        else:
            print('NO_STOP %s state=%#x sequence=%d ack=%d run=%d; lease bounded' %
                  (self.site, state, sequence, ack, run), flush=True)


def wait_overlap(endpoints, timeout=10, sleep=time.sleep, clock=time.monotonic):
    deadline = clock() + timeout
    while True:
        states = [endpoint.box.read_u32(0xc8) for endpoint in endpoints]
        if all((state & 0xf) == 2 and (state & ACTIVE) for state in states):
            print('OBSERVED simultaneous RUN with both TX sessions active', flush=True)
            return
        require(clock() < deadline, 'simultaneous RUN overlap not observed; no retry')
        sleep(.01)


def run_pma(endpoints, sleep=time.sleep):
    for endpoint in endpoints:
        endpoint.healthy(0, 0)
        endpoint.evidence('pre-PMA')
        endpoint.submit(1, 0, 0x11501, 10000)
    for endpoint in endpoints:
        endpoint.response(1, SUMMARY, 1)
    sleep(12)
    for endpoint in endpoints:
        endpoint.healthy(1, 1)
        endpoint.records(1)
        endpoint.evidence('post-PMA')
    print('PASS DIRECT_V6_PMA: both four-lane endpoint quads clean', flush=True)


def run_pma_f2_repair(endpoints, sleep=time.sleep):
    f1, f2 = endpoints
    # F1's sequence/run 1 PMA result is preserved and must not be replayed.
    f1.healthy(1, 1)
    f1.records(1)
    f1.evidence('preserved-PMA-pass')
    f2.healthy(0, 0)
    f2.evidence('pre-PMA-repair')
    f2.submit(1, 0, 0x11501, 10000)
    f2.response(1, SUMMARY, 1)
    sleep(12)
    f2.healthy(1, 1)
    f2.records(1)
    f2.evidence('post-PMA-repair')
    print('PASS DIRECT_V6_PMA_F2_REPAIR: F1 preserved; repaired F2 four-lane quad clean', flush=True)


def run_external(endpoints, sleep=time.sleep, overlap=wait_overlap):
    for endpoint in endpoints:
        endpoint.healthy(1, 1)
        endpoint.evidence('pre-external')
    saved = {}
    try:
        for endpoint in endpoints:
            endpoint.submit(2, 1, 2, 180000)
            endpoint.response(2, 0, 1, timeout=5)
            endpoint.healthy(2, 1, active=True)
        sleep(.1)
        for sequence, previous, run in ((3, 2, 2), (4, 3, 3)):
            for endpoint in endpoints:
                endpoint.submit(sequence, previous, 0x10501, 10000)
            overlap(endpoints)
            for endpoint in endpoints:
                endpoint.response(sequence, SUMMARY, run)
                endpoint.evidence('external-%d-published-before-stop' % run)
            sleep(12)
            for endpoint in endpoints:
                endpoint.healthy(sequence, run, active=True)
                saved[(endpoint.site, run)] = endpoint.records(run)
    finally:
        failures = []
        for endpoint in reversed(endpoints):
            try:
                endpoint.evidence('before-stop')
                endpoint.stop_if_safe()
            except Exception as error:
                failures.append('%s: %s' % (endpoint.site, error))
                print('STOP_ERROR %s %s' % (endpoint.site, error), flush=True)
            endpoint.evidence('final')
        require(not failures, 'safe stop failure: ' + repr(failures))
    for endpoint in endpoints:
        endpoint.healthy(5, 3)
        require(endpoint.records(3) == saved[(endpoint.site, 3)],
                endpoint.site + ' publication changed across stops')
    print('PASS DIRECT_V6_EXTERNAL: two overlapping ten-second bidirectional runs clean', flush=True)


def claim(name):
    fd = os.open(name + '.started', os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    os.close(fd)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage', choices=('status', 'pma', 'pma-f2-repair', 'external'))
    args = parser.parse_args()
    sys.path.insert(0, '/home/cms/25G')
    from cm_interface.registry import Registry
    registry = Registry(setup='tf', dev_path='/dev/ttyUL4')
    endpoints = [Endpoint(FpgaMailbox(registry.fpgas[site]), site) for site in ('F1', 'F2')]
    if args.stage == 'status':
        for endpoint in endpoints:
            endpoint.evidence('status')
        return
    claim(args.stage)
    if args.stage == 'pma':
        run_pma(endpoints)
    elif args.stage == 'pma-f2-repair':
        run_pma_f2_repair(endpoints)
    else:
        run_external(endpoints)


if __name__ == '__main__':
    main()
