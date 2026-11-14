#!/usr/bin/env python3
"""Offline protocol/data/cleanup tests; never constructs a board registry."""
import ast
import contextlib
import importlib.util
import io
import json
import math
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import board_eye_scan as op
import eye_scan_data as data
import eye_scan_v1_contract as contract
from package_eye_scan_v1_runtime import package


def raw_point(job=9, lane=0, h=0, v=0, p=0, errors=3, samples=100,
              lpm=True, errors1=0, samples1=0, status=0, measurements=None):
    flags = (1 if lpm else 3) if measurements is None else measurements
    meta = 1 | 8 | (flags << 4) | (status << 6) | (int(lpm) << 14) | (p << 15) | (lane << 20) | (3 << 27)
    return [0x45594401, job, meta, (h & 2047) | ((v & 511) << 11),
            errors | (samples << 16), errors1 | (samples1 << 16), 100, 0x50020101]


class Box:
    def __init__(self, tx=False):
        self.regs = {0xc0: contract.VERSION, 0xc4: contract.VERSION, 0xc8: op.CAPABILITY,
                     0xa0: 41, 0xf0: 41, 0xf4: 0, 0xf8: 7}
        self.selector = 0
        self.selected = 0
        self.events = []
        self.tx = tx
        self.bad_page = None
        self.corrupt = None
        self.pg = dict(job=8, busy=False, available=False, fatal=False, reason=0, count=0)
        self.points = []

    def read_u32(self, address):
        if address == self.corrupt:
            return self.regs.get(address, 0) ^ 1
        if 0xd0 <= address < 0xf0:
            index = (address - 0xd0) // 4
            if self.selector == 0xf6:
                status = int(self.pg["busy"]) | (int(self.pg["available"]) << 1) | (
                    int(self.pg["fatal"]) << 2) | (self.pg["reason"] << 16)
                return [0x45595001, self.pg["job"], status, self.pg["count"], 0, 0, 100, 0][index]
            if self.selector == 0xf7:
                mask = int(self.tx)
                return [0x51430001, mask, mask, mask, mask, 1, 0x102, 0][index]
            if self.selector == 0xf5:
                if self.selected == self.bad_page:
                    return 0
                return self.points[self.selected][index]
            if self.selector == 0x80:
                return 0x51530080 if index == 0 else 0
        return self.regs.get(address, 0)

    def write_u8(self, address, value):
        base = address & ~3
        shift = (address & 3) * 8
        word = (self.regs.get(base, 0) & ~(255 << shift)) | (value << shift)
        self.write_u32(base, word)

    def write_u32(self, address, value):
        self.regs[address] = value
        if address == 0xcc:
            self.selector = value
        if address == 0xa0:
            command = self.regs[0xa4]
            self.events.append(command)
            self.regs[0xf0] = value
            self.regs[0xf4] = 0
            if command == 2:
                self.regs[0xc8] = op.CAPABILITY | op.SESSION_ACTIVE | op.SESSION_READY
            elif command == 3:
                self.regs[0xc8] = op.CAPABILITY
            elif command == 5:
                self.pg.update(job=9, busy=True, count=0)
            elif command == 6:
                self.points = [raw_point(status=2, measurements=0)]
                self.pg.update(busy=False, available=True, count=1, reason=2)
            elif command == 7:
                self.selected = self.regs[0xb0]
                self.selector = 0xf5


class EyeTests(unittest.TestCase):
    def setUp(self):
        self.output = contextlib.redirect_stdout(io.StringIO())
        self.output.__enter__()

    def tearDown(self):
        self.output.__exit__(None, None, None)

    def test_default_matrix_and_encoding(self):
        d = data.descriptor(221, 2, "-32:32:2", "-120:120:8", 5, 120000, 1000)
        self.assertEqual(d["global_lane"], 58)
        self.assertEqual(len(d["xs"]) * len(d["ys"]), 1023)
        self.assertEqual(data.signed((d["words"][0] >> 7) & 127, 7), -32)
        self.assertEqual(data.signed(d["words"][1] & 255, 8), -120)

    def test_invalid_descriptors(self):
        cases = [(120, 0, "0:0:1", "0:0:1", 0, 2000, 1000),
                 (121, 4, "0:0:1", "0:0:1", 0, 2000, 1000),
                 (121, 0, "-33:32:1", "0:0:1", 0, 2000, 1000),
                 (121, 0, "0:0:0", "0:0:1", 0, 2000, 1000),
                 (121, 0, "-32:32:1", "-127:127:1", 0, 2000, 1000),
                 (121, 0, "0:0:1", "0:0:1", 31, 2000, 1000),
                 (121, 0, "-32:32:2", "-120:120:8", 5, 11, 1000)]
        for args in cases:
            with self.subTest(args=args), self.assertRaises(ValueError):
                data.descriptor(*args)

    def test_lpm_and_maximum_prescale(self):
        p = data.decode_point(raw_point(h=-32, v=-127, p=31), 9, 0)
        self.assertTrue(p["complete"])
        self.assertEqual(p["horizontal"], -32)
        self.assertEqual(p["vertical"], -127)
        self.assertEqual(p["bits0"], 100 * 80 * (1 << 32))

    def test_dfe_averages_ratios_with_distinct_denominators(self):
        p = data.decode_point(raw_point(lpm=False, errors=2, samples=100, errors1=9, samples1=300))
        self.assertAlmostEqual(p["mismatch_ratio"], .5 * (2 / 16000.0 + 9 / 48000.0))

    def test_zero_count_bounds(self):
        p = data.decode_point(raw_point(errors=0))
        self.assertAlmostEqual(p["zero_error_upper95"], -math.expm1(math.log(.05) / 16000))
        p = data.decode_point(raw_point(errors=0, lpm=False, samples1=200))
        self.assertAlmostEqual(p["zero_error_upper95"], .5 * (
            -math.expm1(math.log(.025) / 16000) - math.expm1(math.log(.025) / 32000)))

    def test_partial_and_failed_points_not_valid_ber(self):
        for raw in (raw_point(status=2), raw_point(samples=0, errors=0),
                    raw_point(lpm=False, measurements=1), raw_point(errors=65535, samples=1)):
            p = data.decode_point(raw)
            self.assertFalse(p["complete"])
            self.assertIsNone(p["mismatch_ratio"])

    def test_schema_and_identity(self):
        with self.assertRaises(ValueError): data.decode_point(raw_point(), 10)
        with self.assertRaises(ValueError): data.decode_point(raw_point(), 9, 1)
        raw = raw_point(); raw[7] = 0
        with self.assertRaises(ValueError): data.decode_point(raw)

    def test_sequence_gray_byte_carries_and_long_retrieval(self):
        box = Box()
        for start in (0, 0xff, 0xffff, 0xffffff, 0x12345678):
            box.regs[0xa0] = box.regs[0xf0] = start
            seen = {start}
            for _ in range(4200):
                previous = box.regs[0xa0]
                value = op.issue("F1", box, 9)
                delta = previous ^ value
                self.assertEqual(delta & (delta - 1), 0)
                self.assertNotIn(value, seen)
                seen.add(value)

    def test_request_sequence_last_and_run_unchanged(self):
        box = Box()
        self.assertEqual(op.issue("F1", box, 6, operands=(9, 0, 0, 0)), op.next_sequence(41))
        self.assertEqual(box.events, [6])
        self.assertEqual(box.regs[0xf8], 7)

    def test_status_can_report_pending_request(self):
        box = Box(); box.regs[0xa0] = 42
        self.assertEqual(op.identity("F1", box, ready=False)["acknowledgement"], 41)
        with self.assertRaises(RuntimeError): op.identity("F1", box)

    def test_scan_does_not_disturb_an_unowned_peer_job(self):
        boxes = {"F1": Box(tx=True), "F2": Box()}; boxes["F2"].pg["busy"] = True
        args = argparse_namespace(receiver="F1", transmitter="F1", tx_quad=121, acknowledge_firefly_tx=True)
        request = data.descriptor(121, 0, "0:0:1", "0:0:1", 0, 2000, 1000)
        with mock.patch.object(op, "check_clocks", return_value={}):
            with self.assertRaisesRegex(RuntimeError, "unowned eye job"):
                op.run_scan(args, object(), boxes, request, Path("unused"))
        self.assertEqual(boxes["F1"].events + boxes["F2"].events, [])

    def test_staging_failure_never_rings_doorbell(self):
        box = Box(); box.corrupt = 0xb4
        with self.assertRaises(RuntimeError): op.issue("F1", box, 5)
        self.assertEqual(box.events, [])
        self.assertEqual(box.regs[0xa0], 41)

    def test_fetch_checks_job_and_retains_partial_on_failure(self):
        box = Box(); box.pg.update(job=9, available=True, count=2)
        box.points = [raw_point(h=0), raw_point(h=2)]
        self.assertEqual(len(op.fetch("F1", box, 9, 0)), 2)
        box.bad_page = 1
        partial = []
        with self.assertRaises(ValueError): op.fetch("F1", box, 9, 0, partial)
        self.assertEqual(len(partial), 1)
        with self.assertRaises(RuntimeError): op.fetch("F1", box, 10, 0)

    def test_release_guard_before_registry_access(self):
        with mock.patch.object(op, "load_registry", side_effect=AssertionError("hardware touched")):
            with self.assertRaisesRegex(RuntimeError, "UNRELEASED"):
                op.main(["configure", "--site", "F1", "--tx", "none", "--rx", "q121"])
            with self.assertRaisesRegex(RuntimeError, "UNRELEASED"):
                op.main(["scan", "--receiver", "F1", "--quad", "121", "--lane", "0",
                         "--transmitter", "F1", "--tx-quad", "121"])

    def test_failed_scan_cancels_stops_and_preserves_results(self):
        boxes = {"F1": Box(tx=True), "F2": Box()}
        args = argparse_namespace(receiver="F1", transmitter="F1", tx_quad=121, acknowledge_firefly_tx=True)
        request = data.descriptor(121, 0, "0:0:1", "0:0:1", 0, 2000, 1000)
        real_progress = op.progress
        injected = []
        def progress(site, box):
            if box.pg["job"] == 9 and box.pg["busy"] and not injected:
                injected.append(1)
                raise RuntimeError("injected monitoring failure")
            return real_progress(site, box)
        with tempfile.TemporaryDirectory() as root, mock.patch.object(op, "progress", progress), \
                mock.patch.object(op, "check_clocks", return_value={}), \
                mock.patch.object(op, "telemetry_snapshot"), mock.patch.object(op.time, "sleep"):
            prefix = Path(root) / "failed"
            with self.assertRaisesRegex(RuntimeError, "injected monitoring failure"):
                op.run_scan(args, object(), boxes, request, prefix)
            saved = json.loads(Path(str(prefix) + ".json").read_text())
            self.assertEqual(boxes["F1"].events, [2, 5, 6, 3, 7])
            self.assertEqual(boxes["F1"].regs[0xc8], op.CAPABILITY)
            self.assertEqual(len(saved["points"]), 1)
            self.assertEqual(saved["points"][0]["status"], 2)
            self.assertTrue(saved["errors"])
            self.assertNotIn(8, boxes["F1"].events)

    def test_clean_matrix_does_not_hide_final_platform_fault(self):
        class PostFaultBox(Box):
            def write_u32(self, address, value):
                super().write_u32(address, value)
                if address == 0xa0 and self.regs[0xa4] == 5:
                    self.points = [raw_point()]
                    self.pg.update(busy=False, available=True, count=1)
                if address == 0xa0 and self.regs[0xa4] == 3:
                    self.regs[0xc8] |= 1 << 16
        boxes = {"F1": PostFaultBox(tx=True), "F2": Box()}
        args = argparse_namespace(receiver="F1", transmitter="F1", tx_quad=121, acknowledge_firefly_tx=True)
        request = data.descriptor(121, 0, "0:0:1", "0:0:1", 0, 2000, 1000)
        with tempfile.TemporaryDirectory() as root, mock.patch.object(op, "check_clocks", return_value={}), \
                mock.patch.object(op, "telemetry_snapshot"):
            prefix = Path(root) / "post-fault"
            with self.assertRaisesRegex(RuntimeError, "healthy final IDLE"):
                op.run_scan(args, object(), boxes, request, prefix)
            saved = json.loads(Path(str(prefix) + ".json").read_text())
            self.assertTrue(saved["points"][0]["complete"])
            self.assertEqual(saved["final"]["F1"]["state"], op.CAPABILITY | (1 << 16))

    def test_runtime_bundle_preserves_release_hold(self):
        with tempfile.TemporaryDirectory() as root:
            target = package(Path(root) / "bundle")
            manifest = json.loads((target / "eye_scan_v1_runtime_manifest.json").read_text())
            self.assertFalse(manifest["released"])
            self.assertEqual(set(manifest["files"]), set(contract.RUNTIME_FILES))
            with self.assertRaises(FileExistsError): package(target)

    def test_python36_grammar(self):
        root = Path(__file__).resolve().parent
        for name in contract.RUNTIME_FILES + ("package_eye_scan_v1_runtime.py",):
            ast.parse((root / name).read_text(), filename=name, feature_version=(3, 6))

    def test_csv_is_exclusive(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / "points.csv"
            data.write_csv(path, [data.decode_point(raw_point())])
            self.assertIn("samples0", path.read_text())
            with self.assertRaises(FileExistsError): data.write_csv(path, [])

    @unittest.skipUnless(importlib.util.find_spec("matplotlib"), "matplotlib unavailable")
    def test_plot_uses_raw_counters_and_exports_png_pdf(self):
        points = [dict(raw_words=raw_point(h=h, v=v, errors=0 if h == v == 0 else 3), mismatch_ratio=1)
                  for v in (-8, 0, 8) for h in (-4, 0, 4)]
        doc = dict(schema=data.SCHEMA, synthetic=True, job=9, global_lane=0,
                   site="F1", quad=121, lane=0, points=points,
                   requested=dict(xs=[-8, -4, 0, 4, 8], ys=[-16, -8, 0, 8, 16]))
        from matplotlib.axes import Axes
        original = Axes.pcolormesh
        meshes = []
        def capture(panel, *args, **kwargs):
            if len(args) == 3 and getattr(args[0], "ndim", 0) == 1:
                meshes.append(args)
            return original(panel, *args, **kwargs)
        with tempfile.TemporaryDirectory() as root:
            prefix = Path(root) / "eye"
            with mock.patch.object(Axes, "pcolormesh", capture):
                data.plot(doc, prefix)
            matrix = next(args[2] for args in meshes if args[2].shape == (5, 5))
            self.assertTrue(matrix.mask[0].all() and matrix.mask[-1].all())
            self.assertTrue(matrix.mask[:, 0].all() and matrix.mask[:, -1].all())
            self.assertTrue(Path(str(prefix) + ".png").read_bytes().startswith(b"\x89PNG"))
            self.assertTrue(Path(str(prefix) + ".pdf").read_bytes().startswith(b"%PDF"))
            with self.assertRaises(FileExistsError): data.plot(doc, prefix)

    def test_plot_rejects_point_outside_requested_grid(self):
        doc = dict(schema=data.SCHEMA, job=9, global_lane=0,
                   requested=dict(xs=[0], ys=[0]),
                   points=[dict(raw_words=raw_point(h=4))])
        with self.assertRaisesRegex(ValueError, "outside the requested matrix"):
            data.plot(doc, "/tmp/eye-outside-grid-must-not-be-created")


def argparse_namespace(**values):
    from argparse import Namespace
    return Namespace(**values)


if __name__ == "__main__":
    unittest.main()
