#!/usr/bin/env python3
"""Fixed v15 sequence-3 12-hour external qualification soak operator."""
import argparse
from pathlib import Path
import sys

import milestone3_12hour_external_soak as soak

VERSION = 0x0002000F
SEQUENCE = 3
PREVIOUS_SEQUENCE = 2
PREVIOUS_RUN_ID = 2
EXPECTED_RUN_ID = 3
RUN_LABEL = "v15 sequence-3 12-hour external qualification soak"


def mailbox():
    args = argparse.Namespace(cm_interface_root=Path("/home/cms/25G/cm_interface"),
        device="/dev/ttyUL4", reg_module=None, fpga="F1")
    return soak.load_mailbox(args)


def expect_preflight(box):
    overview = soak.read_overview(box)
    for name, expected in (("firmware version", VERSION), ("hardware version", VERSION),
            ("engine state", 0), ("request sequence", PREVIOUS_SEQUENCE),
            ("response sequence", PREVIOUS_SEQUENCE),
            ("response code", soak.SUMMARY_NORMAL_FOUR_LANES),
            ("hardware run ID", PREVIOUS_RUN_ID),
            ("hardware summary", soak.SUMMARY_NORMAL_FOUR_LANES)):
        soak.expect(name, overview[name], expected)


def status(box):
    overview = soak.read_overview(box)
    soak.expect("firmware version", overview["firmware version"], VERSION)
    soak.expect("hardware version", overview["hardware version"], VERSION)
    soak.expect("request sequence", overview["request sequence"], SEQUENCE)
    state = overview["engine state"] & 0xF
    if state == soak.STATE_RUN:
        soak.expect("response sequence", overview["response sequence"], PREVIOUS_SEQUENCE)
        soak.expect("hardware run ID", overview["hardware run ID"], PREVIOUS_RUN_ID)
        print("RUNNING: sequence 3 is active; published bank remains run 2.")
    elif overview["engine state"] & soak.PLATFORM_FAULT_BIT:
        soak.print_platform_diagnostics(box)
        soak.fail("v15 sequence-3 soak published a platform fault")
    elif overview["response sequence"] == SEQUENCE:
        soak.expect("hardware run ID", overview["hardware run ID"], EXPECTED_RUN_ID)
        print("COMPLETE: sequence 3 is published as run ID 3.")
    else:
        soak.fail("unexpected v15 sequence-3 soak state")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=("start", "status", "results"))
    args = parser.parse_args()
    soak.FW_VERSION = VERSION
    soak.HW_VERSION = VERSION
    try:
        box = mailbox()
        if args.stage == "start":
            expect_preflight(box)
            soak.start_soak(box, SEQUENCE, PREVIOUS_SEQUENCE,
                            soak.DURATION_TWELVE_HOURS_MS, RUN_LABEL,
                            soak.MANAGED_LANE_MASK)
            soak.expect("hardware run ID", box.read_u32(soak.REG_RUN_ID), PREVIOUS_RUN_ID)
        elif args.stage == "status":
            status(box)
        else:
            soak.check_results(box, SEQUENCE, RUN_LABEL, soak.MANAGED_LANE_MASK)
            soak.expect("hardware run ID", box.read_u32(soak.REG_RUN_ID), EXPECTED_RUN_ID)
    except (AttributeError, KeyError, ModuleNotFoundError, RuntimeError) as error:
        print("ERROR: {}".format(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
