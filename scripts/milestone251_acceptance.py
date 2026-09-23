#!/usr/bin/env python3
"""Run the isolated Milestone 2.5.1 staged-acquisition acceptance matrix.

Program the 0x00020101 Milestone 2.5.1 image immediately before running this
script. The initial mailbox must be clean. This file intentionally does not
import the historical v2.5 or full Milestone 3 operator modules.
"""

import argparse
import importlib
from pathlib import Path
import sys
import time


VERSION = 0x00020101
CANDIDATE_LABEL = "2.5.1"
POST_RUN_DIAGNOSTIC = None
REG_REQUEST_SEQUENCE = 0xA0
REG_COMMAND = 0xA4
REG_DURATION = 0xA8
REG_TIMEOUT = 0xAC
REG_MASK = (0xB0, 0xB4, 0xB8, 0xBC)
REG_FW_VERSION = 0xC0
REG_HW_VERSION = 0xC4
REG_ENGINE_STATE = 0xC8
REG_RESULT_LANE = 0xCC
REG_LANE_RECORD = 0xD0
REG_RESPONSE_SEQUENCE = 0xF0
REG_RESPONSE_CODE = 0xF4
REG_RUN_ID = 0xF8
REG_SUMMARY = 0xFC
DIAGNOSTIC_SELECTOR = 0xFE

COMMAND_EXTERNAL_PRBS31_MS = 0x00010501
COMMAND_PMA_PRBS31_MS = 0x00011501
MANAGED_MASK = 0x0000F000
STATE_RUN = 2
PLATFORM_FAULT = 1 << 16

PRBS_STATES = {
    0: "IDLE", 1: "CONTROL_SETTLE", 2: "RX_RESET_ASSERT",
    3: "RX_RESET_WAIT", 4: "LOOPBACK_SETTLE", 5: "PMA_RESET_ASSERT",
    6: "PMA_RESET_WAIT", 7: "COUNTER_RESET", 8: "LOCK_WAIT",
    9: "POST_LOCK_COUNTER_RESET", 10: "MEASURE", 11: "CAPTURE_WAIT",
    12: "DRP_LOW_START", 13: "DRP_LOW_WAIT", 14: "DRP_HIGH_START",
    15: "DRP_HIGH_WAIT", 16: "CAPTURE_DONE",
    17: "CLEAN_RESET_ASSERT", 18: "CLEAN_RESET_WAIT", 19: "FAULT",
    20: "RX_CHECKER_SETTLE", 21: "ERROR_FREE_QUALIFY",
}

TESTS = (
    (1, COMMAND_EXTERNAL_PRBS31_MS, 10_000, 0x00001000,
     "2.5.1 lane-12 external first run"),
    (2, COMMAND_EXTERNAL_PRBS31_MS, 10_000, 0x00001000,
     "2.5.1 lane-12 external repeat"),
    (3, COMMAND_EXTERNAL_PRBS31_MS, 10_000, 0x0000F000,
     "2.5.1 four-lane external run"),
    (4, COMMAND_PMA_PRBS31_MS, 10_000, 0x0000F000,
     "2.5.1 four-lane near-end PMA run"),
    (5, COMMAND_EXTERNAL_PRBS31_MS, 10_000, 0x00001000,
     "2.5.1 lane-12 external after PMA"),
)


class TestFailure(RuntimeError):
    pass


class Mailbox(object):
    def __init__(self, fpga):
        self.fpga = fpga

    def read_u32(self, address):
        raw = bytes(self.fpga.read_reg(address, size=4))
        if len(raw) != 4:
            raise TestFailure("short read at {:#04x}".format(address))
        return int.from_bytes(raw, "little")

    def write_u32(self, address, value):
        self.fpga.write_reg(address, value, size=4)

    def write_u8(self, address, value):
        self.fpga.write_reg(address, value, size=1)


def load_mailbox(args):
    if args.reg_module is None:
        parent = str(args.cm_interface_root.resolve().parent)
        if parent not in sys.path:
            sys.path.insert(0, parent)
        from cm_interface.registry import Registry
        registry = Registry(setup="tf", dev_path=args.device)
    else:
        registry = importlib.import_module(args.reg_module)
    return Mailbox(registry.fpgas[args.fpga])


def overview(mailbox, heading):
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
    print(heading)
    for name in (
        "request sequence", "firmware version", "hardware version",
        "engine state", "response sequence", "response code",
        "hardware run ID", "hardware summary",
    ):
        print("{:>18} = {:#010x}".format(name, values[name]))
    return values


def bits(value, low, width):
    return (value >> low) & ((1 << width) - 1)


def read_diagnostic_page(mailbox):
    mailbox.write_u8(REG_RESULT_LANE, DIAGNOSTIC_SELECTOR)
    words = [mailbox.read_u32(REG_LANE_RECORD + 4 * index)
             for index in range(8)]
    names = ("platform", "live_prbs", "live_rx", "live_quad",
             "fault_prbs", "fault_rx", "fault_quad", "fault_counter")
    return dict(zip(names, words))


def show_prbs_context(label, word):
    state = bits(word, 0, 5)
    print("\n{} PRBS context:".format(label))
    print("  state          = {} ({})".format(
        state, PRBS_STATES.get(state, "UNKNOWN")))
    print("  loopback       = {:#x}".format(bits(word, 5, 3)))
    print("  selected lanes = {:#x}".format(bits(word, 8, 4)))
    print("  running lanes  = {:#x}".format(bits(word, 12, 4)))
    print("  locked lanes   = {:#x}".format(bits(word, 16, 4)))
    print("  ever locked    = {:#x}".format(bits(word, 20, 4)))
    print("  lost after lock= {:#x}".format(bits(word, 24, 4)))
    print("  acquisition ready = {}".format(bool(word & (1 << 28))))
    print("  runtime RX reset  = {}".format(bool(word & (1 << 29))))
    print("  controller idle   = {}".format(bool(word & (1 << 30))))
    print("  controller fault  = {}".format(bool(word & (1 << 31))))


def print_platform_diagnostics(mailbox):
    values = read_diagnostic_page(mailbox)
    print("\nPlatform diagnostics (selector 0xfe):")
    for name in ("platform", "live_prbs", "live_rx", "live_quad",
                 "fault_prbs", "fault_rx", "fault_quad", "fault_counter"):
        print("  {:>14} = {:#010x}".format(name, values[name]))
    show_prbs_context("Live", values["live_prbs"])
    fault_counter = values["fault_counter"]
    if fault_counter & (1 << 31):
        show_prbs_context("First-fault", values["fault_prbs"])
        fault_rx = values["fault_rx"]
        fault_quad = values["fault_quad"]
        cycles = fault_counter & 0x7FFFFFFF
        print("\nFirst-fault RX qualifiers:")
        print("  Wizard RX done = {}".format(bool(fault_rx & 1)))
        print("  RXRESETDONE     = {:#x}".format(bits(fault_rx, 1, 4)))
        print("  RXPMARESETDONE  = {:#x}".format(bits(fault_rx, 5, 4)))
        print("  DRP enable/ready= {:#x}/{:#x}".format(
            bits(fault_rx, 16, 4), bits(fault_rx, 20, 4)))
        print("  sequencer cycles= {} ({:.6f} s at 200 MHz)".format(
            cycles, float(cycles) / 200000000.0))
        print("  quad state/ready/fault = {}/{}/{}".format(
            bits(fault_quad, 16, 3), bool(fault_quad & (1 << 19)),
            bool(fault_quad & (1 << 20))))
        print("  power/QPLL/TXclk/RXclk = {:#x}/{}/{}/{}".format(
            bits(fault_quad, 0, 4), bool(fault_quad & (1 << 4)),
            bool(fault_quad & (1 << 5)), bool(fault_quad & (1 << 6))))
        print("  TX/RX reset done       = {:#x}/{:#x}".format(
            bits(fault_quad, 7, 4), bits(fault_quad, 11, 4)))
    else:
        print("\nNo first-fault snapshot is valid.")
    platform = values["platform"]
    print("\nLegacy platform decode:")
    print("  quad state/ready/fault = {}/{}/{}".format(
        platform & 7, bool(platform & (1 << 6)),
        bool(platform & (1 << 7))))
    print("  fault reason = {:#04x}".format(bits(platform, 8, 8)))
    return values


def check_version(values):
    for name in ("firmware version", "hardware version"):
        if values[name] != VERSION:
            raise TestFailure(
                "{}: expected {:#010x}, got {:#010x}".format(
                    name, VERSION, values[name]
                )
            )


def require_clean_image(mailbox):
    values = overview(mailbox, "Fresh {} image preflight:".format(
        CANDIDATE_LABEL))
    check_version(values)
    for name in (
        "request sequence", "response sequence", "response code",
        "hardware run ID", "hardware summary",
    ):
        if values[name] != 0:
            raise TestFailure(
                "{} is not zero; reprogram the 2.5.1 image".format(name)
            )
    if values["engine state"] != 0:
        raise TestFailure("engine is not idle after programming")


def lanes_in(mask):
    return [lane for lane in range(12, 16) if mask & (1 << lane)]


def expected_summary(mask):
    count = len(lanes_in(mask))
    return (count << 16) | (count << 8) | 1


def read_lane(mailbox, lane):
    mailbox.write_u8(REG_RESULT_LANE, lane)
    words = [mailbox.read_u32(REG_LANE_RECORD + 4 * index)
             for index in range(8)]
    return {
        "status": words[0],
        "errors": words[1] | (words[2] << 32),
        "bits": words[3] | (words[4] << 32),
        "lock_losses": words[5],
        "cycles": words[6] | (words[7] << 32),
    }


def print_lane(lane, result):
    if result["errors"] == 0 and result["bits"]:
        ber = "BER95<{:.3e}".format(3.0 / result["bits"])
    elif result["status"] & (1 << 14):
        ber = "BER unavailable (native counter saturated)"
    elif result["bits"]:
        ber = "BER={:.3e}".format(
            float(result["errors"]) / result["bits"]
        )
    else:
        ber = "BER unavailable"
    print(
        "lane {}: status={:#010x}, errors={}, lock_losses={}, bits={}, "
        "cycles={}, {}".format(
            lane, result["status"], result["errors"],
            result["lock_losses"], result["bits"], result["cycles"], ber
        )
    )


def lane_failures(lane, result):
    failures = []
    status = result["status"]
    if (status & 0xFF) != lane:
        failures.append("wrong lane ID")
    if (status & 0x1800) != 0x1800:
        failures.append("selected/locked status missing")
    if status & 0x2000:
        failures.append("lock-loss flag set")
    if status & 0x4000:
        failures.append("native error counter saturated")
    if status & 0x8000:
        failures.append("tested-bit counter saturated")
    if result["errors"]:
        failures.append("nonzero error count")
    if result["lock_losses"]:
        failures.append("nonzero lock-loss count")
    if result["bits"] != result["cycles"] * 80:
        failures.append("bit/cycle accounting mismatch")
    return failures


def wait_for_run(mailbox, sequence):
    deadline = time.monotonic() + 15.0
    last = 0
    while time.monotonic() < deadline:
        last = mailbox.read_u32(REG_ENGINE_STATE)
        if (last & 0xF) == STATE_RUN:
            return
        if last & PLATFORM_FAULT:
            print_platform_diagnostics(mailbox)
            raise TestFailure(
                "platform fault during staged acquisition: C8={:#010x}; "
                "persistent selector-0xfe diagnostics are printed above".format(last)
            )
        if mailbox.read_u32(REG_RESPONSE_SEQUENCE) == sequence:
            raise TestFailure("request completed before RUN")
        time.sleep(0.05)
    raise TestFailure(
        "engine did not enter RUN; last C8={:#010x}".format(last)
    )


def wait_for_completion(mailbox, sequence, duration_ms):
    time.sleep(float(duration_ms) / 1000.0 + 2.0)
    deadline = time.monotonic() + 30.0
    while time.monotonic() < deadline:
        state = mailbox.read_u32(REG_ENGINE_STATE)
        if (state & PLATFORM_FAULT):
            print_platform_diagnostics(mailbox)
            raise TestFailure("platform fault while waiting for completion")
        if (mailbox.read_u32(REG_RESPONSE_SEQUENCE) == sequence and state == 0):
            return
        time.sleep(0.2)
    raise TestFailure("firmware did not acknowledge sequence {}".format(sequence))


def run_one(mailbox, sequence, command, duration_ms, mask, label):
    before = overview(mailbox, "\n{} preflight:".format(label))
    check_version(before)
    if before["engine state"] != 0:
        raise TestFailure("engine is not idle")
    descriptor = (
        (REG_COMMAND, command), (REG_DURATION, duration_ms),
        (REG_TIMEOUT, 0), (REG_MASK[0], mask),
        (REG_MASK[1], 0), (REG_MASK[2], 0), (REG_MASK[3], 0),
    )
    print("Writing descriptor:")
    for address, value in descriptor:
        mailbox.write_u32(address, value)
    for address, expected in descriptor:
        actual = mailbox.read_u32(address)
        print("  register {:#04x} = {:#010x}".format(address, actual))
        if actual != expected:
            raise TestFailure("descriptor readback mismatch")
    mailbox.write_u32(REG_REQUEST_SEQUENCE, sequence)
    print("  request sequence = {:#010x}".format(sequence))
    wait_for_run(mailbox, sequence)
    print("  RUN entered; sleeping through {} ms".format(duration_ms))
    wait_for_completion(mailbox, sequence, duration_ms)

    final = overview(mailbox, "{} final state:".format(label))
    check_version(final)
    expected = expected_summary(mask)
    failures = []
    if final["response sequence"] != sequence:
        failures.append("response sequence mismatch")
    if final["response code"] != expected:
        failures.append("response code expected {:#010x}".format(expected))
    if final["hardware summary"] != expected:
        failures.append("hardware summary expected {:#010x}".format(expected))
    if final["hardware run ID"] != before["hardware run ID"] + 1:
        failures.append("run ID did not advance once")
    print("Published lane records:")
    for lane in lanes_in(mask):
        result = read_lane(mailbox, lane)
        print_lane(lane, result)
        failures.extend(
            "lane {}: {}".format(lane, item)
            for item in lane_failures(lane, result)
        )
    if POST_RUN_DIAGNOSTIC is not None:
        POST_RUN_DIAGNOSTIC(mailbox)
    if failures:
        print("{}: FAIL".format(label))
        for failure in failures:
            print("  - {}".format(failure))
        return False
    print("{}: PASS".format(label))
    return True


def add_connection_arguments(parser):
    parser.add_argument(
        "--cm-interface-root", type=Path,
        default=Path("/nfs/cms/hw/wittich/int_test/cm_interface")
    )
    parser.add_argument("--device", default="/dev/ttyUL4")
    parser.add_argument("--reg-module", default=None)
    parser.add_argument("--fpga", default="F1")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    add_connection_arguments(parser)
    args = parser.parse_args()
    try:
        mailbox = load_mailbox(args)
        require_clean_image(mailbox)
        results = []
        for test in TESTS:
            results.append((test[0], test[4], run_one(mailbox, *test)))
        print("\nMILESTONE {} ACCEPTANCE SUMMARY:".format(
            CANDIDATE_LABEL))
        for sequence, label, passed in results:
            print("  sequence {}: {:4s} - {}".format(
                sequence, "PASS" if passed else "FAIL", label
            ))
        if not all(item[2] for item in results):
            raise TestFailure("one or more acceptance jobs failed")
        print("\nMILESTONE {} ACCEPTANCE PASSED".format(CANDIDATE_LABEL))
        return 0
    except (AttributeError, KeyError, ModuleNotFoundError,
            OSError, TestFailure) as error:
        print("ERROR: {}".format(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
