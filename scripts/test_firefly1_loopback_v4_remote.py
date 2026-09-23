"""Offline failure-path tests; no board connection or writes."""
import contextlib
import io
from pathlib import Path
import runpy
import sys
import types
import unittest
from unittest.mock import patch


class GateTests(unittest.TestCase):
    def execute(self, stage, registers, lane_errors=0, site="F1"):
        writes = []
        class Mailbox:
            def __init__(self, fpga):
                pass
            def read_u32(self, address):
                return registers.get(address, 0)
            def write_u32(self, address, value):
                writes.append((address, value))
                registers[address] = value
                if address == 0xa0:
                    registers[0xc8] = 0x10000
        registry = types.ModuleType("cm_interface.registry")
        registry.Registry = lambda **kwargs: types.SimpleNamespace(fpgas={site: None})
        support = types.ModuleType("milestone3_12hour_external_soak")
        support.FpgaMailbox = Mailbox
        support.read_overview = lambda mailbox: None
        support.print_platform_diagnostics = lambda mailbox: None
        support.read_lane = lambda mailbox, lane: dict(
            id_status=0x801 | lane, errors=lane_errors, tested_bits=1000,
            valid_cycles=100, lock_losses=0)
        modules = {"cm_interface": types.ModuleType("cm_interface"),
                   "cm_interface.registry": registry,
                   "milestone3_12hour_external_soak": support}
        args = ["remote", stage, "--cm-interface-root", "/unused/cm_interface", "--fpga", site]
        with patch.dict(sys.modules, modules), patch.object(sys, "argv", args), patch("time.sleep"):
            with contextlib.redirect_stdout(io.StringIO()):
                try:
                    runpy.run_path(str(Path(__file__).with_name("firefly1_loopback_v4_remote.py")), run_name="__main__")
                except RuntimeError as error:
                    return writes, str(error)
        return writes, None

    def identity(self):
        return {0xc0: 0x20303, 0xc4: 0x20303, 0xd0: 0x40, 0xd4: 0x40000000}

    def test_wrong_identity_never_writes(self):
        writes, error = self.execute("start", {0xc0: 0x20302, 0xc4: 0x20302})
        self.assertEqual(writes, [])
        self.assertIn("version mismatch", error)

    def test_f2_only_and_no_retry(self):
        writes, error = self.execute("start", self.identity(), site="F2")
        self.assertEqual([w for w in writes if w[0] == 0xa0], [(0xa0, 1)])
        self.assertIn("request consumed", error)
        registers = self.identity()
        registers[0xa0] = 1
        self.assertEqual(self.execute("start", registers, site="F2")[0], [])

    def test_consumed_sequence_never_writes(self):
        registers = self.identity()
        registers[0xa0] = 1
        writes, error = self.execute("start", registers)
        self.assertEqual(writes, [])
        self.assertIn("not fresh", error)

    def test_fault_after_submission_never_retries(self):
        writes, error = self.execute("start", self.identity())
        self.assertEqual([write for write in writes if write[0] == 0xa0], [(0xa0, 1)])
        self.assertIn("request consumed", error)

    def test_results_require_clean_lanes_and_correct_summary(self):
        registers = self.identity()
        registers.update({0xf0: 1, 0xf8: 1, 0xf4: 0xc0c01, 0xfc: 0xc0c01})
        self.assertIsNone(self.execute("results", registers.copy())[1])
        self.assertIn("lane 0", self.execute("results", registers.copy(), lane_errors=1)[1])
        registers[0xfc] = 0xc000c04
        self.assertIn("summary mismatch", self.execute("results", registers)[1])

    def test_clean_measurement_with_retained_fault_is_not_a_pass(self):
        registers = self.identity()
        registers.update({0xf0: 1, 0xf8: 1, 0xf4: 0xc0c01, 0xfc: 0xc0c01,
                          0xc8: 0x10000})
        writes, error = self.execute("results", registers)
        self.assertEqual(writes, [])
        self.assertIn("retained platform fault", error)

if __name__ == "__main__":
    unittest.main()
