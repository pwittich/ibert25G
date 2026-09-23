#!/usr/bin/env python3
"""Deploy or launch a guarded all-links-v2 timed FireFly-loopback test."""
import argparse

from all_links_v2_timed_contract import (DEFAULT_DURATION_SECONDS,
                                       validate_duration)
from board_all_links_v2_timed_common import deploy, run_remote, status


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=("deploy", "status", "run"))
    parser.add_argument("quads", nargs="?",
                        help="q121, q121-q124, or comma-separated selections")
    for site in ("f1", "f2"):
        parser.add_argument("--%s-sequence" % site, type=int)
        parser.add_argument("--%s-run" % site, type=int)
    parser.add_argument("--acknowledge-all-managed-tx", action="store_true")
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
    values = (args.quads, args.f1_sequence, args.f1_run,
              args.f2_sequence, args.f2_run)
    if any(value is None for value in values):
        parser.error("run requires quads and both sites' --sequence/--run values")
    if not args.acknowledge_all_managed_tx:
        parser.error("run requires --acknowledge-all-managed-tx")
    try:
        validate_duration(args.duration_seconds)
    except ValueError as error:
        parser.error(str(error))
    arguments = [args.quads,
                 "--f1-sequence", str(args.f1_sequence),
                 "--f1-run", str(args.f1_run),
                 "--f2-sequence", str(args.f2_sequence),
                 "--f2-run", str(args.f2_run),
                 "--duration-seconds", str(args.duration_seconds),
                 "--acknowledge-all-managed-tx"]
    run_remote("test_all_links_v2_firefly_loopback.py", arguments,
               "firefly-%s-%ds" %
               (args.quads.replace(",", "_"), args.duration_seconds))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
