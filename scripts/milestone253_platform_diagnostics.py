#!/usr/bin/env python3
"""Read retained Milestone 2.5.3 fixed-acquisition diagnostic evidence."""

import argparse
import sys

import milestone251_acceptance as common
import milestone252_acceptance as fixed
import milestone253_acceptance as milestone253


def main():
    fixed.DIAGNOSTIC_LABEL = "2.5.3"
    parser = argparse.ArgumentParser(description=__doc__)
    common.add_connection_arguments(parser)
    args = parser.parse_args()
    try:
        mailbox = common.load_mailbox(args)
        values = common.overview(
            mailbox, "Milestone 2.5.3 diagnostic preface:")
        for name in ("firmware version", "hardware version"):
            if values[name] != milestone253.VERSION:
                raise common.TestFailure(
                    "{}: expected {:#010x}, got {:#010x}".format(
                        name, milestone253.VERSION, values[name]))
        fixed.print_qualification_diagnostics(mailbox)
        return 0
    except (AttributeError, KeyError, ModuleNotFoundError,
            OSError, common.TestFailure) as error:
        print("ERROR: {}".format(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
