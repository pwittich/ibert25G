#!/usr/bin/env python3
"""Run one guarded, timed bidirectional inter-FPGA PRBS31 test."""
import argparse
import os

from all_links_v2_timed_contract import (DEFAULT_DURATION_SECONDS,
                                       validate_contract, validate_duration)
from all_links_v2_timed_common import (acquire_lock, load_registry, make_boxes,
                                     run_inter_fpga)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for site in ("f1", "f2"):
        parser.add_argument("--%s-sequence" % site, type=int, required=True,
                            help="expected predecessor request/response sequence")
        parser.add_argument("--%s-run" % site, type=int, required=True,
                            help="expected predecessor published run ID")
    parser.add_argument("--acknowledge-all-firefly-tx", action="store_true",
                        help="acknowledge that v2 TX sessions drive all FireFly TX lanes")
    parser.add_argument("--duration-seconds", type=int,
                        default=DEFAULT_DURATION_SECONDS,
                        help="measurement duration in seconds (default: 90)")
    args = parser.parse_args()
    validate_contract(require_release=True)
    validate_duration(args.duration_seconds)
    if not args.acknowledge_all_firefly_tx:
        raise RuntimeError("--acknowledge-all-firefly-tx is required")
    lock = acquire_lock()
    try:
        registry = load_registry()
        run_inter_fpga(registry, make_boxes(registry), {
            "F1": (args.f1_sequence, args.f1_run),
            "F2": (args.f2_sequence, args.f2_run)}, args.duration_seconds)
    finally:
        os.close(lock)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
