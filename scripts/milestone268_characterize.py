#!/usr/bin/env python3
"""One v268 diagnostic run, with raw evidence saved before validation.

Check FPGA temperature and power externally before invoking. This script does
not program hardware, choose a detection threshold, or silently retry a run.
external-pulse waits for an independently logged XSDB lane-12 injection.
"""
import argparse
import json
import sys
import time
from pathlib import Path

import milestone3_12hour_external_soak as test
import milestone268_diagnostics as diag
import recovery_diagnostics as recovery
import transition_diagnostics

LABEL = "V268"
VALIDATION_BANNER = None
EXPECTED_RESTART_DELTA = 1
EXPECTED_PLANNED_STARTUP_RESTART = False


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def validate(raw, sequence, run_id, stimulus):
    result = diag.decode(raw["capture"])
    overview = raw["capture"]["overview"]
    for key, value in (("request sequence", sequence), ("response sequence", sequence),
                       ("hardware run ID", run_id), ("engine state", 0)):
        require(overview[key] == value, "final {} mismatch".format(key))
    expected_summary = 0x00040401 if stimulus == "clean" else 0x01030401
    for key in ("hardware summary", "response code"):
        require(overview[key] == expected_summary, "unexpected {}".format(key))
    platform = raw["capture"]["platform"]
    require(platform[1] & (1 << 30), "PRBS controller did not return to IDLE")
    require(platform[3] & (1 << 19), "quad supervisor is not ready")
    before = recovery.decode(raw["restart_before"])
    recovery.require_completed_delta(
        before, result["recovery"], EXPECTED_RESTART_DELTA, 3)
    require(not result["metadata"]["overflow"], "trace overflow lost acquisition evidence")
    require(result["metadata"]["epoch"] == raw["epoch_before"] + 1,
            "trace did not capture exactly one epoch")
    if EXPECTED_PLANNED_STARTUP_RESTART:
        transitions = list(zip(result["trace"], result["trace"][1:]))
        require(any(a["prbs_state"] == 1 and b["prbs_state"] == 23
                    for a, b in transitions),
                "planned state-1 to state-23 startup restart is absent")
        require(not any(a["prbs_state"] == 25 and b["prbs_state"] == 23
                        for a, b in transitions),
                "unexpected cause-2 acquisition recovery followed planned restart")
    for lane in range(12, 16):
        words = raw["capture"]["lanes"][str(lane)]
        require(words[0] == 0x1800 | lane, "lane status mismatch")
        require(words[5] == 0, "unexpected native lock loss")
        bits = words[3] | (words[4] << 32)
        cycles = words[6] | (words[7] << 32)
        require(cycles > 0 and bits == cycles * 80, "invalid measurement counts")
        errors = words[1] | (words[2] << 32)
        native = result["profiles"][str(lane)]
        if stimulus != "clean" and lane == 12:
            require(errors > 0 and native["errors"] > 0, "stimulus produced no recorded errors")
        else:
            require(errors == 0 and native["errors"] == 0, "unexpected error on lane {}".format(lane))
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--sequence", type=int, required=True)
    p.add_argument("--previous-sequence", type=int, required=True)
    p.add_argument("--expected-run-id", type=int, required=True)
    p.add_argument("--stimulus", choices=("clean", "firefly", "external-pulse"), default="clean")
    p.add_argument("--disable-ms", type=float, default=100)
    p.add_argument("--duration-ms", type=int, default=10000)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--cm-interface-root", type=Path, default=Path("/home/cms/25G/cm_interface"))
    p.add_argument("--device", default="/dev/ttyUL4")
    args = p.parse_args()
    require(2000 <= args.duration_ms <= 10000, "profile requires 2-10 second measurements")
    require(0 < args.disable_ms <= 1000, "outage must be at most one second")
    require(0 <= args.previous_sequence < args.sequence <= 0xffffffff, "use a new increasing sequence")
    require(args.expected_run_id > 0, "expected run ID must be positive")
    sys.path.insert(0, str(args.cm_interface_root.resolve().parent))
    from cm_interface.registry import Registry
    from cm_interface.device.firefly import Firefly4
    registry = Registry(setup="tf", dev_path=args.device)
    mailbox = test.FpgaMailbox(registry.fpgas["F1"])
    firefly = Firefly4(registry.uart, 0x28, "F1_5")
    test.FW_VERSION = test.HW_VERSION = diag.VERSION
    raw = dict(arguments={k: str(v) if isinstance(v, Path) else v for k, v in vars(args).items()},
               timestamp=time.time())
    # Refuse to overwrite earlier evidence before doing any hardware writes.
    with args.output.open("x") as output:
        try:
            before = test.read_overview(mailbox)
            raw["before"] = before
            for key, value in (("firmware version", diag.VERSION), ("hardware version", diag.VERSION),
                               ("engine state", 0), ("request sequence", args.previous_sequence),
                               ("response sequence", args.previous_sequence),
                               ("hardware run ID", args.expected_run_id - 1)):
                require(before[key] == value, "preflight {} mismatch".format(key))
            raw["restart_before"] = diag.page(mailbox, 0xfd)
            raw["epoch_before"] = diag.page(mailbox, 0xfc)[2]
            original = firefly.read_reg(0x56)[0]
            raw["firefly_original"] = original
            require(original == 0, "FireFly outputs already disabled; do not alter existing state")
            raw["firefly_temperature_before"] = firefly.temperature
            raw["rx_clock_before_khz"] = mailbox.read_u32(0x98)
            require(300000 <= raw["rx_clock_before_khz"] <= 340000, "RX clock unavailable")
            test.start_soak(mailbox, args.sequence, args.previous_sequence, args.duration_ms,
                            LABEL + " diagnostic " + args.stimulus, test.MANAGED_LANE_MASK)
            print("RUN_READY sequence={}".format(args.sequence), flush=True)
            if args.stimulus == "firefly":
                time.sleep(0.25)
                require(mailbox.read_u32(test.REG_ENGINE_STATE) == 2, "run ended before stimulus")
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
                require(firefly.read_reg(0x56)[0] == original, "FireFly restore readback failed")
                raw["alarms_after"] = [firefly.read_reg(3)[0], firefly.read_reg(5)[0]]
                require(mailbox.read_u32(test.REG_ENGINE_STATE) == 2, "stimulus crossed measurement end")
            deadline = time.monotonic() + args.duration_ms / 1000.0 + 20
            while mailbox.read_u32(test.REG_RESPONSE_SEQUENCE) != args.sequence:
                require(time.monotonic() < deadline, "completion timeout; no retry submitted")
                time.sleep(0.2)
            # Publication can precede cleanup completion. Wait for the recorder
            # to freeze, without issuing another command or clearing evidence.
            while transition_diagnostics.metadata(diag.page(mailbox, 0xfc))["active"]:
                require(time.monotonic() < deadline, "cleanup/trace freeze timeout")
                time.sleep(0.1)
        except Exception as error:
            raw["operation_error"] = repr(error)
        finally:
            # Save publication, trace, and alarms even when an assertion fails.
            try:
                raw["capture"] = {}
                diag.capture(mailbox, raw["capture"])
                raw["firefly_temperature_after"] = firefly.temperature
                raw["rx_clock_after_khz"] = mailbox.read_u32(0x98)
            except Exception as error:
                raw["capture_error"] = repr(error)
            json.dump(raw, output, indent=2, sort_keys=True)
            output.flush()
    require("operation_error" not in raw, raw.get("operation_error"))
    require("capture_error" not in raw, raw.get("capture_error"))
    result = validate(raw, args.sequence, args.expected_run_id, args.stimulus)
    print(json.dumps(result, indent=2, sort_keys=True))
    print(VALIDATION_BANNER or
          LABEL + " DIAGNOSTIC RUN VALIDATED; NOT A QUALIFICATION CANDIDATE")


if __name__ == "__main__":
    main()
