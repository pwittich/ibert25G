#!/usr/bin/env python3
"""Fixed F2-only v5 subset diagnostic. Offline-developed; execution held."""
import argparse
import os
import sys
import time
from milestone3_12hour_external_soak import FpgaMailbox, read_lane, read_overview, print_platform_diagnostics

# Parent review must explicitly release after golden evidence and subset sim.
# No CLI override: editing this gate changes the hash-verified bundle.
REVIEW_RELEASED = False
CAP, ACTIVE = 1 << 20, 1 << 17
RX_MASK, SESSION_MASK = 0x0dff, 0x0fff
SUMMARY = (11 << 16) | (11 << 8) | 1
EXPECTED_CYCLES = 322265625 * 10
# 1% is a conservative diagnostic-duration bound, not a clock-calibration
# tolerance. Required monitor clocks independently retain their 0.1% bound.
CYCLE_TOLERANCE = EXPECTED_CYCLES // 100


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


class Diagnostic:
    def __init__(self, box, sleep=time.sleep, clock=time.monotonic, site='F2'):
        self.box, self.sleep, self.clock = box, sleep, clock
        self.site = site

    def identity(self):
        require(self.box.read_u32(0xc0) == 0x20304 and
                self.box.read_u32(0xc4) == 0x20304, 'F2 identity mismatch')

    def healthy(self, sequence, run, active=False):
        b = self.box
        self.identity()
        require(b.read_u32(0xc8) == CAP | (ACTIVE if active else 0), 'F2 not healthy IDLE / session mismatch')
        require((b.read_u32(0xa0), b.read_u32(0xf0), b.read_u32(0xf8)) ==
                (sequence, sequence, run), 'F2 sequence/run mismatch')
        require(b.read_u32(0x9c) == 0x434da501, 'invalid clock monitor')
        for address, nominal in ((0x24, 100000), (0x28, 325000), (0x5c, 322266)):
            require(abs(b.read_u32(address) - nominal) < nominal * .001, 'required clock invalid')
        b.write_u8(0xcc, 0xfe)
        require(b.read_u32(0xd0) == 0x40 and b.read_u32(0xec) == 0, 'retained platform fault')
        prbs = b.read_u32(0xd4)
        require(prbs & 0x40000000 and not (prbs & 0x8000001f), 'controller not IDLE')

    def submit(self, sequence, previous, command, duration, mask):
        b = self.box
        self.identity()
        require(b.read_u32(0xa0) == previous and b.read_u32(0xf0) == previous, 'unexpected predecessor')
        require(b.read_u32(0xc8) & 0x1ffff == 0, 'engine busy or faulted')
        for address, value in ((0xa4, command), (0xa8, duration), (0xac, 0),
                               (0xb0, mask), (0xb4, 0), (0xb8, 0), (0xbc, 0)):
            b.write_u32(address, value)
            require(b.read_u32(address) == value, 'descriptor readback mismatch')
        print('SUBMIT %s sequence=%d command=%#x duration_ms=%d mask=%#x' %
              (self.site, sequence, command, duration, mask), flush=True)
        b.write_u32(0xa0, sequence)  # Exactly once, including transport errors.

    def response(self, sequence, code, run, timeout):
        b = self.box
        deadline = self.clock() + timeout
        while b.read_u32(0xf0) != sequence:
            require(self.clock() < deadline, 'response timeout; no retry')
            self.sleep(.05)
        actual = (b.read_u32(0xf4), b.read_u32(0xf8))
        print('RESPONSE %s sequence=%d code=%#x run=%d' % ((self.site, sequence,) + actual), flush=True)
        require(actual == (code, run), 'response/run failure')

    def evidence(self, label):
        print('EVIDENCE ' + self.site + ' ' + label, flush=True)
        # Attempt each block independently so one failed read cannot hide others.
        actions = [lambda: read_overview(self.box)]
        actions += [lambda lane=lane: print('%s lane=%d %r' %
                    (self.site, lane, read_lane(self.box, lane)), flush=True) for lane in range(12)]
        actions += [lambda: print_platform_diagnostics(self.box)]
        actions += [lambda a=a: print('%s register=%#x value=%#x' %
                    (self.site, a, self.box.read_u32(a)), flush=True)
                    for a in list(range(8, 0xa0, 4)) + list(range(0xa0, 0xc0, 4))]
        for action in actions:
            try:
                action()
            except Exception as error:
                print('EVIDENCE_READ_ERROR ' + str(error), flush=True)

    def records(self):
        b = self.box
        require(b.read_u32(0xfc) == SUMMARY and b.read_u32(0xf8) == 1, 'summary/run mismatch')
        records = {}
        for lane in range(12):
            record = read_lane(b, lane)
            records[lane] = dict(record)
            print('VALIDATE F2 lane=%d %r' % (lane, record), flush=True)
            require(record['errors'] == 0 and record['lock_losses'] == 0, 'lane errors/losses')
            if RX_MASK & (1 << lane):
                require(record['id_status'] == 0x1800 + lane and
                        record['tested_bits'] > 0 and record['valid_cycles'] > 0,
                        'selected lane record failure')
                require(record['tested_bits'] == record['valid_cycles'] * 80,
                        'tested-bit / valid-cycle denominator mismatch')
                require(abs(record['valid_cycles'] - EXPECTED_CYCLES) <= CYCLE_TOLERANCE,
                        'measurement duration outside fixed ten-second tolerance')
            else:
                # qualified_lock bit12 is sampled even on an unselected lane.
                require(record['id_status'] & ~0x1000 == lane and
                        record['tested_bits'] == 0 and record['valid_cycles'] == 0,
                        'excluded lane was selected or counted')
        require(b.read_u32(0xf8) == 1 and b.read_u32(0xfc) == SUMMARY,
                'publication changed while reading records')
        return records

    def stop_if_safe(self):
        b = self.box
        self.identity()
        state, sequence, ack, run = [b.read_u32(a) for a in (0xc8, 0xa0, 0xf0, 0xf8)]
        if state == CAP | ACTIVE and sequence == ack and (sequence, run) in ((1, 0), (2, 1)):
            self.submit(3, sequence, 3, 0, SESSION_MASK)
            self.response(3, 0, run, 5)
            require(b.read_u32(0xc8) == CAP, 'TX did not stop')
        else:
            print('NO_STOP state=%#x sequence=%d ack=%d run=%d; no reset/abort/retry; lease bounded at 180s' %
                  (state, sequence, ack, run), flush=True)

    def start(self):
        self.healthy(0, 0)
        self.evidence('preflight')
        try:
            self.submit(1, 0, 2, 180000, SESSION_MASK)
            self.response(1, 0, 0, 5)
            self.sleep(.1)
            self.healthy(1, 0, active=True)
            self.submit(2, 1, 0x10501, 10000, RX_MASK)
            self.response(2, SUMMARY, 1, 40)
            self.evidence('published-before-cleanup-observation')
            self.sleep(12)
            self.healthy(2, 1, active=True)
            receive_records = self.records()
        finally:
            # Preserve failure/publication before the stop command alters F4.
            self.evidence('before-session-stop')
            try:
                self.stop_if_safe()
            finally:
                self.evidence('final')
        self.healthy(3, 1)
        require(self.records() == receive_records, 'records changed across session stop')
        print('PASS: one F2 eleven-lane external receive measurement; TX stopped', flush=True)


def claim_start(directory):
    fd = os.open(os.path.join(directory, 'oneway.started'), os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    os.close(fd)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage', choices=('preflight', 'start', 'status', 'results'))
    args = parser.parse_args()
    require(REVIEW_RELEASED, 'HOLD: golden evidence, subset simulation and parent review pending')
    # Construct only F2; never access the golden F1 mailbox. MCU FP transactions
    # own I2C5 semaphore/mux selection through the installed cm_interface API.
    sys.path.insert(0, '/home/cms/25G')
    from cm_interface.registry import Registry
    registry = Registry(setup='tf', dev_path='/dev/ttyUL4')
    diagnostic = Diagnostic(FpgaMailbox(registry.fpgas['F2']))
    if args.stage == 'start':
        claim_start('.')
        diagnostic.start()
    elif args.stage == 'preflight':
        diagnostic.evidence('preflight')
        diagnostic.healthy(0, 0)
    else:
        diagnostic.evidence(args.stage)
        if args.stage == 'results':
            diagnostic.healthy(3, 1)
            diagnostic.records()


if __name__ == '__main__':
    main()
