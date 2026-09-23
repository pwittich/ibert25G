#!/usr/bin/env python3
"""Run the Milestone 2.5.2 fixed staged-acquisition acceptance matrix.

Program the 0x00020102 image immediately before running this script. This
candidate measures even when its fixed one-millisecond acquisition-observation
window contains errors or unlocks, and prints that evidence after every job.
"""

import milestone251_acceptance as common


VERSION = 0x00020102
DIAGNOSTIC_LABEL = "2.5.2"

TESTS = (
    (1, common.COMMAND_EXTERNAL_PRBS31_MS, 10000, 0x00001000,
     "2.5.2 lane-12 external first run"),
    (2, common.COMMAND_EXTERNAL_PRBS31_MS, 10000, 0x00001000,
     "2.5.2 lane-12 external repeat"),
    (3, common.COMMAND_EXTERNAL_PRBS31_MS, 10000, 0x0000F000,
     "2.5.2 four-lane external run"),
    (4, common.COMMAND_PMA_PRBS31_MS, 10000, 0x0000F000,
     "2.5.2 four-lane near-end PMA run"),
    (5, common.COMMAND_EXTERNAL_PRBS31_MS, 10000, 0x00001000,
     "2.5.2 lane-12 external after PMA"),
)


def print_qualification_diagnostics(mailbox):
    values = common.read_diagnostic_page(mailbox)
    word = values["live_rx"]
    if not (word & 1):
        raise common.TestFailure(
            "{} qualification diagnostic format marker is absent".format(
                DIAGNOSTIC_LABEL))
    maximum_clean = common.bits(word, 6, 18)
    print("\n{} fixed acquisition observation:".format(DIAGNOSTIC_LABEL))
    print("  sampled-error lanes = {:#x}".format(common.bits(word, 28, 4)))
    print("  sampled-unlock lanes= {:#x}".format(common.bits(word, 24, 4)))
    print("  maximum clean streak= {} cycles ({:.3f} us)".format(
        maximum_clean, float(maximum_clean) / 200.0))
    print("  live selected error = {}".format(bool(word & (1 << 5))))
    print("  live selected locked= {}".format(bool(word & (1 << 4))))
    print("  Wizard RX done      = {}".format(bool(word & (1 << 3))))
    print("  selected RX done    = {}".format(bool(word & (1 << 2))))
    print("  selected PMA done   = {}".format(bool(word & (1 << 1))))
    return values


def main():
    common.VERSION = VERSION
    common.CANDIDATE_LABEL = "2.5.2"
    common.TESTS = TESTS
    common.POST_RUN_DIAGNOSTIC = print_qualification_diagnostics
    common.print_platform_diagnostics = print_qualification_diagnostics
    common.__doc__ = __doc__
    return common.main()


if __name__ == "__main__":
    raise SystemExit(main())
