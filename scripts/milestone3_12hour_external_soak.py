#!/usr/bin/env python3
"""Run and inspect the Milestone 3 12-hour external-path PRBS31 soak.

The script is compatible with Python 3.6. Run one stage at a time:

  python3 scripts/milestone3_12hour_external_soak.py start
  python3 scripts/milestone3_12hour_external_soak.py status
  python3 scripts/milestone3_12hour_external_soak.py results

Before ``start``, connect the intended optical loopback or configure the
external PRBS partner. This descriptor deliberately disables internal GT
loopback. Record F1 AVTT current and FPGA temperature before and after the run.
"""

import argparse
import importlib
from pathlib import Path
import sys
import time
from typing import Any, Dict


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

# Parallel BER, PRBS31, external path (LOOPBACK=000), millisecond timebase.
COMMAND_EXTERNAL_PRBS31_MS = 0x00010501
DURATION_TWELVE_HOURS_MS = 43_200_000
MANAGED_LANE_MASK = 0x0000F000

SUMMARY_NORMAL_FOUR_LANES = 0x00040401
STATE_RUN = 2
PLATFORM_FAULT_BIT = 1 << 16
DIAGNOSTIC_SELECTOR = 0xFE

PRBS_STATES = {
    0: "IDLE", 1: "CONTROL_SETTLE", 2: "RX_RESET_ASSERT",
    3: "RX_RESET_WAIT", 4: "LOOPBACK_SETTLE", 5: "PMA_RESET_ASSERT",
    6: "PMA_RESET_WAIT", 7: "COUNTER_RESET", 8: "LOCK_WAIT",
    9: "POST_LOCK_COUNTER_RESET", 10: "MEASURE", 11: "CAPTURE_WAIT",
    12: "DRP_LOW_START", 13: "DRP_LOW_WAIT", 14: "DRP_HIGH_START",
    15: "DRP_HIGH_WAIT", 16: "CAPTURE_DONE",
    17: "CLEAN_RESET_ASSERT", 18: "CLEAN_RESET_WAIT", 19: "FAULT",
    20: "RX_CHECKER_SETTLE", 21: "FIXED_ACQUISITION_OBSERVE",
    22: "POST_CAPTURE_RX_REQUAL",
    23: "QUAD_RESTART_REQUEST", 24: "QUAD_RESTART_WAIT",
}


def fail(message: str) -> None:
    raise RuntimeError(message)


class FpgaMailbox:
    def __init__(self, fpga: Any) -> None:
        self.fpga = fpga

    def read(self, address: int, size: int = 4) -> bytes:
        raw = bytes(self.fpga.read_reg(address, size=size))
        if len(raw) != size:
            fail(
                f"read_reg({address:#04x}, size={size}) returned "
                f"{len(raw)} bytes"
            )
        return raw

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
            f"received {actual:#010x}; FPGA reprogramming may have reset "
            "the prior sequence history",
            file=sys.stderr,
        )


def read_overview(mailbox: FpgaMailbox) -> Dict[str, int]:
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
    for name, value in values.items():
        print(f"{name:>18} = {value:#010x}")
    return values


def read_diagnostic_page(mailbox: FpgaMailbox) -> Dict[str, int]:
    """Select and read the persistent platform-diagnostic page over I2C."""
    mailbox.write_u8(REG_RESULT_LANE, DIAGNOSTIC_SELECTOR)
    words = [mailbox.read_u32(REG_LANE_RECORD + 4 * index)
             for index in range(8)]
    return {
        "platform": words[0], "live_prbs": words[1],
        "live_rx": words[2], "live_quad": words[3],
        "fault_prbs": words[4], "fault_rx": words[5],
        "fault_quad": words[6], "fault_counter": words[7],
    }


def _bits(value: int, low: int, width: int) -> int:
    return (value >> low) & ((1 << width) - 1)


def print_platform_diagnostics(mailbox: FpgaMailbox) -> Dict[str, int]:
    values = read_diagnostic_page(mailbox)
    platform = values["platform"]
    live = values["live_prbs"]
    rx = values["live_rx"]
    quad = values["live_quad"]
    fault = values["fault_prbs"]
    fault_rx = values["fault_rx"]
    fault_quad = values["fault_quad"]
    fault_counter = values["fault_counter"]

    print("\nPlatform diagnostics (selector 0xfe):")
    for name in ("platform", "live_prbs", "live_rx", "live_quad",
                 "fault_prbs", "fault_rx", "fault_quad", "fault_counter"):
        print("  {:>14} = {:#010x}".format(name, values[name]))

    def show_prbs(label: str, word: int) -> None:
        state = _bits(word, 0, 5)
        print("\n{} PRBS context:".format(label))
        print("  state          = {} ({})".format(
            state, PRBS_STATES.get(state, "UNKNOWN")))
        print("  loopback       = {:#x}".format(_bits(word, 5, 3)))
        print("  selected lanes = {:#x}".format(_bits(word, 8, 4)))
        print("  running lanes  = {:#x}".format(_bits(word, 12, 4)))
        print("  locked lanes   = {:#x}".format(_bits(word, 16, 4)))
        print("  ever locked    = {:#x}".format(_bits(word, 20, 4)))
        print("  lost after lock= {:#x}".format(_bits(word, 24, 4)))
        print("  acquisition ready = {}".format(bool(word & (1 << 28))))
        print("  runtime RX reset  = {}".format(bool(word & (1 << 29))))
        print("  controller idle   = {}".format(bool(word & (1 << 30))))
        print("  controller fault  = {}".format(bool(word & (1 << 31))))

    def show_fixed_observation(label: str, word: int) -> None:
        print("\n{} fixed acquisition observation:".format(label))
        print("  format marker      = {}".format(bool(word & 1)))
        print("  sampled-error lanes= {:#x}".format(_bits(word, 28, 4)))
        print("  sampled-unlock lanes= {:#x}".format(_bits(word, 24, 4)))
        maximum_clean = _bits(word, 6, 18)
        print("  maximum clean streak= {} cycles ({:.3f} us)".format(
            maximum_clean, float(maximum_clean) / 200.0))
        print("  live selected error = {}".format(bool(word & (1 << 5))))
        print("  live selected locked= {}".format(bool(word & (1 << 4))))
        print("  Wizard RX done      = {}".format(bool(word & (1 << 3))))
        print("  selected RX done    = {}".format(bool(word & (1 << 2))))
        print("  selected PMA done   = {}".format(bool(word & (1 << 1))))

    show_prbs("Live", live)
    show_fixed_observation("Retained", rx)
    if fault_counter & (1 << 31):
        show_prbs("First-fault", fault)
        show_fixed_observation("First-fault", fault_rx)
        print("  sequencer cycles= {} ({:.6f} s at 200 MHz)".format(
            fault_counter & 0x7FFFFFFF,
            float(fault_counter & 0x7FFFFFFF) / 200_000_000.0))
        print("  quad state/ready/fault = {}/{}/{}".format(
            _bits(fault_quad, 16, 3), bool(fault_quad & (1 << 19)),
            bool(fault_quad & (1 << 20))))
        print("  power/QPLL/TXclk/RXclk = {:#x}/{}/{}/{}".format(
            _bits(fault_quad, 0, 4), bool(fault_quad & (1 << 4)),
            bool(fault_quad & (1 << 5)), bool(fault_quad & (1 << 6))))
        print("  TX/RX reset done       = {:#x}/{:#x}".format(
            _bits(fault_quad, 7, 4), _bits(fault_quad, 11, 4)))
    else:
        print("\nNo first-fault snapshot is valid.")

    print("\nLegacy platform decode:")
    print("  quad state/ready/fault = {}/{}/{}".format(
        platform & 7, bool(platform & (1 << 6)),
        bool(platform & (1 << 7))))
    print("  fault reason = {:#04x}".format(_bits(platform, 8, 8)))
    return values


def wait_for_run(mailbox: FpgaMailbox, timeout_seconds: float = 15.0) -> int:
    deadline = time.monotonic() + timeout_seconds
    while True:
        status = mailbox.read_u32(REG_ENGINE_STATE)
        if (status & 0xF) == STATE_RUN:
            return status
        if status & PLATFORM_FAULT_BIT:
            print_platform_diagnostics(mailbox)
            fail(
                "platform fault while waiting for RUN; persistent diagnostic "
                "context is printed above"
            )
        if time.monotonic() >= deadline:
            print_platform_diagnostics(mailbox)
            fail(
                f"engine did not reach RUN state 2 within {timeout_seconds:g} s; "
                f"last C8 value was {status:#010x}"
            )
        time.sleep(0.05)


def start_soak(
    mailbox: FpgaMailbox,
    sequence: int,
    previous: int,
    duration_ms: int = DURATION_TWELVE_HOURS_MS,
    run_label: str = "12-hour external soak",
    lane_mask: int = MANAGED_LANE_MASK,
) -> None:
    if lane_mask == 0 or lane_mask & ~MANAGED_LANE_MASK:
        fail(
            "lane mask must select at least one managed lane and may contain "
            "only global lanes 12-15 (mask 0x0000f000)"
        )
    print("Preflight:")
    overview = read_overview(mailbox)
    expect("firmware version", overview["firmware version"], FW_VERSION)
    expect("hardware version", overview["hardware version"], HW_VERSION)
    expect("engine state", overview["engine state"], 0)
    warn_expect("response sequence", overview["response sequence"], previous)

    if overview["request sequence"] == sequence:
        fail(
            f"request sequence {sequence} is already present at A0; choose a "
            "different --sequence or reprogram before attempting a new run"
        )

    descriptor = {
        REG_COMMAND: COMMAND_EXTERNAL_PRBS31_MS,
        REG_DURATION: duration_ms,
        REG_TIMEOUT: 0,
        REG_MASK_0: lane_mask,
        REG_MASK_1: 0,
        REG_MASK_2: 0,
        REG_MASK_3: 0,
    }

    print(f"\nWriting {run_label} descriptor:")
    for address, value in descriptor.items():
        mailbox.write_u32(address, value)

    print("Verifying descriptor before commit:")
    for address, expected in descriptor.items():
        expect(f"register {address:#04x}", mailbox.read_u32(address), expected)

    mailbox.write_u32(REG_REQUEST_SEQUENCE, sequence)
    expect("request sequence", mailbox.read_u32(REG_REQUEST_SEQUENCE), sequence)
    state = wait_for_run(mailbox)
    print(f"      engine state = {state:#010x} (RUN)")
    print(f"\n{run_label.upper()} STARTED ({duration_ms} ms).")
    print(
        "Leave the optical path and FPGA undisturbed. The test is timed and "
        "stopped entirely in HDL. Use the 'status' stage only for occasional "
        "mailbox checks."
    )


def normal_summary(lane_mask: int) -> int:
    selected_count = sum(
        1 for lane in range(12, 16) if lane_mask & (1 << lane)
    )
    return (selected_count << 16) | (selected_count << 8) | 1


def show_status(mailbox: FpgaMailbox, sequence: int, lane_mask: int) -> None:
    overview = read_overview(mailbox)
    expect("firmware version", overview["firmware version"], FW_VERSION)
    expect("hardware version", overview["hardware version"], HW_VERSION)

    state = overview["engine state"] & 0xF
    if overview["engine state"] & PLATFORM_FAULT_BIT:
        print_platform_diagnostics(mailbox)
    if overview["response sequence"] == sequence:
        print("\nCOMPLETE: firmware has acknowledged the requested sequence.")
    elif state == STATE_RUN:
        print("\nRUNNING: the HDL engine remains in its measurement interval.")
    elif overview["hardware summary"] == normal_summary(lane_mask):
        print(
            "\nHARDWARE COMPLETE: the hardware bank is published; firmware "
            "has not yet acknowledged this request sequence."
        )
    else:
        print("\nNOT COMPLETE: inspect C8, F0, F4, F8, and FC before proceeding.")


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


def check_results(
    mailbox: FpgaMailbox,
    sequence: int,
    run_label: str = "12-hour external soak",
    lane_mask: int = MANAGED_LANE_MASK,
    diagnostic_results: bool = False,
) -> None:
    print(f"Final {run_label} state:")
    overview = read_overview(mailbox)
    expect("firmware version", overview["firmware version"], FW_VERSION)
    expect("hardware version", overview["hardware version"], HW_VERSION)
    if overview["engine state"] & PLATFORM_FAULT_BIT:
        print_platform_diagnostics(mailbox)
        fail("platform-fault result; persistent diagnostic context is above")
    expect("response sequence", overview["response sequence"], sequence)
    expected_summary = normal_summary(lane_mask)
    result_failures = []
    for name in ("response code", "hardware summary"):
        actual = overview[name]
        print(f"{name:>18} = {actual:#010x}")
        if actual != expected_summary:
            message = (
                f"{name}: expected {expected_summary:#010x}, "
                f"received {actual:#010x}"
            )
            if diagnostic_results:
                result_failures.append(message)
            else:
                fail(message)
    expect("engine state", overview["engine state"], 0)
    if overview["hardware run ID"] == 0:
        fail("hardware run ID is zero; no post-reprogram result was published")

    run_id_before = mailbox.read_u32(REG_RUN_ID)
    selected_lanes = [
        lane for lane in range(12, 16) if lane_mask & (1 << lane)
    ]
    results = {lane: read_lane(mailbox, lane) for lane in selected_lanes}
    run_id_after = mailbox.read_u32(REG_RUN_ID)
    expect("stable run ID", run_id_after, run_id_before)

    print("\nPublished lane records:")
    for lane, result in results.items():
        bits = result["tested_bits"]
        errors = result["errors"]
        error_saturated = bool(result["id_status"] & (1 << 14))
        if errors == 0 and bits:
            ber_text = "BER95<{:.3e}".format(3.0 / bits)
        elif error_saturated:
            ber_text = "measured_BER=unavailable(error_count_saturated)"
        elif bits:
            ber_text = "measured_BER={:.3e}".format(float(errors) / bits)
        else:
            ber_text = "measured_BER=unavailable(zero_tested_bits)"
        print(
            f"lane {lane}: id/status={result['id_status']:#010x}, "
            f"errors={errors}, lock_losses={result['lock_losses']}, "
            f"tested_bits={bits}, valid_cycles={result['valid_cycles']}, "
            f"{ber_text}"
        )

        lane_failures = []
        if (result["id_status"] & 0xFF) != lane:
            lane_failures.append(f"lane {lane}: result contains the wrong lane ID")
        if (result["id_status"] & ((1 << 11) | (1 << 12))) != (
            (1 << 11) | (1 << 12)
        ):
            lane_failures.append(
                f"lane {lane}: selected/locked status is not set"
            )
        if result["id_status"] & ((1 << 13) | (1 << 14) | (1 << 15)):
            lane_failures.append(
                f"lane {lane}: lock-loss or counter-saturation status is set"
            )
        if result["errors"] != 0:
            lane_failures.append(f"lane {lane}: expected zero errors")
        if result["lock_losses"] != 0:
            lane_failures.append(f"lane {lane}: expected zero lock losses")
        if bits != result["valid_cycles"] * 80:
            lane_failures.append(
                f"lane {lane}: tested-bit and valid-cycle counts disagree"
            )
        if lane_failures:
            if diagnostic_results:
                result_failures.extend(lane_failures)
            else:
                fail(lane_failures[0])

    if diagnostic_results:
        print_platform_diagnostics(mailbox)
        if result_failures:
            print(f"\n{run_label.upper()} COMPLETED WITH FAILURES:")
            for message in result_failures:
                print(f"  - {message}")
            fail("targeted diagnostic observed the failures listed above")

    print(f"\n{run_label.upper()} PASSED.")
    print("Record the final F1 AVTT current and FPGA temperature with these results.")


def parse_args(
    default_sequence: int = 2,
    default_previous_sequence: int = 1,
    default_duration_ms: int = DURATION_TWELVE_HOURS_MS,
    default_run_label: str = "12-hour external soak",
    default_lane_mask: int = MANAGED_LANE_MASK,
    description: str = None,
) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=description or __doc__)
    parser.add_argument("stage", choices=("start", "status", "results"))
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
    parser.add_argument(
        "--sequence",
        type=lambda value: int(value, 0),
        default=default_sequence,
        help=f"request sequence (default: {default_sequence})",
    )
    parser.add_argument(
        "--previous-sequence",
        type=lambda value: int(value, 0),
        default=default_previous_sequence,
        help=(
            "previous response sequence, warning only "
            f"(default: {default_previous_sequence})"
        ),
    )
    parser.add_argument(
        "--duration-ms",
        type=lambda value: int(value, 0),
        default=default_duration_ms,
        help=(
            "hardware measurement duration in milliseconds "
            f"(default: {default_duration_ms})"
        ),
    )
    parser.add_argument(
        "--run-label",
        default=default_run_label,
        help="description used in operator output",
    )
    parser.add_argument(
        "--lane-mask",
        type=lambda value: int(value, 0),
        default=default_lane_mask,
        help=(
            "global managed-lane mask (default: {:#x}; allowed bits 12-15)"
            .format(default_lane_mask)
        ),
    )
    return parser.parse_args()


def load_mailbox(args: argparse.Namespace) -> FpgaMailbox:
    if args.reg_module is None:
        package_parent = str(args.cm_interface_root.resolve().parent)
        if package_parent not in sys.path:
            sys.path.insert(0, package_parent)
        from cm_interface.registry import Registry

        registry = Registry(setup="tf", dev_path=args.device)
    else:
        registry = importlib.import_module(args.reg_module)
    return FpgaMailbox(registry.fpgas[args.fpga])


def main(
    default_sequence: int = 2,
    default_previous_sequence: int = 1,
    default_duration_ms: int = DURATION_TWELVE_HOURS_MS,
    default_run_label: str = "12-hour external soak",
    default_lane_mask: int = MANAGED_LANE_MASK,
    diagnostic_results: bool = False,
    description: str = None,
) -> int:
    args = parse_args(
        default_sequence,
        default_previous_sequence,
        default_duration_ms,
        default_run_label,
        default_lane_mask,
        description,
    )
    try:
        mailbox = load_mailbox(args)
        if args.stage == "start":
            start_soak(
                mailbox,
                args.sequence,
                args.previous_sequence,
                args.duration_ms,
                args.run_label,
                args.lane_mask,
            )
        elif args.stage == "status":
            show_status(mailbox, args.sequence, args.lane_mask)
        else:
            check_results(
                mailbox, args.sequence, args.run_label, args.lane_mask,
                diagnostic_results,
            )
    except (AttributeError, KeyError, ModuleNotFoundError, RuntimeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
