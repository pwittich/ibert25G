#!/usr/bin/env python3
"""Reproduce the preserved v2.5 one-second, four-lane external smoke.

Program the validated 0x00020004 Milestone 2.5 bitstream immediately before
running this script. The script refuses non-v2.5 or non-clean sequence state.
It automatically waits for the HDL measurement and prints all four records.
"""

import argparse
import sys

import milestone25_test_common as m25


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    m25.add_connection_arguments(parser)
    args = parser.parse_args()
    try:
        mailbox = m25.load_mailbox(args)
        m25.require_clean_reprogram(mailbox)
        result = m25.run_test(
            mailbox=mailbox,
            sequence=1,
            command=m25.COMMAND_EXTERNAL_PRBS31_MS,
            duration_ms=1_000,
            lane_mask=0x0000F000,
            label="v2.5 historical one-second four-lane external smoke",
        )
        return 0 if result["passed"] else 1
    except (AttributeError, KeyError, ModuleNotFoundError, RuntimeError) as error:
        print("ERROR: {}".format(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

