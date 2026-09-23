#!/usr/bin/env python3
"""Run the Milestone 3 MicroBlaze-halted completion test.

This script deliberately does not control XSDB.  Run its stages around the
manual MicroBlaze halt/resume operation:

  python3 scripts/milestone3_cpu_halted_test.py start
  # In XSDB: verify engine state 2, then execute "stop".
  # Leave MicroBlaze halted until five minutes after the start command.
  python3 scripts/milestone3_cpu_halted_test.py halted
  # In XSDB: execute "con".
  python3 scripts/milestone3_cpu_halted_test.py resumed

By default, ``Registry(setup="tf")`` creates ``reg`` and F1 is selected through
``reg.fpgas['F1']``.  Use --reg-module or --fpga if the interface is exposed
under a different importable module or FPGA name.
"""

import argparse
import importlib
from pathlib import Path
import sys
import time
from typing import Any, Dict

import milestone3_12hour_external_soak as external_test


FW_VERSION = 0x0002000B
HW_VERSION = 0x0002000B

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

COMMAND_PMA_PRBS31_MS = 0x00011501
DURATION_FIVE_MINUTES_MS = 300_000
MANAGED_LANE_MASK = 0x0000F000

SUMMARY_NORMAL_FOUR_LANES = 0x00040401
STATE_RUN = 2
STATE_INTERRUPT_PENDING = 1 << 14
PLATFORM_FAULT_BIT = 1 << 16


def fail(message: str) -> None:
    raise RuntimeError(message)


class FpgaMailbox:
    def __init__(self, fpga: Any) -> None:
        self.fpga = fpga

    def read(self, address: int, size: int = 4) -> bytes:
        raw = self.fpga.read_reg(address, size=size)
        value = bytes(raw)
        if len(value) != size:
            fail(
                f"read_reg({address:#04x}, size={size}) returned "
                f"{len(value)} bytes"
            )
        return value

    def read_u32(self, address: int) -> int:
        return int.from_bytes(self.read(address, 4), "little")

    def write_u32(self, address: int, value: int) -> None:
        self.fpga.write_reg(address, value, size=4)

    def write_u8(self, address: int, value: int) -> None:
        self.fpga.write_reg(address, value, size=1)


def expect(name: str, actual: int, expected: int) -> None:
    print(f"{name:>18} = {actual:#010x}")
    if actual != expected:
        fail(f"{name}: expected {expected:#010x}, received {actual:#010x}")


def warn_expect(name: str, actual: int, expected: int) -> None:
    print(f"{name:>18} = {actual:#010x}")
    if actual != expected:
        print(
            f"WARNING: {name}: expected {expected:#010x}, "
            f"received {actual:#010x}; continuing because FPGA "
            "reprogramming resets sequence history",
            file=sys.stderr,
        )


def read_overview(mailbox: FpgaMailbox) -> Dict[str, int]:
    fields = {
        "firmware version": mailbox.read_u32(REG_FW_VERSION),
        "hardware version": mailbox.read_u32(REG_HW_VERSION),
        "engine state": mailbox.read_u32(REG_ENGINE_STATE),
        "response sequence": mailbox.read_u32(REG_RESPONSE_SEQUENCE),
        "response code": mailbox.read_u32(REG_RESPONSE_CODE),
        "hardware run ID": mailbox.read_u32(REG_RUN_ID),
        "hardware summary": mailbox.read_u32(REG_SUMMARY),
    }
    for name, value in fields.items():
        print(f"{name:>18} = {value:#010x}")
    return fields


def wait_for_run(mailbox: FpgaMailbox, timeout_seconds: float = 15.0) -> int:
    deadline = time.monotonic() + timeout_seconds
    while True:
        status = mailbox.read_u32(REG_ENGINE_STATE)
        if (status & 0xF) == STATE_RUN:
            return status
        if status & PLATFORM_FAULT_BIT:
            external_test.print_platform_diagnostics(mailbox)
            fail(
                "platform fault while waiting for RUN; persistent diagnostic "
                "context is printed above"
            )
        if time.monotonic() >= deadline:
            external_test.print_platform_diagnostics(mailbox)
            fail(
                f"engine did not reach RUN state 2 within {timeout_seconds:g} s; "
                f"last C8 value was {status:#010x}"
            )
        time.sleep(0.05)


def start_test(
    mailbox: FpgaMailbox,
    sequence: int,
    previous: int,
    previous_run_id: int,
    previous_summary: int,
) -> None:
    print("Preflight:")
    status = read_overview(mailbox)
    if status["engine state"] & PLATFORM_FAULT_BIT:
        external_test.print_platform_diagnostics(mailbox)
        fail("latched platform fault at preflight; reprogram before starting")
    expect("firmware version", status["firmware version"], FW_VERSION)
    expect("hardware version", status["hardware version"], HW_VERSION)
    expect("engine state", status["engine state"], 0)
    warn_expect("response sequence", status["response sequence"], previous)
    warn_expect("hardware run ID", status["hardware run ID"], previous_run_id)
    warn_expect("response code", status["response code"], previous_summary)
    warn_expect("hardware summary", status["hardware summary"], previous_summary)

    descriptor = {
        REG_COMMAND: COMMAND_PMA_PRBS31_MS,
        REG_DURATION: DURATION_FIVE_MINUTES_MS,
        REG_TIMEOUT: 0,
        REG_MASK_0: MANAGED_LANE_MASK,
        REG_MASK_1: 0,
        REG_MASK_2: 0,
        REG_MASK_3: 0,
    }

    print("\nWriting descriptor (sequence commit is intentionally last):")
    for address, value in descriptor.items():
        mailbox.write_u32(address, value)

    print("Verifying descriptor:")
    for address, expected in descriptor.items():
        expect(f"register {address:#04x}", mailbox.read_u32(address), expected)

    mailbox.write_u32(REG_REQUEST_SEQUENCE, sequence)
    expect("request sequence", mailbox.read_u32(REG_REQUEST_SEQUENCE), sequence)
    state = wait_for_run(mailbox)
    print(f"      engine state = {state:#010x} (RUN)")

    print(
        "\nThe five-minute test is running. In XSDB, select MicroBlaze #0, "
        "verify mrd 0x44a00010 reports 00000002, then execute 'stop'. "
        "Leave it halted until at least five minutes after this launch."
    )


def read_lane(mailbox: FpgaMailbox, lane: int) -> Dict[str, int]:
    mailbox.write_u8(REG_RESULT_LANE, lane)
    words = [mailbox.read_u32(REG_LANE_RECORD + 4 * index) for index in range(8)]
    return {
        "id_status": words[0],
        "errors": words[1] | (words[2] << 32),
        "tested_bits": words[3] | (words[4] << 32),
        "lock_losses": words[5],
        "valid_cycles": words[6] | (words[7] << 32),
    }


def check_halted(
    mailbox: FpgaMailbox,
    sequence: int,
    previous: int,
    previous_run_id: int,
    previous_summary: int,
) -> None:
    print("Completion state while MicroBlaze is halted:")
    status = read_overview(mailbox)
    if status["engine state"] & PLATFORM_FAULT_BIT:
        external_test.print_platform_diagnostics(mailbox)
        fail("platform fault while MicroBlaze was halted")
    expect("firmware version", status["firmware version"], FW_VERSION)
    expect("hardware version", status["hardware version"], HW_VERSION)
    warn_expect("response sequence", status["response sequence"], previous)
    expect("hardware run ID", status["hardware run ID"], previous_run_id + 1)
    expect("hardware summary", status["hardware summary"], SUMMARY_NORMAL_FOUR_LANES)
    expect("engine state", status["engine state"], STATE_INTERRUPT_PENDING)
    warn_expect("response code", status["response code"], previous_summary)

    run_id_before = mailbox.read_u32(REG_RUN_ID)
    results = {lane: read_lane(mailbox, lane) for lane in range(12, 16)}
    run_id_after = mailbox.read_u32(REG_RUN_ID)
    print(f"     run ID before = {run_id_before:#010x}")
    expect("run ID after", run_id_after, run_id_before)

    print("\nPublished lane records:")
    for lane, result in results.items():
        print(
            f"lane {lane}: id/status={result['id_status']:#010x}, "
            f"errors={result['errors']}, lock_losses={result['lock_losses']}, "
            f"tested_bits={result['tested_bits']}, "
            f"valid_cycles={result['valid_cycles']}"
        )
        if (result["id_status"] & 0xFF) != lane:
            fail(f"lane {lane}: result contains the wrong lane ID")
        if (result["id_status"] & ((1 << 11) | (1 << 12))) != (
            (1 << 11) | (1 << 12)
        ):
            fail(f"lane {lane}: selected/locked status is not set")
        if result["id_status"] & ((1 << 13) | (1 << 14) | (1 << 15)):
            fail(f"lane {lane}: lock-loss or counter-saturation status is set")
        if result["errors"] != 0:
            fail(f"lane {lane}: expected zero errors")
        if result["lock_losses"] != 0:
            fail(f"lane {lane}: expected zero lock losses")
        if result["tested_bits"] != result["valid_cycles"] * 80:
            fail(f"lane {lane}: tested-bit and valid-cycle counts disagree")

    print(
        "\nHALTED CHECK PASSED. In XSDB execute 'con', wait a few seconds, "
        "then run this script with the 'resumed' stage."
    )


def check_resumed(
    mailbox: FpgaMailbox, sequence: int, expected_run_id: int
) -> None:
    print("Final state after resuming MicroBlaze:")
    status = read_overview(mailbox)
    if status["engine state"] & PLATFORM_FAULT_BIT:
        external_test.print_platform_diagnostics(mailbox)
        fail("platform fault after MicroBlaze resume")
    expect("firmware version", status["firmware version"], FW_VERSION)
    expect("hardware version", status["hardware version"], HW_VERSION)
    warn_expect("response sequence", status["response sequence"], sequence)
    expect("response code", status["response code"], SUMMARY_NORMAL_FOUR_LANES)
    expect("hardware run ID", status["hardware run ID"], expected_run_id)
    expect("hardware summary", status["hardware summary"], SUMMARY_NORMAL_FOUR_LANES)
    expect("engine state", status["engine state"], 0)
    print("\nRESUMED CHECK PASSED: firmware acknowledged the existing hardware result.")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=("start", "halted", "resumed"))
    parser.add_argument(
        "--reg-module",
        default=None,
        help=(
            "optional importable module exposing fpgas; by default create "
            "Registry(setup='tf') on /dev/ttyUL4"
        ),
    )
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
    parser.add_argument("--fpga", default="F1", help="FPGA key (default: F1)")
    parser.add_argument(
        "--sequence", type=lambda value: int(value, 0), default=6,
        help="new request sequence (default: 6)",
    )
    parser.add_argument(
        "--previous-sequence", type=lambda value: int(value, 0), default=5,
        help="previous completed sequence (default: 5)",
    )
    parser.add_argument(
        "--previous-run-id", type=lambda value: int(value, 0), default=4,
        help="hardware run ID before this test (default: 4)",
    )
    parser.add_argument(
        "--previous-summary", type=lambda value: int(value, 0),
        default=SUMMARY_NORMAL_FOUR_LANES,
        help="firmware/hardware summary before this test (default: 0x00040401)",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        if args.reg_module is None:
            # The checkout is itself the cm_interface package directory, so
            # Python needs its parent on sys.path. Construct Registry only
            # after argument parsing so --help never opens the board device.
            package_parent = str(args.cm_interface_root.resolve().parent)
            if package_parent not in sys.path:
                sys.path.insert(0, package_parent)
            from cm_interface.registry import Registry

            registry = Registry(setup="tf", dev_path=args.device)
        else:
            registry = importlib.import_module(args.reg_module)
        mailbox = FpgaMailbox(registry.fpgas[args.fpga])

        if args.stage == "start":
            start_test(
                mailbox,
                args.sequence,
                args.previous_sequence,
                args.previous_run_id,
                args.previous_summary,
            )
        elif args.stage == "halted":
            check_halted(
                mailbox,
                args.sequence,
                args.previous_sequence,
                args.previous_run_id,
                args.previous_summary,
            )
        else:
            check_resumed(mailbox, args.sequence, args.previous_run_id + 1)
    except (AttributeError, KeyError, ModuleNotFoundError, RuntimeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
