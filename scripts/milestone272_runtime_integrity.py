#!/usr/bin/env python3
"""One v272 lane-12 runtime-integrity fault test; preserve before validating."""
import argparse
import json
import sys
import time
from pathlib import Path

import milestone3_12hour_external_soak as test
import milestone268_diagnostics as diag
import recovery_diagnostics as recovery
import transition_diagnostics

VERSION = 0x00020116
LABEL = "V272"


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sequence", type=int, required=True)
    parser.add_argument("--previous-sequence", type=int, required=True)
    parser.add_argument("--expected-run-id", type=int, required=True)
    parser.add_argument("--disable-ms", type=float, default=250.0)
    parser.add_argument("--duration-ms", type=int, default=10000)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--cm-interface-root", type=Path,
                        default=Path("/home/cms/25G/cm_interface"))
    parser.add_argument("--device", default="/dev/ttyUL4")
    args = parser.parse_args()
    require(100.0 < args.disable_ms <= 1000.0,
            "outage must exceed the 100-ms detector threshold and be at most one second")
    require(2000 <= args.duration_ms <= 10000, "use a 2-10 second measurement")
    require(0 <= args.previous_sequence < args.sequence <= 0xffffffff,
            "use a new increasing sequence")
    require(args.expected_run_id > 0, "expected run ID must be positive")

    sys.path.insert(0, str(args.cm_interface_root.resolve().parent))
    from cm_interface.registry import Registry
    from cm_interface.device.firefly import Firefly4

    registry = Registry(setup="tf", dev_path=args.device)
    mailbox = test.FpgaMailbox(registry.fpgas["F1"])
    firefly = Firefly4(registry.uart, 0x28, "F1_5")
    test.FW_VERSION = test.HW_VERSION = VERSION
    diag.VERSION = VERSION
    raw = dict(arguments={key: str(value) if isinstance(value, Path) else value
                          for key, value in vars(args).items()}, timestamp=time.time())

    with args.output.open("x") as output:
        try:
            before = test.read_overview(mailbox)
            raw["before"] = before
            for key, value in (("firmware version", VERSION),
                               ("hardware version", VERSION), ("engine state", 0),
                               ("request sequence", args.previous_sequence),
                               ("response sequence", args.previous_sequence),
                               ("hardware run ID", args.expected_run_id - 1)):
                require(before[key] == value, "preflight {} mismatch".format(key))
            raw["restart_before"] = diag.page(mailbox, 0xfd)
            before_recovery = recovery.decode(raw["restart_before"])
            require(before_recovery["capabilities"] == 3,
                    "runtime-integrity capability is unavailable")
            require(before_recovery["integrity_count"] == 0,
                    "integrity event already retained before stimulus")
            require(not before_recovery["integrity"]["monitor_enabled"],
                    "measurement-enable must be clear during IDLE preflight")
            raw["epoch_before"] = diag.page(mailbox, 0xfc)[2]
            original = firefly.read_reg(0x56)[0]
            raw["firefly_original"] = original
            require(original == 0, "FireFly outputs already disabled; do not alter state")
            raw["firefly_temperature_before"] = firefly.temperature
            raw["rx_clock_before_khz"] = mailbox.read_u32(0x98)
            require(300000 <= raw["rx_clock_before_khz"] <= 340000,
                    "RX clock unavailable")

            test.start_soak(mailbox, args.sequence, args.previous_sequence,
                            args.duration_ms, LABEL + " runtime integrity",
                            test.MANAGED_LANE_MASK)
            print("RUN_READY sequence={}".format(args.sequence), flush=True)
            time.sleep(0.25)
            require(mailbox.read_u32(test.REG_ENGINE_STATE) == 2,
                    "run ended before stimulus")
            raw["alarms_before"] = [firefly.read_reg(3)[0], firefly.read_reg(5)[0]]
            try:
                raw["disable_write_begin"] = time.monotonic()
                firefly.write_reg(0x56, bytes([original | 1]))
                raw["disable_write_end"] = time.monotonic()
                time.sleep(args.disable_ms / 1000.0)
            finally:
                raw["restore_write_begin"] = time.monotonic()
                firefly.write_reg(0x56, bytes([original]))
                raw["restore_write_end"] = time.monotonic()
            require(firefly.read_reg(0x56)[0] == original,
                    "FireFly restore readback failed")
            raw["alarms_after"] = [firefly.read_reg(3)[0], firefly.read_reg(5)[0]]

            deadline = time.monotonic() + 30.0
            while mailbox.read_u32(test.REG_RESPONSE_SEQUENCE) != args.sequence:
                require(time.monotonic() < deadline,
                        "completion timeout; no retry submitted")
                time.sleep(0.2)
            while transition_diagnostics.metadata(diag.page(mailbox, 0xfc))["active"]:
                require(time.monotonic() < deadline, "trace freeze timeout")
                time.sleep(0.1)
        except Exception as error:
            raw["operation_error"] = repr(error)
        finally:
            try:
                raw["capture"] = {}
                diag.capture(mailbox, raw["capture"])
                raw["firefly_temperature_after"] = firefly.temperature
                raw["firefly_disable_after"] = firefly.read_reg(0x56)[0]
                raw["rx_clock_after_khz"] = mailbox.read_u32(0x98)
            except Exception as error:
                raw["capture_error"] = repr(error)
            json.dump(raw, output, indent=2, sort_keys=True)
            output.flush()

    require("operation_error" not in raw, raw.get("operation_error"))
    require("capture_error" not in raw, raw.get("capture_error"))
    capture = raw["capture"]
    overview = capture["overview"]
    for key, value in (("request sequence", args.sequence),
                       ("response sequence", args.sequence),
                       ("hardware run ID", args.expected_run_id),
                       ("response code", 0x04000404),
                       ("hardware summary", 0x04000404)):
        require(overview[key] == value, "final {} mismatch".format(key))
    require(overview["engine state"] == 0x00010000,
            "expected retained platform-fault IDLE state")
    require(capture["platform"][4] & 0x1f == 27,
            "first-fault PRBS stage is not runtime-integrity stage 27")
    integrity = recovery.decode(capture["recovery"])
    require(integrity["integrity_count"] == 1,
            "expected exactly one retained integrity event")
    require(integrity["integrity"]["retained_error_lanes"] == 1,
            "expected retained lane-12 data-integrity event only")
    require(not integrity["integrity"]["retained_clock_fault"],
            "unexpected shared-clock fault")
    require(integrity["integrity"]["selected_lanes"] == 0xf,
            "accepted lane mask was not retained")
    require(raw["firefly_disable_after"] == 0, "FireFly output was not restored")
    result = diag.decode(capture)
    require(result["metadata"]["epoch"] == raw["epoch_before"] + 1,
            "trace did not capture exactly one epoch")
    require(not result["metadata"]["overflow"], "trace overflow")
    print(json.dumps(result, indent=2, sort_keys=True))
    print(LABEL + " RUNTIME-INTEGRITY HARDWARE GATE PASSED; PLATFORM FAULT RETAINED")


if __name__ == "__main__":
    main()
