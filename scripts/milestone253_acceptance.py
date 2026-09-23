#!/usr/bin/env python3
"""Run the Milestone 2.5.3 retained-diagnostic hardware check.

Program the 0x00020103 image immediately before running this script. It runs
one ten-second lane-12 external test and requires a retained nonzero maximum
clean streak after completion.
"""

import milestone251_acceptance as common
import milestone252_acceptance as fixed


VERSION = 0x00020103

TESTS = (
    (1, common.COMMAND_EXTERNAL_PRBS31_MS, 10000, 0x00001000,
     "2.5.3 lane-12 retained-diagnostic check"),
)


def print_and_check_qualification_diagnostics(mailbox):
    values = fixed.print_qualification_diagnostics(mailbox)
    maximum_clean = common.bits(values["live_rx"], 6, 18)
    if maximum_clean == 0:
        raise common.TestFailure(
            "retained maximum clean streak is zero after completion")
    return values


def main():
    fixed.DIAGNOSTIC_LABEL = "2.5.3"
    common.VERSION = VERSION
    common.CANDIDATE_LABEL = "2.5.3"
    common.TESTS = TESTS
    common.POST_RUN_DIAGNOSTIC = print_and_check_qualification_diagnostics
    common.print_platform_diagnostics = fixed.print_qualification_diagnostics
    common.__doc__ = __doc__
    return common.main()


if __name__ == "__main__":
    raise SystemExit(main())
