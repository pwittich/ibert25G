"""Offline fixed-gate protocol tests; no hardware transport."""
import contextlib
import io
import runpy
import sys
import types
import unittest
from pathlib import Path
from unittest.mock import patch


class V5Gates(unittest.TestCase):
    def execute(self, stage, wrong_version=False, fail_first=False, deny_session=False):
        writes = []
        initial = 0 if stage == 'pma' else 1
        registers = {site: {0xc0: 0x20303 if wrong_version else 0x20304,
                            0xc4: 0x20304, 0xc8: 1 << 20, 0xa0: initial,
                            0xf0: initial, 0xf8: initial, 0xf4: 0, 0xfc: 0,
                            0x9c: 0x434da501, 0x24: 100000, 0x28: 325000,
                            0x5c: 322260, 0xd0: 0x40, 0xd4: 0x40000000, 0xec: 0}
                     for site in ('F1', 'F2')}
        class Box:
            def __init__(self, site): self.site = site
            def read_u32(self, address): return registers[self.site].get(address, 0)
            def write_u32(self, address, value):
                writes.append((self.site, address, value))
                r = registers[self.site]
                r[address] = value
                if address == 0xa0:
                    command = r[0xa4]
                    r[0xf0] = value
                    if command == 2:
                        r[0xf4] = 1 if deny_session else 0
                        if not deny_session: r[0xc8] |= 1 << 17
                    elif command == 3:
                        r[0xf4] = 0; r[0xc8] &= ~(1 << 17)
                    else:
                        r[0xf8] += 1
                        r[0xf4] = r[0xfc] = 0x010b0c01 if fail_first else 0xc0c01
        registry = types.ModuleType('cm_interface.registry')
        registry.Registry = lambda **kwargs: types.SimpleNamespace(fpgas={s: s for s in registers})
        support = types.ModuleType('milestone3_12hour_external_soak')
        support.FpgaMailbox = Box
        support.read_lane = lambda box, lane: dict(id_status=0x1800+lane, errors=0,
                                                  lock_losses=0, tested_bits=800, valid_cycles=10)
        support.read_overview = support.print_platform_diagnostics = lambda box: None
        with patch.dict(sys.modules, {'cm_interface.registry': registry,
                                      'milestone3_12hour_external_soak': support}), patch.object(
                sys, 'argv', ['remote', stage]), patch('os.open', return_value=999), patch('os.close'), patch('time.sleep'), contextlib.redirect_stdout(io.StringIO()):
            try:
                runpy.run_path(str(Path(__file__).with_name('firefly1_v5_remote.py')))
                return writes, None
            except RuntimeError as error:
                return writes, str(error)

    def test_pma_fixed_once_each(self):
        writes, error = self.execute('pma')
        self.assertIsNone(error)
        self.assertEqual([w for w in writes if w[1] == 0xa0], [('F1', 0xa0, 1), ('F2', 0xa0, 1)])

    def test_external_two_runs_and_explicit_stop(self):
        writes, error = self.execute('external')
        self.assertIsNone(error)
        for site in ('F1', 'F2'):
            self.assertEqual([w[2] for w in writes if w[:2] == (site, 0xa0)], [2, 3, 4, 5])

    def test_bad_identity_never_submits(self):
        writes, error = self.execute('external', wrong_version=True)
        self.assertIn('wrong version', error)
        self.assertFalse(any(w[1] == 0xa0 for w in writes))

    def test_failed_first_measurement_not_retried(self):
        writes, error = self.execute('external', fail_first=True)
        self.assertIn('response/run failure', error)
        for site in ('F1', 'F2'):
            self.assertEqual([w[2] for w in writes if w[:2] == (site, 0xa0)], [2, 3, 5])

    def test_failed_session_never_starts_receiver(self):
        writes, error = self.execute('external', deny_session=True)
        self.assertIsNotNone(error)
        self.assertEqual([w[2] for w in writes if w[1] == 0xa0], [2])

if __name__ == '__main__':
    unittest.main()
