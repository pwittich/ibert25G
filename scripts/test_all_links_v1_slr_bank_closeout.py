#!/usr/bin/env python3
"""Static closeout checks for the intentionally optimized bank control bit."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def text(name):
    return (ROOT / name).read_text()


bank = text("src/all_links_v1_slr_bank.sv")
controller = text("src/gt_prbs_test_controller.sv")
left = text("src/managed_native_left_quad_wrapper.sv")
direct = text("src/managed_direct_quad_v6_wrapper.sv")
core = text("src/gt_test_direct_quad_v6_core.sv")

assert "parameter bit RUNTIME_INTEGRITY_DETECTOR = 1'b0" in controller
assert controller.count("RUNTIME_INTEGRITY_DETECTOR && measurement_enable") == 1
assert ".RUNTIME_INTEGRITY_DETECTOR(" not in left
assert ".RUNTIME_INTEGRITY_DETECTOR(" not in direct
assert bank.count(".measurement_enable(local_controls[1])") == 2
assert "for (genvar lane = 0; lane < 112; lane++)" in core
assert ".measurement_enable(measurement_enable)" in core
assert "controls_in({tx_session_active,loopback_mode,acquisition_active,measurement_enable,result_capture_request})" in core
print("PASS: bank control[1] only reaches constant-disabled runtime detectors; global engine measurement control remains wired for 112 lanes")
