#!/usr/bin/env python3
"""Fixed all-direct cleanup-repair PMA and bidirectional PRBS31 gates; never retry."""
import argparse
import fcntl
import os
import sys
import time

from all_direct_v7_contract import (ALL_DIRECT_LANES, ALL_DIRECT_MASK,
                                    DIRECT_REFCLK_ADDRESSES, ENDPOINTS,
                                    EXTERNAL_FITTED_COUNT, validate_contract)
from milestone3_12hour_external_soak import (FpgaMailbox, read_lane,
                                             read_overview,
                                             print_platform_diagnostics)

CAPABILITY = 1 << 20
SESSION_ACTIVE = 1 << 17
SESSION_EXPIRED = 1 << 18
SESSION_READY = 1 << 21
PMA_LANE_COUNT = 56
PMA_SUMMARY = (PMA_LANE_COUNT << 16) | (PMA_LANE_COUNT << 8) | 1
EXTERNAL_SUMMARY = ((EXTERNAL_FITTED_COUNT << 16) |
                    (EXTERNAL_FITTED_COUNT << 8) | 1)
EXPECTED_CYCLES = 322265625 * 10
CYCLE_TOLERANCE = EXPECTED_CYCLES // 100
MCU_LOCK = '/tmp/all-direct-v12-mcu.lock'


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


class Endpoint:
    def __init__(self, box, site, sleep=time.sleep, clock=time.monotonic):
        self.box, self.site = box, site
        self.profile = ENDPOINTS[site]
        self.sleep, self.clock = sleep, clock

    def identity(self):
        expected = self.profile['version']
        require(self.box.read_u32(0xc0) == expected and
                self.box.read_u32(0xc4) == expected,
                self.site + ' identity mismatch')

    def healthy(self, sequence, run, active=False, state_extra=0):
        self.identity()
        expected_state = CAPABILITY | ((SESSION_ACTIVE | SESSION_READY)
                                       if active else 0) | state_extra
        require(self.box.read_u32(0xc8) == expected_state,
                self.site + ' state/session mismatch')
        require((self.box.read_u32(0xa0), self.box.read_u32(0xf0),
                 self.box.read_u32(0xf8)) == (sequence, sequence, run),
                self.site + ' sequence/run mismatch')
        require(self.box.read_u32(0x9c) == 0x434da501,
                self.site + ' invalid clock monitor')
        for address, nominal in ((0x24, 100000), (0x28, 325000)):
            value = self.box.read_u32(address)
            require(abs(value - nominal) < nominal * .001,
                    '%s required clock %#x invalid: %d' %
                    (self.site, address, value))
        for address in DIRECT_REFCLK_ADDRESSES:
            value = self.box.read_u32(address)
            require(abs(value - 322266) < 323,
                    '%s direct REFCLK %#x invalid: %d' %
                    (self.site, address, value))
        self.box.write_u8(0xcc, 0xfe)
        require(self.box.read_u32(0xd0) == 0x40 and
                self.box.read_u32(0xec) == 0,
                self.site + ' retained platform fault')
        prbs = self.box.read_u32(0xd4)
        require(prbs & 0x40000000 and not (prbs & 0x8000001f),
                self.site + ' controller not IDLE')

    def submit(self, sequence, previous, command, duration, mask):
        self.identity()
        require(self.box.read_u32(0xa0) == previous and
                self.box.read_u32(0xf0) == previous,
                self.site + ' unexpected predecessor')
        require(self.box.read_u32(0xc8) & 0x1ffff == 0,
                self.site + ' busy/faulted')
        values = ((0xa4, command), (0xa8, duration), (0xac, 0),
                  (0xb0, mask[0]), (0xb4, mask[1]),
                  (0xb8, mask[2]), (0xbc, mask[3]))
        for address, value in values:
            self.box.write_u32(address, value)
            require(self.box.read_u32(address) == value,
                    self.site + ' descriptor mismatch')
        print('SUBMIT %s sequence=%d command=%#x duration_ms=%d' %
              (self.site, sequence, command, duration), flush=True)
        self.box.write_u32(0xa0, sequence)

    def response(self, sequence, code, run, timeout=40):
        deadline = self.clock() + timeout
        while self.box.read_u32(0xf0) != sequence:
            require(self.clock() < deadline,
                    self.site + ' response timeout; no retry')
            self.sleep(.05)
        actual = (self.box.read_u32(0xf4), self.box.read_u32(0xf8))
        print('RESPONSE %s sequence=%d code=%#x run=%d' %
              ((self.site, sequence) + actual), flush=True)
        require(actual == (code, run), self.site + ' response/run failure')

    def records(self, run, lanes, summary):
        require(self.box.read_u32(0xfc) == summary and
                self.box.read_u32(0xf8) == run,
                self.site + ' summary/run mismatch')
        result = {}
        for lane in lanes:
            record = dict(read_lane(self.box, lane))
            result[lane] = record
            print('VALIDATE %s lane=%d %r' %
                  (self.site, lane, record), flush=True)
            require(record['id_status'] == 0x1800 + lane and
                    record['errors'] == 0 and record['lock_losses'] == 0 and
                    record['tested_bits'] > 0 and
                    record['valid_cycles'] > 0,
                    self.site + ' lane record failure')
            require(record['tested_bits'] == record['valid_cycles'] * 80,
                    self.site + ' denominator mismatch')
            require(abs(record['valid_cycles'] - EXPECTED_CYCLES) <=
                    CYCLE_TOLERANCE,
                    self.site + ' duration outside tolerance')
        require(self.box.read_u32(0xfc) == summary and
                self.box.read_u32(0xf8) == run,
                self.site + ' publication changed')
        return result

    def evidence(self, label):
        print('EVIDENCE %s %s' % (self.site, label), flush=True)
        actions = [lambda: read_overview(self.box),
                   lambda: print_platform_diagnostics(self.box)]
        actions += [lambda lane=lane: print('%s lane=%d %r' %
                    (self.site, lane, read_lane(self.box, lane)), flush=True)
                    for lane in ALL_DIRECT_LANES]
        for action in actions:
            try:
                action()
            except Exception as error:
                print('EVIDENCE_READ_ERROR %s %s' %
                      (self.site, error), flush=True)

    def stop_if_safe(self, allowed_sequences=(2, 3), allowed_runs=(1, 2)):
        self.identity()
        state, sequence, ack, run = [self.box.read_u32(address)
                                     for address in (0xc8, 0xa0, 0xf0, 0xf8)]
        if (state == CAPABILITY | SESSION_ACTIVE | SESSION_READY and
                sequence == ack and
                sequence in allowed_sequences and run in allowed_runs):
            stop_sequence = sequence + 1
            self.submit(stop_sequence, sequence, 3, 0, ALL_DIRECT_MASK)
            self.response(stop_sequence, 0, run, timeout=5)
            require(self.box.read_u32(0xc8) == CAPABILITY,
                    self.site + ' TX did not stop')
            return stop_sequence
        else:
            print('NO_STOP %s state=%#x sequence=%d ack=%d run=%d; '
                  'lease bounded' %
                  (self.site, state, sequence, ack, run), flush=True)
            return None


def wait_overlap(endpoints, timeout=10, sleep=time.sleep,
                 clock=time.monotonic):
    deadline = clock() + timeout
    while True:
        states = [endpoint.box.read_u32(0xc8) for endpoint in endpoints]
        if all((state & 0xf) == 2 and
               (state & (SESSION_ACTIVE | SESSION_READY)) ==
               (SESSION_ACTIVE | SESSION_READY) for state in states):
            print('OBSERVED simultaneous RUN with both TX sessions active',
                  flush=True)
            return
        require(clock() < deadline,
                'simultaneous RUN overlap not observed; no retry')
        sleep(.01)


def run_pma_f1(endpoints):
    f1, f2 = endpoints
    f1.healthy(0, 0)
    f2.healthy(0, 0)
    f1.evidence('pre-PMA-F1')
    f2.evidence('preserved-fresh-F2')
    try:
        f1.submit(1, 0, 0x11501, 10000, ALL_DIRECT_MASK)
        f1.response(1, PMA_SUMMARY, 1)
        f1.healthy(1, 1)
        f1.records(1, ALL_DIRECT_LANES, PMA_SUMMARY)
        f2.healthy(0, 0)
    except Exception:
        f1.evidence('PMA-F1-failure')
        f2.evidence('preserved-F2-after-PMA-F1-failure')
        raise
    f1.evidence('post-PMA-F1')
    print('PASS ALL_DIRECT_V12_PMA_F1: 56 lanes clean; F2 preserved fresh',
          flush=True)


def run_pma_f2(endpoints):
    f1, f2 = endpoints
    f1.healthy(1, 1)
    f1.records(1, ALL_DIRECT_LANES, PMA_SUMMARY)
    f2.healthy(0, 0)
    f1.evidence('preserved-PMA-F1')
    f2.evidence('pre-PMA-F2')
    try:
        f2.submit(1, 0, 0x11501, 10000, ALL_DIRECT_MASK)
        f2.response(1, PMA_SUMMARY, 1)
        f1.healthy(1, 1)
        f2.healthy(1, 1)
        f2.records(1, ALL_DIRECT_LANES, PMA_SUMMARY)
    except Exception:
        f1.evidence('preserved-F1-after-PMA-F2-failure')
        f2.evidence('PMA-F2-failure')
        raise
    f2.evidence('post-PMA-F2')
    print('PASS ALL_DIRECT_V12_PMA_F2: 56 lanes clean; F1 pass preserved',
          flush=True)


def run_external(endpoints, overlap=wait_overlap):
    for endpoint in endpoints:
        endpoint.healthy(1, 1)
        endpoint.evidence('pre-external')
    saved = {}
    try:
        for endpoint in endpoints:
            endpoint.submit(2, 1, 2, 180000, ALL_DIRECT_MASK)
            endpoint.response(2, 0, 1, timeout=5)
            endpoint.healthy(2, 1, active=True)
        for endpoint in endpoints:
            endpoint.submit(3, 2, 0x10501, 10000,
                            endpoint.profile['external_mask'])
        overlap(endpoints)
        for endpoint in endpoints:
            endpoint.response(3, EXTERNAL_SUMMARY, 2)
        # Preserve and validate both publications before either transmitter is
        # stopped.  A failure still enters the bounded safe-stop path below.
        for endpoint in endpoints:
            endpoint.evidence('external-published-before-stop')
            endpoint.healthy(3, 2, active=True)
            saved[endpoint.site] = endpoint.records(
                2, endpoint.profile['external_lanes'], EXTERNAL_SUMMARY)
    finally:
        failures = []
        for endpoint in reversed(endpoints):
            try:
                endpoint.evidence('before-stop')
                endpoint.stop_if_safe()
            except Exception as error:
                failures.append('%s: %s' % (endpoint.site, error))
                print('STOP_ERROR %s %s' %
                      (endpoint.site, error), flush=True)
            endpoint.evidence('final')
        require(not failures, 'safe stop failure: ' + repr(failures))
    for endpoint in endpoints:
        endpoint.healthy(4, 2)
        require(endpoint.records(2, endpoint.profile['external_lanes'],
                                 EXTERNAL_SUMMARY) == saved[endpoint.site],
                endpoint.site + ' publication changed across stops')
    print('PASS ALL_DIRECT_V12_EXTERNAL: one overlapping ten-second '
          'bidirectional 54-fitted-lane run clean', flush=True)


def run_external_resume(endpoints, overlap=wait_overlap):
    """Resume once from preserved post-launcher-failure v10 state."""
    f1, f2 = endpoints
    f1.healthy(2, 1, state_extra=SESSION_EXPIRED)
    f2.healthy(1, 1)
    for endpoint in endpoints:
        endpoint.records(1, ALL_DIRECT_LANES, PMA_SUMMARY)
        endpoint.evidence('pre-external-resume')
    saved = {}
    stopped = {}
    try:
        f1.submit(3, 2, 2, 180000, ALL_DIRECT_MASK)
        f1.response(3, 0, 1, timeout=5)
        f1.healthy(3, 1, active=True)
        f2.submit(2, 1, 2, 180000, ALL_DIRECT_MASK)
        f2.response(2, 0, 1, timeout=5)
        f2.healthy(2, 1, active=True)

        f1.submit(4, 3, 0x10501, 10000,
                  f1.profile['external_mask'])
        f2.submit(3, 2, 0x10501, 10000,
                  f2.profile['external_mask'])
        overlap(endpoints)
        f1.response(4, EXTERNAL_SUMMARY, 2)
        f2.response(3, EXTERNAL_SUMMARY, 2)
        for endpoint in endpoints:
            endpoint.evidence('external-resume-published-before-stop')
            sequence = 4 if endpoint.site == 'F1' else 3
            endpoint.healthy(sequence, 2, active=True)
            saved[endpoint.site] = endpoint.records(
                2, endpoint.profile['external_lanes'], EXTERNAL_SUMMARY)
    finally:
        failures = []
        for endpoint in reversed(endpoints):
            try:
                endpoint.evidence('before-resume-stop')
                stopped[endpoint.site] = endpoint.stop_if_safe(
                    allowed_sequences=(2, 3, 4), allowed_runs=(1, 2))
            except Exception as error:
                failures.append('%s: %s' % (endpoint.site, error))
                print('STOP_ERROR %s %s' %
                      (endpoint.site, error), flush=True)
            endpoint.evidence('final-resume')
        require(not failures, 'safe stop failure: ' + repr(failures))
    require(stopped == {'F1': 5, 'F2': 4},
            'unexpected successful resume stop sequences: ' + repr(stopped))
    for endpoint, sequence in ((f1, 5), (f2, 4)):
        endpoint.healthy(sequence, 2)
        require(endpoint.records(2, endpoint.profile['external_lanes'],
                                 EXTERNAL_SUMMARY) == saved[endpoint.site],
                endpoint.site + ' publication changed across resume stop')
    print('PASS ALL_DIRECT_V10_EXTERNAL_RESUME: one overlapping ten-second '
          'bidirectional 54-fitted-lane run clean', flush=True)


def claim(stage):
    descriptor = os.open(stage + '.started',
                         os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    os.close(descriptor)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage',
                        choices=('status', 'pma-f1', 'pma-f2', 'external'))
    args = parser.parse_args()
    validate_contract()
    lock_fd = os.open(MCU_LOCK, os.O_RDWR | os.O_CREAT, 0o600)
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except IOError:
        os.close(lock_fd)
        raise RuntimeError('serialized MCU owner already active')
    if args.stage != 'status':
        claim(args.stage)
    sys.path.insert(0, '/home/cms/25G')
    from cm_interface.registry import Registry
    registry = Registry(setup='tf', dev_path='/dev/ttyUL4')
    endpoints = [Endpoint(FpgaMailbox(registry.fpgas[site]), site)
                 for site in ('F1', 'F2')]
    try:
        if args.stage == 'status':
            for endpoint in endpoints:
                endpoint.evidence('status')
        elif args.stage == 'pma-f1':
            run_pma_f1(endpoints)
        elif args.stage == 'pma-f2':
            run_pma_f2(endpoints)
        elif args.stage == 'external':
            run_external(endpoints)
        else:
            run_external(endpoints)
    finally:
        os.close(lock_fd)


if __name__ == '__main__':
    main()
