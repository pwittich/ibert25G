#!/usr/bin/env python3
"""Run one clean isolated 2.5.7 four-lane external acceptance request."""

import argparse
from pathlib import Path
import sys

import milestone3_12hour_external_soak as test


VERSION = 0x00020107
CANDIDATE_LABEL = "2.5.7"


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=("start", "status", "results"))
    parser.add_argument("--sequence", type=lambda value: int(value, 0),
                        required=True)
    parser.add_argument("--previous-sequence",
                        type=lambda value: int(value, 0), required=True)
    parser.add_argument("--expected-run-id",
                        type=lambda value: int(value, 0), required=True)
    parser.add_argument("--duration-ms", type=lambda value: int(value, 0),
                        default=10000)
    parser.add_argument("--cm-interface-root", type=Path,
                        default=Path("/home/cms/25G/cm_interface"))
    parser.add_argument("--device", default="/dev/ttyUL4")
    parser.add_argument("--reg-module", default=None)
    parser.add_argument("--fpga", default="F1")
    return parser.parse_args()


def main():
    args = parse_args()
    test.FW_VERSION = VERSION
    test.HW_VERSION = VERSION
    mailbox = test.load_mailbox(args)
    label = "{} four-lane external acceptance sequence {}".format(
        CANDIDATE_LABEL, args.sequence)
    if args.stage == "start":
        run_id = mailbox.read_u32(test.REG_RUN_ID)
        test.expect("preflight run ID", run_id, args.expected_run_id - 1)
        test.start_soak(mailbox, args.sequence, args.previous_sequence,
                        args.duration_ms, label, test.MANAGED_LANE_MASK)
    elif args.stage == "status":
        test.show_status(mailbox, args.sequence, test.MANAGED_LANE_MASK)
    else:
        test.check_results(mailbox, args.sequence, label,
                           test.MANAGED_LANE_MASK)
        test.expect("completed run ID", mailbox.read_u32(test.REG_RUN_ID),
                    args.expected_run_id)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AttributeError, KeyError, ModuleNotFoundError, RuntimeError) as error:
        print("ERROR: {}".format(error), file=sys.stderr)
        raise SystemExit(1)
