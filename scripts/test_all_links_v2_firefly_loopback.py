#!/usr/bin/env python3
"""Run one guarded, timed FireFly external-loopback PRBS31 test."""
import argparse
import os

from all_links_v2_timed_contract import (DEFAULT_DURATION_SECONDS,
                                       validate_contract, validate_duration)
from all_links_v2_timed_common import (acquire_lock, load_registry, make_boxes,
                                     parse_quads, run_firefly)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("quads", help="q121, q121-q124, or comma-separated selections")
    for site in ("f1", "f2"):
        parser.add_argument("--%s-sequence" % site, type=int, required=True,
                            help="expected predecessor request/response sequence")
        parser.add_argument("--%s-run" % site, type=int, required=True,
                            help="expected predecessor published run ID")
    parser.add_argument("--acknowledge-all-managed-tx", action="store_true",
                        help="acknowledge that v2 sessions drive all 112 TX lanes")
    parser.add_argument("--duration-seconds", type=int,
                        default=DEFAULT_DURATION_SECONDS,
                        help="measurement duration in seconds (default: 90)")
    args = parser.parse_args()
    quads = parse_quads(args.quads)
    validate_contract(require_release=True)
    validate_duration(args.duration_seconds)
    if not args.acknowledge_all_managed_tx:
        raise RuntimeError("--acknowledge-all-managed-tx is required")
    lock = acquire_lock()
    try:
        registry = load_registry()
        run_firefly(registry, make_boxes(registry), quads, {
            "F1": (args.f1_sequence, args.f1_run),
            "F2": (args.f2_sequence, args.f2_run)}, args.duration_seconds)
    finally:
        os.close(lock)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
