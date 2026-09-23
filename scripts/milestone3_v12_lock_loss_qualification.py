#!/usr/bin/env python3
"""Qualify v12 CDR lock-loss accounting with FireFly-5 channel 0.

Run this only after a clean v12 smoke test.  It starts one four-lane external
measurement, disables FireFly-5 channel 0 (global lane 12) for ten seconds,
restores the exact original byte-86 value, waits for completion, and requires
one isolated lane-12 lock loss while lanes 13-15 remain clean.
"""

import argparse
from pathlib import Path
import sys
import time

import milestone3_12hour_external_soak as test


VERSION = 0x0002000C
SUMMARY_ONE_FAILED_THREE_PASSED = 0x01030401
FIREFLY_DEVICE_INDEX = 8
TX_DISABLE_REGISTER = 0x56
LOS_ALARM_REGISTER = 0x03
CDR_LOL_ALARM_REGISTER = 0x05
CHANNEL = 0
LANE = 12


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--cm-interface-root", type=Path,
        default=Path("/nfs/cms/tracktrigger/wittich/int_test/cm_interface"),
    )
    parser.add_argument("--device", default="/dev/ttyUL4")
    parser.add_argument("--sequence", type=lambda value: int(value, 0), default=2)
    parser.add_argument(
        "--previous-sequence", type=lambda value: int(value, 0), default=1
    )
    parser.add_argument("--duration-ms", type=int, default=30_000)
    parser.add_argument("--disable-seconds", type=float, default=10.0)
    return parser.parse_args()


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def main():
    args = parse_args()
    require(args.duration_ms > (args.disable_seconds + 5.0) * 1000,
            "measurement must leave at least five seconds around the outage")
    package_parent = str(args.cm_interface_root.resolve().parent)
    if package_parent not in sys.path:
        sys.path.insert(0, package_parent)
    from cm_interface.device.firefly import Firefly4
    from cm_interface.registry import Registry

    registry = Registry(setup="tf", dev_path=args.device)
    mailbox = test.FpgaMailbox(registry.fpgas["F1"])
    firefly = Firefly4(
        registry.uart, 0x20 + FIREFLY_DEVICE_INDEX, "F1_5"
    )
    test.FW_VERSION = VERSION
    test.HW_VERSION = VERSION

    run_id_before = mailbox.read_u32(test.REG_RUN_ID)
    test.start_soak(
        mailbox, args.sequence, args.previous_sequence, args.duration_ms,
        "v12 FireFly channel-0 lock-loss qualification",
    )

    original = firefly.read_reg(TX_DISABLE_REGISTER)[0]
    baseline_los = firefly.read_reg(LOS_ALARM_REGISTER)[0]
    baseline_lol = firefly.read_reg(CDR_LOL_ALARM_REGISTER)[0]
    disabled = original | (1 << CHANNEL)
    module_failures = []
    print("FireFly part ID  = {!r}".format(firefly.part_id))
    print("original byte 86 = 0x{:02x}".format(original))
    print("baseline LOS/LOL = 0x{:02x}/0x{:02x}".format(
        baseline_los, baseline_lol
    ))

    restored = False
    try:
        time.sleep(2.0)
        firefly.write_reg(TX_DISABLE_REGISTER, bytes([disabled]))
        if firefly.read_reg(TX_DISABLE_REGISTER)[0] != disabled:
            module_failures.append("FireFly TX-disable readback mismatch")
        time.sleep(1.0)
        active_los = firefly.read_reg(LOS_ALARM_REGISTER)[0]
        active_lol = firefly.read_reg(CDR_LOL_ALARM_REGISTER)[0]
        print("disabled LOS/LOL = 0x{:02x}/0x{:02x}".format(
            active_los, active_lol
        ))
        if not active_los & 0x01:
            module_failures.append("FireFly RX0 LOS did not assert")
        if not active_los & 0x10:
            module_failures.append("FireFly TX0 LOS did not assert")
        if not active_lol & 0x01:
            module_failures.append("FireFly RX0 CDR LOL did not assert")
        time.sleep(args.disable_seconds - 1.0)
    finally:
        firefly.write_reg(TX_DISABLE_REGISTER, bytes([original]))
        restored = firefly.read_reg(TX_DISABLE_REGISTER)[0] == original
        print("restored byte 86 = 0x{:02x}".format(
            firefly.read_reg(TX_DISABLE_REGISTER)[0]
        ))
    if not restored:
        module_failures.append("failed to restore FireFly byte 86")

    deadline = time.monotonic() + args.duration_ms / 1000.0 + 20.0
    while mailbox.read_u32(test.REG_RESPONSE_SEQUENCE) != args.sequence:
        require(time.monotonic() < deadline, "timed out waiting for completion")
        time.sleep(0.25)

    overview = test.read_overview(mailbox)
    test.expect("firmware version", overview["firmware version"], VERSION)
    test.expect("hardware version", overview["hardware version"], VERSION)
    test.expect("engine state", overview["engine state"], 0)
    test.expect("response sequence", overview["response sequence"], args.sequence)
    # An intentional lane-12 lock loss makes that lane fail the normal
    # per-lane acceptance predicate, so the expected aggregate is one failed
    # lane and three passed lanes with a normal-duration stop.
    test.expect("response code", overview["response code"],
                SUMMARY_ONE_FAILED_THREE_PASSED)
    test.expect("hardware summary", overview["hardware summary"],
                SUMMARY_ONE_FAILED_THREE_PASSED)
    test.expect("run ID", overview["hardware run ID"],
                (run_id_before + 1) & 0xFFFFFFFF)

    results = {lane: test.read_lane(mailbox, lane) for lane in range(12, 16)}
    for lane, result in results.items():
        print("lane {}: status={:#010x} errors={} losses={} bits={} cycles={}".format(
            lane, result["id_status"], result["errors"],
            result["lock_losses"], result["tested_bits"],
            result["valid_cycles"],
        ))
        require(result["tested_bits"] == result["valid_cycles"] * 80,
                "lane {} bit/cycle mismatch".format(lane))

    disturbed = results[LANE]
    require(disturbed["id_status"] & (1 << 13),
            "lane 12 lock-loss status did not assert")
    require(disturbed["lock_losses"] >= 1,
            "lane 12 lock-loss counter did not increment")
    require(disturbed["errors"] > 0, "lane 12 recorded no PRBS errors")
    for lane in range(13, 16):
        result = results[lane]
        require(result["errors"] == 0,
                "adjacent lane {} recorded errors".format(lane))
        require(result["lock_losses"] == 0,
                "adjacent lane {} recorded lock loss".format(lane))
        require(not (result["id_status"] & ((1 << 13) | (1 << 14) | (1 << 15))),
                "adjacent lane {} has failure status".format(lane))
        require(disturbed["valid_cycles"] < result["valid_cycles"],
                "lane 12 did not exclude its unlocked interval")

    require(not module_failures, "; ".join(module_failures))

    print("V12 FIREFLY LOCK-LOSS QUALIFICATION PASSED")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AttributeError, KeyError, ModuleNotFoundError, RuntimeError) as error:
        print("ERROR: {}".format(error), file=sys.stderr)
        raise SystemExit(1)
