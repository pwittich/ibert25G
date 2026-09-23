#!/usr/bin/env python3
"""Fixed v275 sequence-3 12-hour external soak operator."""
import argparse
from pathlib import Path
import sys

import milestone3_12hour_external_soak as soak


VERSION = 0x00020119
SEQUENCE = 3
PREVIOUS_SEQUENCE = 2
PREVIOUS_RUN_ID = 2
EXPECTED_RUN_ID = 3
RUN_LABEL = "v275 sequence-3 12-hour external qualification soak"


def fixed_mailbox():
    args = argparse.Namespace(
        cm_interface_root=Path("/home/cms/25G/cm_interface"),
        device="/dev/ttyUL4", reg_module=None, fpga="F1")
    return soak.load_mailbox(args)


def exact_preflight(mailbox):
    overview = soak.read_overview(mailbox)
    for name, expected in (
            ("firmware version", VERSION), ("hardware version", VERSION),
            ("engine state", 0), ("request sequence", PREVIOUS_SEQUENCE),
            ("response sequence", PREVIOUS_SEQUENCE),
            ("response code", soak.SUMMARY_NORMAL_FOUR_LANES),
            ("hardware run ID", PREVIOUS_RUN_ID),
            ("hardware summary", soak.SUMMARY_NORMAL_FOUR_LANES)):
        soak.expect(name, overview[name], expected)


def exact_status(mailbox):
    overview = soak.read_overview(mailbox)
    soak.expect("firmware version", overview["firmware version"], VERSION)
    soak.expect("hardware version", overview["hardware version"], VERSION)
    soak.expect("request sequence", overview["request sequence"], SEQUENCE)
    state = overview["engine state"] & 0xF
    if state == soak.STATE_RUN:
        # The published-bank run ID advances only when the run completes.
        soak.expect("response sequence", overview["response sequence"],
                    PREVIOUS_SEQUENCE)
        soak.expect("hardware run ID", overview["hardware run ID"],
                    PREVIOUS_RUN_ID)
        print("\nRUNNING: sequence 3 is active; the published bank remains run 2.")
    elif overview["engine state"] & soak.PLATFORM_FAULT_BIT:
        soak.expect("response sequence", overview["response sequence"], SEQUENCE)
        soak.expect("hardware run ID", overview["hardware run ID"],
                    EXPECTED_RUN_ID)
        soak.print_platform_diagnostics(mailbox)
        soak.fail("v275 sequence-3 soak published a platform fault")
    elif overview["response sequence"] == SEQUENCE:
        soak.expect("hardware run ID", overview["hardware run ID"],
                    EXPECTED_RUN_ID)
        print("\nCOMPLETE: sequence 3 has been published as run ID 3.")
    else:
        if overview["engine state"] & soak.PLATFORM_FAULT_BIT:
            soak.print_platform_diagnostics(mailbox)
        soak.fail("unexpected v275 sequence-3 soak state")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=("start", "status", "results"))
    args = parser.parse_args()
    soak.FW_VERSION = VERSION
    soak.HW_VERSION = VERSION
    try:
        mailbox = fixed_mailbox()
        if args.stage == "start":
            exact_preflight(mailbox)
            soak.start_soak(mailbox, SEQUENCE, PREVIOUS_SEQUENCE,
                            soak.DURATION_TWELVE_HOURS_MS, RUN_LABEL,
                            soak.MANAGED_LANE_MASK)
            soak.expect("hardware run ID", mailbox.read_u32(soak.REG_RUN_ID),
                        PREVIOUS_RUN_ID)
        elif args.stage == "status":
            exact_status(mailbox)
        else:
            soak.check_results(mailbox, SEQUENCE, RUN_LABEL,
                               soak.MANAGED_LANE_MASK)
            soak.expect("hardware run ID", mailbox.read_u32(soak.REG_RUN_ID),
                        EXPECTED_RUN_ID)
    except (AttributeError, KeyError, ModuleNotFoundError, RuntimeError) as error:
        print("ERROR: {}".format(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
