#!/usr/bin/env python3
"""Dump the currently published Milestone 3 result without validating it.

This Python 3.6-compatible diagnostic is intentionally read-mostly: it does
not start, abort, acknowledge, or clear a run.  Its only write selects each
published lane record through register 0xCC.

  python3 scripts/milestone3_dump_results.py
"""

import argparse
from pathlib import Path
import sys

import milestone3_12hour_external_soak as external_test


STOP_REASONS = {
    0: "not published/unknown",
    1: "normal duration",
    2: "operator abort",
    3: "automatic timeout",
    4: "platform fault",
}


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
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
    return parser.parse_args()


def yes_no(value):
    return "yes" if value else "no"


def main():
    args = parse_args()
    try:
        mailbox = external_test.load_mailbox(args)

        print("Published mailbox overview:")
        overview = external_test.read_overview(mailbox)
        if overview["engine state"] & external_test.PLATFORM_FAULT_BIT:
            external_test.print_platform_diagnostics(mailbox)
        summary = overview["hardware summary"]
        failed = (summary >> 24) & 0xFF
        passed = (summary >> 16) & 0xFF
        selected = (summary >> 8) & 0xFF
        stop_reason = summary & 0xFF
        print("\nDecoded hardware summary:")
        print("  failed lanes = {}".format(failed))
        print("  passed lanes = {}".format(passed))
        print("selected lanes = {}".format(selected))
        print(
            "   stop reason = {} ({})".format(
                stop_reason,
                STOP_REASONS.get(stop_reason, "unrecognized"),
            )
        )

        run_id_before = mailbox.read_u32(external_test.REG_RUN_ID)
        results = {
            lane: external_test.read_lane(mailbox, lane)
            for lane in range(12, 16)
        }
        run_id_after = mailbox.read_u32(external_test.REG_RUN_ID)

        print("\nPublished lane records:")
        for lane, result in results.items():
            status = result["id_status"]
            record_lane = status & 0xFF
            selected_flag = bool(status & (1 << 11))
            locked = bool(status & (1 << 12))
            lock_loss_flag = bool(status & (1 << 13))
            error_saturated = bool(status & (1 << 14))
            bit_count_saturated = bool(status & (1 << 15))
            passed_flag = (
                selected_flag
                and locked
                and not lock_loss_flag
                and result["errors"] == 0
            )
            bits = result["tested_bits"]
            ber95 = 3.0 / bits if bits else float("inf")

            print("\nlane {}: {}".format(lane, "PASS" if passed_flag else "FAIL"))
            print("       id/status = {:#010x}".format(status))
            print("       record lane = {}".format(record_lane))
            print("          selected = {}".format(yes_no(selected_flag)))
            print("    locked at stop = {}".format(yes_no(locked)))
            print("    lock-loss flag = {}".format(yes_no(lock_loss_flag)))
            print("   error saturated = {}".format(yes_no(error_saturated)))
            print("bit-count saturated = {}".format(yes_no(bit_count_saturated)))
            print("            errors = {}".format(result["errors"]))
            print("       lock losses = {}".format(result["lock_losses"]))
            print("       tested bits = {}".format(bits))
            print("      valid cycles = {}".format(result["valid_cycles"]))
            if result["errors"] == 0:
                print("             BER95 < {:.3e}".format(ber95))
            elif error_saturated:
                print("      measured BER = unavailable (error count saturated)")
            elif bits:
                measured_ber = float(result["errors"]) / bits
                print("      measured BER = {:.3e}".format(measured_ber))
            else:
                print("      measured BER = unavailable (zero tested bits)")

        if run_id_after != run_id_before:
            print(
                "\nWARNING: hardware run ID changed from {:#010x} to "
                "{:#010x} while lane records were being read; rerun the dump "
                "for an internally consistent snapshot.".format(
                    run_id_before, run_id_after
                ),
                file=sys.stderr,
            )
            return 2

        print("\nStable hardware run ID: {:#010x}".format(run_id_after))
        return 0
    except (AttributeError, KeyError, ModuleNotFoundError, RuntimeError) as error:
        print("ERROR: {}".format(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
