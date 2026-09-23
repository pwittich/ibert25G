#!/usr/bin/env python3
"""Offline tests for the all-links-v2 90-second launcher contracts."""
import unittest
from pathlib import Path
import sys
import tempfile

SCRIPT_DIRECTORY = str(Path(__file__).resolve().parent)
if SCRIPT_DIRECTORY not in sys.path:
    sys.path.insert(0, SCRIPT_DIRECTORY)

from all_links_v2_timed_common import firefly_mask, parse_quads, words_for_lanes
from all_links_v2_timed_contract import (
    DEFAULT_DURATION_SECONDS, DIRECT_MASKS, MAX_DURATION_SECONDS,
    expected_cycles, mask_lanes, validate_contract, validate_duration)
from all_links_v2_timed_report import write_report


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


if __name__ == "__main__":
    unittest.main()
