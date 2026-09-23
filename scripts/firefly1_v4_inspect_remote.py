#!/usr/bin/env python3
"""Read registers only, sequentially through the MCU's mux/semaphore API."""
import sys
sys.path.insert(0, '/home/cms/25G')
from cm_interface.registry import Registry

stage = sys.argv[1]
if stage not in ('preflight', 'verify', 'pma-complete'):
    raise RuntimeError('invalid stage')
registry = Registry(setup='tf', dev_path='/dev/ttyUL4')
failures = []
for site in ('F1', 'F2'):
    fpga = registry.fpgas[site]
    def read(address):
        data = bytes(fpga.read_reg(address, size=4))
        if len(data) != 4:
            raise RuntimeError('short register read')
        return int.from_bytes(data, 'little')
    try:
        values = {a: read(a) for a in (0x9c, 0xc0, 0xc4, 0xc8, 0xa0, 0xf0, 0xf4, 0xf8, 0xfc)}
        print(site + ' mailbox ' + ' '.join('%02x=%08x' % (a, v) for a, v in sorted(values.items())), flush=True)
        clocks = {r: read(r * 4) for r in range(2, 39)}
        for r, value in sorted(clocks.items()):
            print('%s r%02d clock_khz=%d' % (site, r, value), flush=True)
        if site == 'F1' or stage in ('verify', 'pma-complete'):
            expected_id = 1 if site == 'F1' or stage == 'pma-complete' else 0
            expected_summary = 0x000c0c01 if expected_id else 0
            for a, expected in ((0x9c, 0x434da501), (0xc0, 0x20303), (0xc4, 0x20303),
                                (0xc8, 0), (0xa0, expected_id), (0xf0, expected_id),
                                (0xf8, expected_id), (0xf4, expected_summary), (0xfc, expected_summary)):
                if values[a] != expected:
                    failures.append('%s register %02x unexpected %08x' % (site, a, values[a]))
            for r, nominal in ((9, 100000), (10, 325000), (23, 322266)):
                if abs(clocks[r] - nominal) > nominal * 0.001:
                    failures.append('%s required clock r%d out of tolerance' % (site, r))
    except Exception as error:
        print('%s READ_FAILURE %s' % (site, error), flush=True)
        if site == 'F1' or stage in ('verify', 'pma-complete'):
            failures.append('%s register access failed' % site)
if failures:
    raise RuntimeError('; '.join(failures))
print('PASS: ' + stage + ' register/clock checks; no requests or writes')
