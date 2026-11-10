#!/usr/bin/env python3
"""Offline tests for the all-links-v2 timed launcher contracts."""
import argparse
import contextlib
import importlib
import io
import unittest
from unittest import mock
from pathlib import Path
import sys
import tempfile

SCRIPT_DIRECTORY = str(Path(__file__).resolve().parent)
if SCRIPT_DIRECTORY not in sys.path:
    sys.path.insert(0, SCRIPT_DIRECTORY)

import all_links_v2_timed_common as common
from all_links_v2_timed_common import (firefly_mask, parse_quads,
                                      resolve_predecessors, words_for_lanes)
from all_links_v2_timed_contract import (
    CAPABILITY, VERSION, DEFAULT_DURATION_SECONDS, DIRECT_MASKS,
    MAX_DURATION_SECONDS, add_predecessor_arguments, parse_predecessors,
    expected_cycles, mask_lanes, validate_contract, validate_duration)
from all_links_v2_timed_report import write_report


class FakeBox:
    def __init__(self, sequence=3, run=1):
        self.values = {0xc0: VERSION, 0xc4: VERSION, 0xc8: CAPABILITY,
                       0xa0: sequence, 0xf0: sequence, 0xf8: run,
                       0xd0: 0x40, 0xec: 0}
        self.writes = []

    def read_u32(self, address):
        return self.values[address]

    def write_u32(self, address, value):
        self.writes.append((address, value))
        self.values[address] = value


class TestPredecessorDiscovery(unittest.TestCase):
    def boxes(self):
        return {"F1": FakeBox(3, 1), "F2": FakeBox(12, 4)}

    def test_reads_independent_site_states_without_writing(self):
        boxes = self.boxes()
        with contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(resolve_predecessors(boxes),
                             {"F1": (3, 1), "F2": (12, 4)})
        self.assertIn("PREDECESSOR site=F1 sequence=3 run=1 mode=auto", output.getvalue())
        self.assertIn("PREDECESSOR site=F2 sequence=12 run=4 mode=auto", output.getvalue())
        self.assertTrue(all(not box.writes for box in boxes.values()))

    def test_rejects_busy_fault_session_pending_identity_and_exhaustion(self):
        for address, value in ((0xc8, CAPABILITY | 2),
                               (0xc8, CAPABILITY | (1 << 16)),
                               (0xc8, CAPABILITY | (1 << 17)),
                               (0xf0, 11), (0xc0, VERSION - 1),
                               (0xf8, 0xffffffff), (0xa0, 0xfffffffd)):
            with self.subTest(address=address, value=value):
                boxes = self.boxes()
                boxes["F2"].values[address] = value
                if address == 0xa0:
                    boxes["F2"].values[0xf0] = value
                with self.assertRaises(RuntimeError):
                    resolve_predecessors(boxes)
                self.assertTrue(all(not box.writes for box in boxes.values()))

    def test_rejects_incoherent_snapshot_without_writes(self):
        boxes = self.boxes()
        normal = boxes["F2"].read_u32
        reads = []
        def changing(address):
            reads.append(address)
            value = normal(address)
            return value + 1 if address == 0xf8 and len(reads) > 6 else value
        boxes["F2"].read_u32 = changing
        with self.assertRaisesRegex(RuntimeError, "state changed"):
            resolve_predecessors(boxes)
        self.assertTrue(all(not box.writes for box in boxes.values()))

    def test_optional_explicit_guards_still_reject_stale_command(self):
        boxes = self.boxes()
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(resolve_predecessors(boxes, {"F1": (3, 1), "F2": (12, 4)}),
                             {"F1": (3, 1), "F2": (12, 4)})
        with self.assertRaisesRegex(RuntimeError, "predecessor sequence/run mismatch"):
            resolve_predecessors(boxes, {"F1": (0, 0), "F2": (0, 0)})
        self.assertTrue(all(not box.writes for box in boxes.values()))

    def test_state_change_after_discovery_aborts_before_tx_start(self):
        boxes = self.boxes()
        def mutate_state(*args):
            boxes["F2"].values[0xa0] += 3
            boxes["F2"].values[0xf0] += 3
            boxes["F2"].values[0xf8] += 1
        with mock.patch.object(common, "telemetry_snapshot", side_effect=mutate_state), \
                mock.patch.object(common, "check_clocks"), \
                mock.patch.object(common, "submit") as submit, \
                contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(RuntimeError, "predecessor sequence/run mismatch"):
                common.run_inter_fpga(None, boxes, None, 180)
        submit.assert_not_called()
        self.assertFalse(any(address == 0xa0 for box in boxes.values()
                             for address, value in box.writes))


class TestOptionalPredecessorCLI(unittest.TestCase):
    def test_all_or_none_guards_and_counter_bounds(self):
        parser = argparse.ArgumentParser()
        add_predecessor_arguments(parser)
        self.assertIsNone(parse_predecessors(parser, parser.parse_args([])))
        arguments = ["--f1-sequence", "3", "--f1-run", "1",
                     "--f2-sequence", "12", "--f2-run", "4"]
        self.assertEqual(parse_predecessors(parser, parser.parse_args(arguments)),
                         {"F1": (3, 1), "F2": (12, 4)})
        for invalid in (["--f1-sequence", "3"],
                        ["--f1-sequence", "-1"] + arguments[2:],
                        ["--f1-sequence", str(0xfffffffd)] + arguments[2:]):
            with self.subTest(arguments=invalid), contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit):
                    parse_predecessors(parser, parser.parse_args(invalid))

    def test_remote_runners_accept_no_manual_counters_under_lock(self):
        cases = (("test_all_links_v2_inter_fpga", [], "--acknowledge-all-firefly-tx", "run_inter_fpga"),
                 ("test_all_links_v2_firefly_loopback", ["q121,q124"], "--acknowledge-all-managed-tx", "run_firefly"))
        for module_name, quad_args, acknowledgement, runner in cases:
            entry = importlib.import_module(module_name)
            argv = [module_name] + quad_args + ["--duration-seconds", "180", acknowledgement]
            boxes = object()
            with self.subTest(script=module_name), \
                    mock.patch.object(sys, "argv", argv), \
                    mock.patch.object(entry, "acquire_lock", return_value=123) as lock, \
                    mock.patch.object(entry, "load_registry") as registry, \
                    mock.patch.object(entry, "make_boxes", return_value=boxes), \
                    mock.patch.object(entry, runner) as run, \
                    mock.patch.object(entry.os, "close") as close:
                registry.side_effect = lambda: lock.assert_called_once_with()
                self.assertEqual(entry.main(), 0)
                self.assertEqual(run.call_args[0][-2:], (None, 180))
                close.assert_called_once_with(123)

    def test_workstation_wrappers_forward_only_supplied_guards(self):
        cases = (("board_all_links_v2_inter_fpga", [], "--acknowledge-all-firefly-tx"),
                 ("board_all_links_v2_firefly_loopback", ["q121,q124"], "--acknowledge-all-managed-tx"))
        guards = ["--f1-sequence", "3", "--f1-run", "1",
                  "--f2-sequence", "12", "--f2-run", "4"]
        for module_name, quad_args, acknowledgement in cases:
            entry = importlib.import_module(module_name)
            for extra in ([], guards):
                argv = [module_name, "run"] + quad_args + [acknowledgement] + extra
                with self.subTest(script=module_name, guards=extra), \
                        mock.patch.object(sys, "argv", argv), \
                        mock.patch.object(entry, "run_remote") as run:
                    self.assertEqual(entry.main(), 0)
                    forwarded = run.call_args[0][1]
                    self.assertEqual("--f1-sequence" in forwarded, bool(extra))
                    if extra:
                        for flag, value in zip(guards[::2], guards[1::2]):
                            self.assertEqual(forwarded[forwarded.index(flag) + 1], value)


class TestAllLinksV290sHelpers(unittest.TestCase):
    def test_contract_is_consistent_and_released(self):
        self.assertTrue(validate_contract(require_release=False))
        self.assertTrue(validate_contract(require_release=True))
        self.assertEqual(DEFAULT_DURATION_SECONDS, 90)
        self.assertEqual(validate_duration(DEFAULT_DURATION_SECONDS), 90000)
        self.assertEqual(expected_cycles(90000), 29003906250)

    def test_duration_validation_and_scaling(self):
        self.assertEqual(validate_duration(1), 1000)
        self.assertEqual(validate_duration(300), 300000)
        self.assertEqual(expected_cycles(300000), 96679687500)
        self.assertEqual(validate_duration(MAX_DURATION_SECONDS),
                         MAX_DURATION_SECONDS * 1000)
        for value in (0, -1, MAX_DURATION_SECONDS + 1, 1.5, True):
            with self.assertRaises(ValueError):
                validate_duration(value)

    def test_quad_selector_and_packing(self):
        self.assertEqual(parse_quads("q121"), (121,))
        self.assertEqual(parse_quads("121-123,q125"), (121, 122, 123, 125))
        self.assertEqual(mask_lanes(firefly_mask(parse_quads("q121-q134"))),
                         tuple(range(56)))
        with self.assertRaises(ValueError):
            parse_quads("q120")
        with self.assertRaises(ValueError):
            parse_quads("q134-q133")

    def test_fitted_direct_masks(self):
        self.assertEqual(len(mask_lanes(DIRECT_MASKS["F1"])), 54)
        self.assertEqual(len(mask_lanes(DIRECT_MASKS["F2"])), 54)
        self.assertNotIn(70, mask_lanes(DIRECT_MASKS["F1"]))
        self.assertNotIn(71, mask_lanes(DIRECT_MASKS["F1"]))
        self.assertNotIn(96, mask_lanes(DIRECT_MASKS["F2"]))
        self.assertNotIn(97, mask_lanes(DIRECT_MASKS["F2"]))
        self.assertEqual(words_for_lanes(mask_lanes(DIRECT_MASKS["F1"])),
                         DIRECT_MASKS["F1"])

    def test_immutable_pass_report(self):
        clocks = []
        names = ["clock_%d" % value for value in range(2, 39)]
        names[0] = "clk_200_ext"
        names[7] = "clk_100"
        names[8] = "clk_325"
        reference_registers = (11, 12, 14, 15, 16, 17, 18, 19,
                               20, 21, 22, 23)
        for site in ("F1", "F2"):
            for register, name in zip(range(2, 39), names):
                value = (200000 if register == 2 else
                         100000 if register == 9 else
                         325000 if register == 10 else
                         322260 if register in reference_registers else 40080)
                clocks.append("CLOCK site=%s r=%02d name=%s khz=%d" %
                              (site, register, name, value))
        lines = clocks + [
            "POWER12V label=pre volts=12 amps=10 watts=120",
            "FPGA_DIODE_TEMP label=pre sensor=F1_TEMP celsius=40",
            "FPGA_DIODE_TEMP label=pre sensor=F2_TEMP celsius=41",
            "LGA80D_TEMP label=pre device=F1 page=0 sensor=1 celsius=42",
            "FIREFLY_TEMP label=pre device=F1_1 address=0x21 celsius=43",
            "RECORD site=F1 run=1 lane=56 data={'id_status': 6200, 'errors': 0, 'tested_bits': 800, 'lock_losses': 0, 'valid_cycles': 10}",
            "RECORD site=F2 run=1 lane=56 data={'id_status': 6200, 'errors': 0, 'tested_bits': 800, 'lock_losses': 0, 'valid_cycles': 10}",
            "PASS INTER_FPGA duration_seconds=90 fitted_rx_lanes_per_endpoint=54 errors=0",
        ]
        with tempfile.TemporaryDirectory() as directory:
            evidence = Path(directory) / "evidence.log"
            evidence.write_text("\n".join(lines) + "\n")
            arguments = ["--f1-sequence", "0", "--f1-run", "0",
                         "--f2-sequence", "0", "--f2-run", "0",
                         "--duration-seconds", "90"]
            report = write_report(evidence,
                                  "test_all_links_v2_inter_fpga.py",
                                  arguments, "inter-fpga-90s", 0, "deadbeef")
            text = report.read_text()
            self.assertIn("**PASS**", text)
            self.assertEqual(text.count("| PASS | 37/37 |"), 2)
            self.assertIn("| F1 | 1 | 1 | 0 | 0 | 800–800 | 1 |", text)
            with self.assertRaises(FileExistsError):
                write_report(evidence,
                             "test_all_links_v2_inter_fpga.py",
                             arguments, "inter-fpga-90s", 0, "deadbeef")

    def test_failure_report_preserves_nonclean_lane_and_tail(self):
        lines = [
            "RECORD site=F2 run=2 lane=9 data={'id_status': 22537, 'errors': 4294967295, 'tested_bits': 800, 'lock_losses': 0, 'valid_cycles': 10}",
            "RuntimeError: F2 lane 9 has PRBS errors or native lock losses",
        ]
        with tempfile.TemporaryDirectory() as directory:
            evidence = Path(directory) / "failed.log"
            evidence.write_text("\n".join(lines) + "\n")
            report = write_report(
                evidence, "test_all_links_v2_firefly_loopback.py",
                ["q121-q123", "--duration-seconds", "180"],
                "firefly-q121-q123-180s", 1, "deadbeef")
            text = report.read_text()
            self.assertIn("**FAIL**", text)
            self.assertIn("FireFly receive selection: `q121-q123`", text)
            self.assertIn("| F2 | 9 | `0x5809` | 4294967295 | 0 | 800 |", text)
            self.assertIn("## Failure tail", text)

    def test_report_records_auto_discovered_start_states(self):
        lines = ["PREDECESSOR site=F1 sequence=3 run=1 mode=auto",
                 "PREDECESSOR site=F2 sequence=12 run=4 mode=auto",
                 "RuntimeError: no hardware used in this report test"]
        with tempfile.TemporaryDirectory() as directory:
            evidence = Path(directory) / "auto.log"
            evidence.write_text("\n".join(lines) + "\n")
            report = write_report(evidence, "test_all_links_v2_inter_fpga.py",
                                  ["--duration-seconds", "180"],
                                  "inter-fpga-180s", 1, "deadbeef")
            self.assertIn("Starting F1 sequence/run: 3/1", report.read_text())
            self.assertIn("Starting F2 sequence/run: 12/4", report.read_text())


if __name__ == "__main__":
    unittest.main()
