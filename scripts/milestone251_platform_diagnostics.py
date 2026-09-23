#!/usr/bin/env python3
"""Read Milestone 2.5.1 live and persistent platform diagnostics.

This Python 3.6-compatible utility does not start, abort, acknowledge, or
clear a run. Its only write selects diagnostic result page 0xfe at 0xcc.
"""

import argparse
import sys

import milestone251_acceptance as milestone251


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    milestone251.add_connection_arguments(parser)
    args = parser.parse_args()
    try:
        mailbox = milestone251.load_mailbox(args)
        values = milestone251.overview(
            mailbox, "Milestone 2.5.1 diagnostic preface:")
        milestone251.check_version(values)
        milestone251.print_platform_diagnostics(mailbox)
        return 0
    except (AttributeError, KeyError, ModuleNotFoundError,
            OSError, milestone251.TestFailure) as error:
        print("ERROR: {}".format(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
