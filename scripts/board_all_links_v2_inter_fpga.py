#!/usr/bin/env python3
"""Deploy or launch the guarded all-links-v2 timed inter-FPGA test."""
import argparse

from all_links_v2_timed_contract import (DEFAULT_DURATION_SECONDS,
                                       validate_duration)
from board_all_links_v2_timed_common import deploy, results, run_remote, status


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=("deploy", "status", "results",
                                          "run"))
    for site in ("f1", "f2"):
        parser.add_argument("--%s-sequence" % site, type=int)
        parser.add_argument("--%s-run" % site, type=int)
    parser.add_argument("--acknowledge-all-firefly-tx", action="store_true")
    parser.add_argument("--duration-seconds", type=int,
                        default=DEFAULT_DURATION_SECONDS,
                        help="measurement duration in seconds (default: 90)")
    args = parser.parse_args()
    if args.stage == "deploy":
        deploy()
        return 0
    if args.stage == "status":
        status()
        return 0
    if args.stage == "results":
        results()
        return 0
    values = (args.f1_sequence, args.f1_run, args.f2_sequence, args.f2_run)
    if any(value is None for value in values):
        parser.error("run requires both sites' --sequence and --run values")
    if not args.acknowledge_all_firefly_tx:
        parser.error("run requires --acknowledge-all-firefly-tx")
    try:
        validate_duration(args.duration_seconds)
    except ValueError as error:
        parser.error(str(error))
    arguments = ["--f1-sequence", str(args.f1_sequence),
                 "--f1-run", str(args.f1_run),
                 "--f2-sequence", str(args.f2_sequence),
                 "--f2-run", str(args.f2_run),
                 "--duration-seconds", str(args.duration_seconds),
                 "--acknowledge-all-firefly-tx"]
    run_remote("test_all_links_v2_inter_fpga.py", arguments,
               "inter-fpga-%ds" % args.duration_seconds)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
