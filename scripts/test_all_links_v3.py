#!/usr/bin/env python3
"""Offline v3 selection, request, release and state-contract tests."""
import ast
import contextlib
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import all_links_v3_contract as contract
import board_all_links_v3 as cli
import package_all_links_v3_runtime as packaging


class Box:
    def __init__(self):
        self.values = {0xc0: contract.VERSION, 0xc4: contract.VERSION,
                       0xc8: 1 << 20, 0xa0: 3, 0xf0: 3, 0xf8: 1}
        self.writes = []
    def read_u32(self, address):
        return self.values.get(address, 0)
    def write_u32(self, address, value):
        self.writes.append((address, value))
        self.values[address] = value


class V3Tests(unittest.TestCase):
    def test_presets_scope_only_requested_transmitters_and_receivers(self):
        self.assertEqual(cli.preset_masks("enable-inter-fpga"), {"F1": 0xfffc000, "F2": 0xfffc000})
        self.assertEqual(cli.preset_masks("loopback-four"), {"F1": 15, "F2": 15})
        self.assertEqual(cli.preset_masks("loopback-four", "q121,q123,q125,q127", "q131-q134"),
                         {"F1": 85, "F2": 15 << 10})
        for spec in ("all", "none", "q121-q123", "q121-q125", "q221-q224", "q121,q121,q122,q123"):
            with self.subTest(spec=spec), self.assertRaises(RuntimeError):
                cli.preset_masks("loopback-four", spec)

    def test_both_presets_retain_release_guard_before_hardware_access(self):
        for stage, options in (("enable-inter-fpga", []), ("loopback-four", ["--acknowledge-firefly-tx"])):
            with mock.patch.object(sys, "argv", ["preset"] + options), \
                 mock.patch.object(cli, "load_registry") as registry, \
                 mock.patch.object(cli.subprocess, "check_output") as git:
                with self.assertRaisesRegex(RuntimeError, "UNRELEASED"):
                    cli.main(stage)
                registry.assert_not_called(); git.assert_not_called()

    def test_loopback_preset_requires_acknowledgement_before_access(self):
        with mock.patch.object(sys, "argv", ["loopback"]), mock.patch.object(cli, "load_registry") as registry:
            with self.assertRaisesRegex(RuntimeError, "FireFly TX acknowledgement"):
                cli.main("loopback-four")
            registry.assert_not_called()

    def test_preset_dispatch_keeps_configuration_only_separate_from_testing(self):
        for stage, options, should_test in (
                ("enable-inter-fpga", [], False),
                ("enable-inter-fpga", ["--test"], True),
                ("loopback-four", ["--acknowledge-firefly-tx"], True),
                ("loopback-four", ["--acknowledge-firefly-tx", "--configure-only"], False)):
            boxes = {"F1": Box(), "F2": Box()}
            with self.subTest(stage=stage, options=options), \
                 mock.patch.object(sys, "argv", ["preset"] + options), \
                 mock.patch.object(cli, "require_release"), mock.patch.object(cli, "validate_runtime"), \
                 mock.patch.object(cli.subprocess, "check_output", side_effect=[contract.CM_COMMIT.encode(), b"v1.0.3", b""]), \
                 mock.patch.object(cli, "acquire_lock", return_value=99), mock.patch.object(cli.os, "close"), \
                 mock.patch.object(cli, "load_registry", return_value="registry"), \
                 mock.patch.object(cli, "make_boxes", return_value=boxes), \
                 mock.patch.object(cli, "configure_pair") as configure, mock.patch.object(cli, "run_test") as run:
                cli.main(stage)
                masks = cli.preset_masks(stage)
                configure.assert_called_once_with(boxes, masks, {})
                self.assertEqual(run.call_count, int(should_test))
                if should_test:
                    run.assert_called_once_with("registry", boxes, masks, 90, stage == "loopback-four", {})

    def test_pair_preflights_second_site_before_first_config_write(self):
        boxes = {"F1": Box(), "F2": Box()}
        with mock.patch.object(cli, "configuration", return_value=(0,) * 6 + (0x100, 0)), \
             mock.patch.object(cli, "check_clocks", side_effect=[None, RuntimeError("F2 clock missing")]), \
             mock.patch.object(cli, "configure") as configure, contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(RuntimeError, "F2 clock missing"):
                cli.configure_pair(boxes, {"F1": 15, "F2": 15}, {})
        configure.assert_not_called()

    def test_pair_configures_exact_masks_and_stops_after_failure_without_retry(self):
        boxes = {"F1": Box(), "F2": Box()}
        with mock.patch.object(cli, "configuration", return_value=(0,) * 6 + (0x100, 0)), \
             mock.patch.object(cli, "check_clocks"), \
             mock.patch.object(cli, "configure", side_effect=[None, RuntimeError("F2 rejected")]) as configure, \
             contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(RuntimeError, "F2 rejected"):
                cli.configure_pair(boxes, {"F1": 15, "F2": 240}, {"F1": (3, 1), "F2": (3, 1)})
        self.assertEqual(configure.call_args_list,
                         [mock.call("F1", boxes["F1"], 15, 15, (3, 1)),
                          mock.call("F2", boxes["F2"], 240, 240, (3, 1))])

    def test_runtime_bundle_hashes_and_exclusive_creation(self):
        with tempfile.TemporaryDirectory() as temporary:
            parent = Path(temporary)
            source = parent / "source"; source.mkdir()
            for name in packaging.FILES:
                (source / name).write_text(name + "\n")
            target = packaging.package(parent / "bundle", source)
            with contextlib.redirect_stdout(io.StringIO()):
                cli.validate_runtime(target)
            with self.assertRaises(FileExistsError):
                packaging.package(target, source)
            (target / packaging.FILES[0]).write_text("changed\n")
            with self.assertRaisesRegex(RuntimeError, "hash mismatch"), contextlib.redirect_stdout(io.StringIO()):
                cli.validate_runtime(target)

    def test_missing_runtime_manifest_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaises(FileNotFoundError):
                cli.validate_runtime(temporary)

    def exercise_one_way_run(self, fail_records=False):
        class SimBox(Box):
            def __init__(self):
                super().__init__()
                self.run_once = False
                self.commands = []
            def read_u32(self, address):
                if address == 0xc8 and self.run_once:
                    self.run_once = False
                    return self.values[address] | 2
                return super().read_u32(address)
            def write_u32(self, address, value):
                super().write_u32(address, value)
                if address == 0xa0:
                    command = self.values[0xa4]
                    self.commands.append(command)
                    self.values[0xf0] = value
                    self.values[0xf4] = 0
                    if command == 2:
                        self.values[0xc8] |= cli.SESSION_ACTIVE | cli.SESSION_READY
                    elif command == 3:
                        self.values[0xc8] = cli.CAPABILITY
                    else:
                        self.run_once = True
                        self.values[0xf8] += 1
        boxes = {"F1": SimBox(), "F2": SimBox()}
        configs = {"F1": (0x51430001, 1, 0, 1, 0, 1, 0x102, 0),
                   "F2": (0x51430001, 0, 1, 0, 1, 1, 0x102, 0)}
        timer = [0.0]
        def advance(seconds):
            timer[0] += max(seconds, .01)
        with mock.patch.object(cli, "configuration", side_effect=lambda site, box: configs[site]), \
             mock.patch.object(cli, "check_clocks"), mock.patch.object(cli, "telemetry_snapshot") as telemetry, \
             mock.patch.object(cli, "validate_records", side_effect=RuntimeError("bad lane") if fail_records else None), \
             mock.patch.object(cli.time, "monotonic", side_effect=lambda: timer[0]), \
             mock.patch.object(cli.time, "sleep", side_effect=advance), \
             contextlib.redirect_stdout(io.StringIO()):
            if fail_records:
                with self.assertRaisesRegex(RuntimeError, "bad lane"):
                    cli.run_test(None, boxes, {"F1": 0, "F2": 1}, 1, True, {})
            else:
                cli.run_test(None, boxes, {"F1": 0, "F2": 1}, 1, True, {})
        self.assertEqual(telemetry.call_args_list[-1], mock.call(None, "post"))
        self.assertEqual(boxes["F1"].commands, [2, 3])
        self.assertEqual(boxes["F2"].commands, [0x10501])
        self.assertEqual(boxes["F1"].values[0xf8], 1)
        self.assertEqual(boxes["F2"].values[0xf8], 2)
        self.assertEqual(boxes["F1"].values[0xc8], cli.CAPABILITY)

    def test_failed_first_endpoint_preserves_second_endpoint_records(self):
        with mock.patch.object(cli, "wait_response") as wait, \
             mock.patch.object(cli, "validate_records", side_effect=[RuntimeError("F1 lane failed"), None]) as records:
            with self.assertRaisesRegex(RuntimeError, "F1 lane failed"):
                cli.collect_results({"F1": Box(), "F2": Box()}, {"F1": 1, "F2": 1},
                                    {"F1": (4, 1), "F2": (7, 2)},
                                    {"F1": (15, 0, 0, 0), "F2": (15, 0, 0, 0)}, 1000, 1)
        self.assertEqual(wait.call_count, 2)
        self.assertEqual([call.args[0] for call in records.call_args_list], ["F1", "F2"])

    def test_tx_only_partner_and_rx_only_receiver(self):
        self.exercise_one_way_run()

    def test_failed_receiver_still_stops_owned_transmitter_without_retry(self):
        self.exercise_one_way_run(fail_records=True)

    def test_selectors_cover_both_classes_and_edges(self):
        self.assertEqual(contract.quad_mask("none"), 0)
        self.assertEqual(contract.quad_mask("all"), 0xfffffff)
        self.assertEqual(contract.quad_mask("q121,q234"), 0x8000001)
        self.assertEqual(contract.quad_mask("q121-q123,q221-q223"), 7 | (7 << 14))
        self.assertEqual(contract.quad_mask("q121,q121"), 1)

    def test_invalid_ranges_never_alias_into_another_class(self):
        for spec in ("", "q120", "q135", "q220", "q235", "q134-q221", "q123-q121", "q121,", "qq121"):
            with self.subTest(spec=spec), self.assertRaises(ValueError):
                contract.quad_mask(spec)

    def test_fitted_exclusions_are_site_specific(self):
        for site, omitted in contract.UNFITTED.items():
            words = contract.receive_words(site, contract.quad_mask("all"))
            lanes = {lane for lane in range(112) if words[lane // 32] & (1 << (lane % 32))}
            self.assertEqual(lanes, set(range(112)) - set(omitted))
        self.assertEqual(contract.receive_words("F1", 1), (15, 0, 0, 0))

    def test_release_guard_is_closed(self):
        with self.assertRaisesRegex(RuntimeError, "UNRELEASED"):
            contract.require_release()

    def test_reference_clock_dependency_mapping(self):
        self.assertEqual(contract.required_refclks(0), ())
        self.assertEqual(contract.required_refclks(contract.quad_mask("q121-q123")), (0x5c,))
        self.assertEqual(contract.required_refclks(contract.quad_mask("q124,q224")), (0x2c, 0x58))
        self.assertEqual(contract.required_refclks(contract.quad_mask("all")),
                         (0x2c, 0x30, 0x38, 0x3c, 0x40, 0x44, 0x48, 0x4c, 0x50, 0x54, 0x58, 0x5c))

    def test_disabled_refclock_does_not_block_configuring_another_quad(self):
        box = Box()
        box.values.update({0x9c: 0x434da501, 0x08: 200000, 0x24: 100000,
                           0x28: 325000, 0x5c: 322266})
        with contextlib.redirect_stdout(io.StringIO()):
            cli.check_clocks("F1", box, contract.quad_mask("q121"))
        with self.assertRaises(RuntimeError), contextlib.redirect_stdout(io.StringIO()):
            cli.check_clocks("F1", box, contract.quad_mask("q124"))

    def test_failed_run_dumps_all_records_before_rejecting(self):
        box = Box()
        record = {"id_status": 0, "errors": 7, "lock_losses": 0,
                  "tested_bits": 0, "valid_cycles": 0}
        with mock.patch.object(cli, "read_lane", return_value=record) as read, \
             contextlib.redirect_stdout(io.StringIO()) as output:
            with self.assertRaises(RuntimeError):
                cli.validate_records("F1", box, (15, 0, 0, 0), 2, 1000)
        self.assertEqual(read.call_count, 4)
        self.assertEqual(output.getvalue().count("RECORD site=F1"), 4)

    def test_firefly_config_requires_acknowledgement_before_any_hardware(self):
        with mock.patch.object(sys, "argv", ["v3", "configure", "--site", "F1", "--tx", "q121", "--rx", "none"]), \
             mock.patch.object(cli, "load_registry") as registry, \
             mock.patch.object(cli.subprocess, "check_output") as git:
            with self.assertRaisesRegex(RuntimeError, "FireFly TX acknowledgement"):
                cli.main()
            registry.assert_not_called(); git.assert_not_called()

    def test_main_blocks_hardware_before_registry_or_git(self):
        with mock.patch.object(sys, "argv", ["v3", "configure", "--site", "F1", "--tx", "none", "--rx", "none"]), \
             mock.patch.object(cli, "load_registry") as registry, \
             mock.patch.object(cli.subprocess, "check_output") as git:
            with self.assertRaisesRegex(RuntimeError, "UNRELEASED"):
                cli.main()
            registry.assert_not_called(); git.assert_not_called()

    def test_predecessor_rejects_busy_pending_wrong_identity(self):
        for address, value in ((0xc8, (1 << 20) | 2), (0xf0, 2), (0xc0, 0x20501), (0xa0, 0xffffffff)):
            box = Box(); box.values[address] = value
            with self.subTest(address=address), self.assertRaises(RuntimeError):
                cli.predecessor("F1", box)
            self.assertEqual(box.writes, [])

    def test_predecessor_guards_and_config_fault_isolation(self):
        box = Box()
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(cli.predecessor("F1", box, (3, 1)), (3, 1))
            box.values[0xc8] |= 1 << 16
            self.assertEqual(cli.predecessor("F1", box, allow_fault=True), (3, 1))
        with self.assertRaises(RuntimeError):
            cli.predecessor("F1", box)

    def test_configuration_request_sequence_is_last(self):
        box = Box()
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(cli.submit("F1", box, 3, 4, 0, (1, 2, 0, 0)), 4)
        self.assertEqual(box.writes[-1], (0xa0, 4))
        self.assertEqual(box.values[0xb0], 1); self.assertEqual(box.values[0xb4], 2)

    def test_no_config_doorbell_under_active_session(self):
        box = Box(); box.values[0xc8] |= 1 << 17
        with self.assertRaises(RuntimeError):
            cli.submit("F1", box, 3, 4, 0, (0, 0, 0, 0))
        self.assertEqual(box.writes, [])

    def test_configuration_waits_for_quad_cleanup_without_issuing_request(self):
        box = Box()
        cfg = (0x51430001, 1, 1, 1, 1, 1, 2, 0)  # Applied, but eligibility flag clear.
        with mock.patch.object(cli, "configuration", return_value=cfg), \
             mock.patch.object(cli, "submit") as submit, \
             contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(RuntimeError, "cleanup"):
                cli.configure("F1", box, 0, 0)
        submit.assert_not_called()

    def test_state_change_or_readback_failure_never_rings_doorbell(self):
        box = Box(); box.values[0xf0] = 2
        with self.assertRaises(RuntimeError):
            cli.submit("F1", box, 3, 4, 0, (0, 0, 0, 0))
        self.assertEqual(box.writes, [])
        box = Box()
        with mock.patch.object(box, "write_u32"):
            with self.assertRaises(RuntimeError):
                cli.submit("F1", box, 3, 4, 0, (0, 0, 0, 0))
        self.assertEqual(box.values[0xa0], 3)

    def test_python36_grammar(self):
        for name in ("all_links_v3_contract.py", "board_all_links_v3.py"):
            p = Path(__file__).parent / name
            ast.parse(p.read_text(), filename=str(p), feature_version=(3, 6))


if __name__ == "__main__":
    unittest.main()
