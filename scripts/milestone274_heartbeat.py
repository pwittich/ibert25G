#!/usr/bin/env python3
"""Submit one v274 run watched by the fixed heartbeat-test XSDB helper."""
import argparse
import json
import sys
import time
from pathlib import Path

import milestone3_12hour_external_soak as test
import milestone268_diagnostics as diag
import recovery_diagnostics as recovery
import transition_diagnostics

VERSION = 0x00020118


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sequence", type=int, required=True)
    parser.add_argument("--previous-sequence", type=int, required=True)
    parser.add_argument("--expected-run-id", type=int, required=True)
    parser.add_argument("--duration-ms", type=int, default=10000)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--cm-interface-root", type=Path,
                        default=Path("/home/cms/25G/cm_interface"))
    parser.add_argument("--device", default="/dev/ttyUL4")
    args = parser.parse_args()
    require(args.sequence == 2 and args.previous_sequence == 1 and
            args.expected_run_id == 2, "v274 heartbeat gate is fixed to sequence/run 2")
    require(args.duration_ms == 10000, "v274 heartbeat gate is fixed to 10 seconds")

    sys.path.insert(0, str(args.cm_interface_root.resolve().parent))
    from cm_interface.registry import Registry

    registry = Registry(setup="tf", dev_path=args.device)
    mailbox = test.FpgaMailbox(registry.fpgas["F1"])
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
                               ("request sequence", 1), ("response sequence", 1),
                               ("hardware run ID", 1)):
                require(before[key] == value, "preflight {} mismatch".format(key))
            raw["restart_before"] = diag.page(mailbox, 0xfd)
            before_recovery = recovery.decode(raw["restart_before"])
            require(before_recovery["capabilities"] == 7,
                    "v274 heartbeat-test capability is unavailable")
            require(before_recovery["integrity_count"] == 0,
                    "integrity event already retained before stimulus")
            require(not before_recovery["integrity"]["monitor_enabled"],
                    "measurement-enable must be clear during IDLE preflight")
            raw["epoch_before"] = diag.page(mailbox, 0xfc)[2]
            raw["rx_clock_before_khz"] = mailbox.read_u32(0x98)
            require(300000 <= raw["rx_clock_before_khz"] <= 340000,
                    "physical RX clock unavailable before test")

            test.start_soak(mailbox, 2, 1, 10000, "V274 heartbeat test",
                            test.MANAGED_LANE_MASK)
            print("RUN_READY sequence=2", flush=True)
            deadline = time.monotonic() + 30.0
            while mailbox.read_u32(test.REG_RESPONSE_SEQUENCE) != 2:
                require(time.monotonic() < deadline,
                        "completion timeout; no retry submitted")
                time.sleep(0.1)
            while transition_diagnostics.metadata(diag.page(mailbox, 0xfc))["active"]:
                require(time.monotonic() < deadline, "trace freeze timeout")
                time.sleep(0.1)
        except Exception as error:
            raw["operation_error"] = repr(error)
        finally:
            try:
                raw["capture"] = {}
                diag.capture(mailbox, raw["capture"])
                raw["rx_clock_after_khz"] = mailbox.read_u32(0x98)
            except Exception as error:
                raw["capture_error"] = repr(error)
            json.dump(raw, output, indent=2, sort_keys=True)
            output.flush()

    require("operation_error" not in raw, raw.get("operation_error"))
    require("capture_error" not in raw, raw.get("capture_error"))
    capture = raw["capture"]
    overview = capture["overview"]
    for key, value in (("request sequence", 2), ("response sequence", 2),
                       ("hardware run ID", 2), ("response code", 0x04000404),
                       ("hardware summary", 0x04000404),
                       ("engine state", 0x00010000)):
        require(overview[key] == value, "final {} mismatch".format(key))
    require(capture["platform"][4] & 0x1f == 27,
            "first-fault PRBS stage is not runtime-integrity stage 27")
    integrity = recovery.decode(capture["recovery"])
    require(integrity["capabilities"] == 7, "v274 capabilities changed")
    require(integrity["integrity_count"] == 1,
            "expected exactly one retained integrity event")
    require(integrity["integrity"]["retained_error_lanes"] == 0,
            "unexpected retained lane-data cause")
    require(integrity["integrity"]["retained_clock_fault"],
            "missing retained heartbeat-loss cause")
    require(integrity["integrity"]["selected_lanes"] == 0xf,
            "accepted lane mask was not retained")
    recovery.require_completed_delta(before_recovery, integrity, 1, 4)
    for quad_word in (capture["platform"][3], capture["platform"][6]):
        require(quad_word & (1 << 19), "quad supervisor is not READY")
        require(not quad_word & (1 << 20), "unexpected quad fault/reset")
    for lane in range(12, 16):
        require(capture["lanes"][str(lane)] ==
                [0x2800 | lane, 0, 0, 0, 0, 1, 0, 0],
                "platform-failure record mismatch on lane {}".format(lane))
    require(300000 <= raw["rx_clock_after_khz"] <= 340000,
            "physical RX clock unavailable after test")
    result = diag.decode(capture)
    require(result["metadata"]["epoch"] == raw["epoch_before"] + 1,
            "trace did not capture exactly one epoch")
    require(not result["metadata"]["overflow"], "trace overflow")
    print(json.dumps(result, indent=2, sort_keys=True))
    print("V274 HEARTBEAT-MONITOR TEST PASSED; PLATFORM FAULT RETAINED")


if __name__ == "__main__":
    main()
