#!/usr/bin/env python3
"""Shared support for the preserved Milestone 2.5 (0x00020004) image only.

This module is intentionally independent of the current Milestone 3 utilities.
It uses the Python 3.6-compatible ``cm_interface`` generic FPGA-register API.
"""

import argparse
import importlib
from pathlib import Path
import sys
import time


FW_VERSION = 0x00020004
HW_VERSION = 0x00020004

REG_REQUEST_SEQUENCE = 0xA0
REG_COMMAND = 0xA4
REG_DURATION = 0xA8
REG_TIMEOUT = 0xAC
REG_MASK_0 = 0xB0
REG_MASK_1 = 0xB4
REG_MASK_2 = 0xB8
REG_MASK_3 = 0xBC
REG_FW_VERSION = 0xC0
REG_HW_VERSION = 0xC4
REG_ENGINE_STATE = 0xC8
REG_RESULT_LANE = 0xCC
REG_LANE_RECORD = 0xD0
REG_RESPONSE_SEQUENCE = 0xF0
REG_RESPONSE_CODE = 0xF4
REG_RUN_ID = 0xF8
REG_SUMMARY = 0xFC

COMMAND_EXTERNAL_PRBS31_MS = 0x00010501
COMMAND_PMA_PRBS31_MS = 0x00011501
MANAGED_LANE_MASK = 0x0000F000
STATE_RUN = 2
PLATFORM_FAULT_BIT = 1 << 16


def fail(message):
    raise RuntimeError(message)


class FpgaMailbox(object):
    def __init__(self, fpga):
        self.fpga = fpga

    def read(self, address, size=4):
        raw = bytes(self.fpga.read_reg(address, size=size))
        if len(raw) != size:
            fail(
                "read_reg({:#04x}, size={}) returned {} bytes".format(
                    address, size, len(raw)
                )
            )
        return raw

    def read_u32(self, address):
        return int.from_bytes(self.read(address, 4), "little")

    def write_u32(self, address, value):
        self.fpga.write_reg(address, value, size=4)

    def write_u8(self, address, value):
        self.fpga.write_reg(address, value, size=1)


def add_connection_arguments(parser):
    parser.add_argument(
        "--cm-interface-root",
        type=Path,
        default=Path("/nfs/cms/hw/wittich/int_test/cm_interface"),
        help="cm_interface package directory",
    )
    parser.add_argument(
        "--device",
        default="/dev/ttyUL4",
        help="MCU serial device used by Registry (default: /dev/ttyUL4)",
    )
    parser.add_argument(
        "--reg-module",
        default=None,
        help="optional importable module that directly exposes fpgas",
    )
    parser.add_argument("--fpga", default="F1", help="FPGA key (default: F1)")


def load_mailbox(args):
    if args.reg_module is None:
        package_parent = str(args.cm_interface_root.resolve().parent)
        if package_parent not in sys.path:
            sys.path.insert(0, package_parent)
        from cm_interface.registry import Registry

        registry = Registry(setup="tf", dev_path=args.device)
    else:
        registry = importlib.import_module(args.reg_module)
    return FpgaMailbox(registry.fpgas[args.fpga])


def read_overview(mailbox, heading=None):
    if heading:
        print(heading)
    values = {
        "request sequence": mailbox.read_u32(REG_REQUEST_SEQUENCE),
        "firmware version": mailbox.read_u32(REG_FW_VERSION),
        "hardware version": mailbox.read_u32(REG_HW_VERSION),
        "engine state": mailbox.read_u32(REG_ENGINE_STATE),
        "response sequence": mailbox.read_u32(REG_RESPONSE_SEQUENCE),
        "response code": mailbox.read_u32(REG_RESPONSE_CODE),
        "hardware run ID": mailbox.read_u32(REG_RUN_ID),
        "hardware summary": mailbox.read_u32(REG_SUMMARY),
    }
    for name in (
        "request sequence", "firmware version", "hardware version",
        "engine state", "response sequence", "response code",
        "hardware run ID", "hardware summary",
    ):
        print("{:>18} = {:#010x}".format(name, values[name]))
    return values


def require_version(overview):
    if overview["firmware version"] != FW_VERSION:
        fail(
            "this is a Milestone 2.5-only script: expected firmware "
            "{:#010x}, received {:#010x}".format(
                FW_VERSION, overview["firmware version"]
            )
        )
    if overview["hardware version"] != HW_VERSION:
        fail(
            "this is a Milestone 2.5-only script: expected hardware "
            "{:#010x}, received {:#010x}".format(
                HW_VERSION, overview["hardware version"]
            )
        )


def require_clean_reprogram(mailbox):
    overview = read_overview(mailbox, "Fresh-image preflight:")
    require_version(overview)
    for name in (
        "request sequence", "response sequence", "hardware run ID",
        "response code", "hardware summary",
    ):
        if overview[name] != 0:
            fail(
                "{} is {:#010x}, not zero; reprogram the preserved v2.5 "
                "bitstream before starting this script".format(
                    name, overview[name]
                )
            )
    if overview["engine state"] != 0:
        fail("engine is not idle after reprogramming")


def selected_lanes(lane_mask):
    return [lane for lane in range(12, 16) if lane_mask & (1 << lane)]


def expected_summary(lane_mask):
    count = len(selected_lanes(lane_mask))
    return (count << 16) | (count << 8) | 1


def wait_for_run(mailbox, sequence, timeout_seconds=15.0):
    deadline = time.monotonic() + timeout_seconds
    last_state = 0
    while time.monotonic() < deadline:
        last_state = mailbox.read_u32(REG_ENGINE_STATE)
        if (last_state & 0xF) == STATE_RUN:
            return
        if last_state & PLATFORM_FAULT_BIT:
            fail(
                "platform fault while waiting for RUN: C8={:#010x}".format(
                    last_state
                )
            )
        if mailbox.read_u32(REG_RESPONSE_SEQUENCE) == sequence:
            fail("request completed before reaching RUN; inspect F4 and FC")
        time.sleep(0.05)
    fail(
        "engine did not reach RUN within {:.1f} s; last C8={:#010x}".format(
            timeout_seconds, last_state
        )
    )


def wait_for_completion(mailbox, sequence, duration_ms, timeout_seconds=30.0):
    # Avoid unnecessary I2C polling during the HDL-owned measurement interval.
    time.sleep(float(duration_ms) / 1000.0 + 2.0)
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        response = mailbox.read_u32(REG_RESPONSE_SEQUENCE)
        state = mailbox.read_u32(REG_ENGINE_STATE)
        if response == sequence and state == 0:
            return
        if state & PLATFORM_FAULT_BIT:
            fail("platform fault while waiting for completion")
        time.sleep(0.20)
    fail("firmware did not acknowledge sequence {} after the run".format(sequence))


def read_lane(mailbox, lane):
    mailbox.write_u8(REG_RESULT_LANE, lane)
    words = [mailbox.read_u32(REG_LANE_RECORD + 4 * index)
             for index in range(8)]
    return {
        "id_status": words[0],
        "errors": words[1] | (words[2] << 32),
        "tested_bits": words[3] | (words[4] << 32),
        "lock_losses": words[5],
        "valid_cycles": words[6] | (words[7] << 32),
    }


def lane_failure_reasons(lane, result):
    status = result["id_status"]
    reasons = []
    if (status & 0xFF) != lane:
        reasons.append("wrong record lane ID")
    if (status & ((1 << 11) | (1 << 12))) != ((1 << 11) | (1 << 12)):
        reasons.append("selected/locked status is not set")
    if status & (1 << 13):
        reasons.append("lock-loss flag is set")
    if status & (1 << 14):
        reasons.append("native error counter saturated")
    if status & (1 << 15):
        reasons.append("tested-bit counter saturated")
    if result["errors"] != 0:
        reasons.append("expected zero errors")
    if result["lock_losses"] != 0:
        reasons.append("expected zero lock losses")
    if result["tested_bits"] != result["valid_cycles"] * 80:
        reasons.append("tested-bit and valid-cycle counts disagree")
    return reasons


def print_lane(lane, result):
    bits = result["tested_bits"]
    errors = result["errors"]
    saturated = bool(result["id_status"] & (1 << 14))
    if errors == 0 and bits:
        ber_text = "BER95<{:.3e}".format(3.0 / bits)
    elif saturated:
        ber_text = "measured_BER=unavailable(error_count_saturated)"
    elif bits:
        ber_text = "measured_BER={:.3e}".format(float(errors) / bits)
    else:
        ber_text = "measured_BER=unavailable(zero_tested_bits)"
    print(
        "lane {}: id/status={:#010x}, errors={}, lock_losses={}, "
        "tested_bits={}, valid_cycles={}, {}".format(
            lane, result["id_status"], errors, result["lock_losses"],
            bits, result["valid_cycles"], ber_text
        )
    )


def run_test(mailbox, sequence, command, duration_ms, lane_mask, label):
    if lane_mask == 0 or lane_mask & ~MANAGED_LANE_MASK:
        fail("lane mask may contain only managed lanes 12-15")

    before = read_overview(mailbox, "\n{} preflight:".format(label))
    require_version(before)
    if before["engine state"] != 0:
        fail("engine is not idle before {}".format(label))
    if before["request sequence"] == sequence:
        fail("request sequence {} is already present".format(sequence))

    descriptor = (
        (REG_COMMAND, command),
        (REG_DURATION, duration_ms),
        (REG_TIMEOUT, 0),
        (REG_MASK_0, lane_mask),
        (REG_MASK_1, 0),
        (REG_MASK_2, 0),
        (REG_MASK_3, 0),
    )
    print("\nWriting {} descriptor:".format(label))
    for address, value in descriptor:
        mailbox.write_u32(address, value)
    for address, expected in descriptor:
        actual = mailbox.read_u32(address)
        print("  register {:#04x} = {:#010x}".format(address, actual))
        if actual != expected:
            fail(
                "register {:#04x}: expected {:#010x}, got {:#010x}".format(
                    address, expected, actual
                )
            )

    mailbox.write_u32(REG_REQUEST_SEQUENCE, sequence)
    print("  request sequence = {:#010x}".format(sequence))
    wait_for_run(mailbox, sequence)
    print("  engine entered RUN; sleeping through {} ms measurement".format(
        duration_ms
    ))
    wait_for_completion(mailbox, sequence, duration_ms)

    final = read_overview(mailbox, "{} final state:".format(label))
    require_version(final)
    lanes = selected_lanes(lane_mask)
    run_id_before = mailbox.read_u32(REG_RUN_ID)
    records = {lane: read_lane(mailbox, lane) for lane in lanes}
    run_id_after = mailbox.read_u32(REG_RUN_ID)

    failures = []
    expected = expected_summary(lane_mask)
    if final["response sequence"] != sequence:
        failures.append("response sequence does not match request")
    if final["response code"] != expected:
        failures.append(
            "response code expected {:#010x}, got {:#010x}".format(
                expected, final["response code"]
            )
        )
    if final["hardware summary"] != expected:
        failures.append(
            "hardware summary expected {:#010x}, got {:#010x}".format(
                expected, final["hardware summary"]
            )
        )
    if final["engine state"] != 0:
        failures.append("engine did not return to IDLE")
    if run_id_before != run_id_after:
        failures.append("run ID changed while records were read")
    if run_id_after != before["hardware run ID"] + 1:
        failures.append("run ID did not advance exactly once")

    print("Published lane records:")
    for lane in lanes:
        print_lane(lane, records[lane])
        for reason in lane_failure_reasons(lane, records[lane]):
            failures.append("lane {}: {}".format(lane, reason))

    if failures:
        print("{}: FAIL".format(label))
        for reason in failures:
            print("  - {}".format(reason))
    else:
        print("{}: PASS".format(label))

    return {
        "label": label,
        "sequence": sequence,
        "passed": not failures,
        "failures": failures,
        "overview": final,
        "records": records,
    }
