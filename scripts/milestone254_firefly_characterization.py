#!/usr/bin/env python3
"""Characterize PRBS-error activity and RXUSRCLK during one optical outage.

Program the isolated Milestone 2.5.4 (0x00020104) image immediately before
running this script.  It commits exactly one 30-second four-lane external run,
disables FireFly-5 channel 0 for ten seconds, restores byte 86 in ``finally``,
and requires corruption to remain isolated to global lane 12.  In this image
only, r38 reports the managed quad RXUSRCLK2 frequency and each result error
field counts RXPRBSERR-active cycles rather than native bit errors.
"""

import argparse
from pathlib import Path
import sys
import time

import milestone3_12hour_external_soak as test


VERSION = 0x00020104
CANDIDATE_LABEL = "2.5.4"
SUMMARY_ONE_FAILED_THREE_PASSED = 0x01030401
FIREFLY_DEVICE_INDEX = 8
TX_DISABLE_REGISTER = 0x56
LOS_ALARM_REGISTER = 0x03
CDR_LOL_ALARM_REGISTER = 0x05
RXUSRCLK_FREQUENCY_REGISTER = 0x98
STATUS_REGISTER = 0x9C
CHANNEL = 0
LANE = 12


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--cm-interface-root", type=Path,
        default=Path("/home/cms/25G/cm_interface"),
    )
    parser.add_argument("--device", default="/dev/ttyUL4")
    parser.add_argument("--sequence", type=lambda value: int(value, 0), default=1)
    parser.add_argument(
        "--previous-sequence", type=lambda value: int(value, 0), default=0
    )
    parser.add_argument("--duration-ms", type=int, default=30_000)
    parser.add_argument("--disable-seconds", type=float, default=10.0)
    return parser.parse_args()


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def read_rx_clock(mailbox, label):
    status = mailbox.read_u32(STATUS_REGISTER)
    frequency = mailbox.read_u32(RXUSRCLK_FREQUENCY_REGISTER)
    print("{} RXUSRCLK2 = {} kHz; r39={:#010x}".format(
        label, frequency, status
    ))
    require((status >> 16) == 0x434D, "clock-monitor ID is not 0x434d")
    require(status & 0x8000, "clock-monitor measurement is not valid")
    require(300_000 <= frequency <= 340_000,
            "RXUSRCLK2 frequency {} kHz is outside 300-340 MHz".format(
                frequency))
    return frequency


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
    firefly = Firefly4(registry.uart, 0x20 + FIREFLY_DEVICE_INDEX, "F1_5")
    test.FW_VERSION = VERSION
    test.HW_VERSION = VERSION

    run_id_before = mailbox.read_u32(test.REG_RUN_ID)
    require(run_id_before == 0,
            "image is not fresh: run ID is {}; reprogram before retrying".format(
                run_id_before))
    read_rx_clock(mailbox, "baseline")
    test.start_soak(
        mailbox, args.sequence, args.previous_sequence, args.duration_ms,
        "{} FireFly PRBS-activity characterization".format(CANDIDATE_LABEL),
    )

    original = firefly.read_reg(TX_DISABLE_REGISTER)[0]
    baseline_los = firefly.read_reg(LOS_ALARM_REGISTER)[0]
    baseline_lol = firefly.read_reg(CDR_LOL_ALARM_REGISTER)[0]
    disabled = original | (1 << CHANNEL)
    failures = []
    samples = []
    print("FireFly part ID  = {!r}".format(firefly.part_id))
    print("original byte 86 = 0x{:02x}".format(original))
    print("baseline LOS/LOL = 0x{:02x}/0x{:02x}".format(
        baseline_los, baseline_lol))

    restored = False
    try:
        time.sleep(2.0)
        firefly.write_reg(TX_DISABLE_REGISTER, bytes([disabled]))
        require(firefly.read_reg(TX_DISABLE_REGISTER)[0] == disabled,
                "FireFly TX-disable readback mismatch")
        time.sleep(1.0)
        active_los = firefly.read_reg(LOS_ALARM_REGISTER)[0]
        active_lol = firefly.read_reg(CDR_LOL_ALARM_REGISTER)[0]
        print("disabled LOS/LOL = 0x{:02x}/0x{:02x}".format(
            active_los, active_lol))
        if not active_los & 0x01:
            failures.append("FireFly RX0 LOS did not assert")
        if not active_los & 0x10:
            failures.append("FireFly TX0 LOS did not assert")
        if not active_lol & 0x01:
            failures.append("FireFly RX0 CDR LOL did not assert")
        sample_deadline = time.monotonic() + args.disable_seconds - 1.0
        while time.monotonic() < sample_deadline:
            samples.append(read_rx_clock(mailbox, "outage"))
            time.sleep(1.0)
    finally:
        firefly.write_reg(TX_DISABLE_REGISTER, bytes([original]))
        readback = firefly.read_reg(TX_DISABLE_REGISTER)[0]
        restored = readback == original
        print("restored byte 86 = 0x{:02x}".format(readback))
    require(restored, "failed to restore FireFly byte 86")
    require(samples, "no outage clock samples were collected")
    read_rx_clock(mailbox, "restored")

    deadline = time.monotonic() + args.duration_ms / 1000.0 + 20.0
    while mailbox.read_u32(test.REG_RESPONSE_SEQUENCE) != args.sequence:
        require(time.monotonic() < deadline, "timed out waiting for completion")
        time.sleep(0.25)

    overview = test.read_overview(mailbox)
    test.expect("firmware version", overview["firmware version"], VERSION)
    test.expect("hardware version", overview["hardware version"], VERSION)
    test.expect("engine state", overview["engine state"], 0)
    test.expect("response sequence", overview["response sequence"], args.sequence)
    test.expect("response code", overview["response code"],
                SUMMARY_ONE_FAILED_THREE_PASSED)
    test.expect("hardware summary", overview["hardware summary"],
                SUMMARY_ONE_FAILED_THREE_PASSED)
    test.expect("run ID", overview["hardware run ID"],
                (run_id_before + 1) & 0xFFFFFFFF)

    results = {lane: test.read_lane(mailbox, lane) for lane in range(12, 16)}
    for lane, result in results.items():
        print("lane {}: status={:#010x} error_active_cycles={} losses={} "
              "bits={} cycles={}".format(
                  lane, result["id_status"], result["errors"],
                  result["lock_losses"], result["tested_bits"],
                  result["valid_cycles"]))
        require(result["tested_bits"] == result["valid_cycles"] * 80,
                "lane {} bit/cycle mismatch".format(lane))

    disturbed = results[LANE]
    require(disturbed["errors"] > 0,
            "lane 12 recorded no RXPRBSERR-active cycles")
    require(disturbed["errors"] < disturbed["valid_cycles"],
            "lane 12 error-active count is not a bounded subset of measurement")
    require(disturbed["lock_losses"] == 0,
            "lane 12 unexpectedly reported a lock loss")
    for lane in range(13, 16):
        result = results[lane]
        require(result["errors"] == 0,
                "adjacent lane {} recorded error activity".format(lane))
        require(result["lock_losses"] == 0,
                "adjacent lane {} recorded lock loss".format(lane))
    require(not failures, "; ".join(failures))

    fraction = float(disturbed["errors"]) / disturbed["valid_cycles"]
    print("lane 12 error-active fraction = {:.6f}".format(fraction))
    print("outage RXUSRCLK2 range = {}-{} kHz".format(
        min(samples), max(samples)))
    print("MILESTONE {} FIREFLY CHARACTERIZATION PASSED".format(
        CANDIDATE_LABEL))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AttributeError, KeyError, ModuleNotFoundError, RuntimeError) as error:
        print("ERROR: {}".format(error), file=sys.stderr)
        raise SystemExit(1)
