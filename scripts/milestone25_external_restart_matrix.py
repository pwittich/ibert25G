#!/usr/bin/env python3
"""Run the v2.5 external restart and PMA-recovery comparison matrix.

Program the preserved 0x00020004 Milestone 2.5 bitstream immediately before
running this script. Do not first run the historical-smoke script: this matrix
requires clean request, response, and run-ID state and performs all six jobs
itself. Expected BER failures are recorded without stopping later comparison
jobs; transport, version, engine-state, or platform faults stop the script.
"""

import argparse
import sys

import milestone25_test_common as m25


TESTS = (
    (1, m25.COMMAND_EXTERNAL_PRBS31_MS, 10_000, 0x00001000,
     "v2.5 lane-12 external first run"),
    (2, m25.COMMAND_EXTERNAL_PRBS31_MS, 10_000, 0x00001000,
     "v2.5 lane-12 external repeat"),
    (3, m25.COMMAND_EXTERNAL_PRBS31_MS, 10_000, 0x00002000,
     "v2.5 lane-13 external after shared-quad runs"),
    (4, m25.COMMAND_PMA_PRBS31_MS, 10_000, 0x0000F000,
     "v2.5 four-lane near-end PMA recovery"),
    (5, m25.COMMAND_EXTERNAL_PRBS31_MS, 10_000, 0x00001000,
     "v2.5 lane-12 external after PMA recovery"),
    (6, m25.COMMAND_EXTERNAL_PRBS31_MS, 10_000, 0x00001000,
     "v2.5 lane-12 external repeat after PMA recovery"),
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    m25.add_connection_arguments(parser)
    args = parser.parse_args()
    try:
        mailbox = m25.load_mailbox(args)
        m25.require_clean_reprogram(mailbox)
        results = []
        for sequence, command, duration_ms, lane_mask, label in TESTS:
            results.append(
                m25.run_test(
                    mailbox, sequence, command, duration_ms, lane_mask, label
                )
            )

        print("\nV2.5 RESTART/RECOVERY MATRIX SUMMARY:")
        for result in results:
            print(
                "  sequence {}: {:4s} - {}".format(
                    result["sequence"],
                    "PASS" if result["passed"] else "FAIL",
                    result["label"],
                )
            )
        print(
            "\nAll six observations were retained. A failing comparison job "
            "does not make this diagnostic script itself incomplete."
        )
        return 0
    except (AttributeError, KeyError, ModuleNotFoundError, RuntimeError) as error:
        print("ERROR: {}".format(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

