#!/usr/bin/env python3
"""Read-only status, clock, power, and temperature report for v2 tests."""
import os

from all_links_v2_timed_contract import validate_contract
from all_links_v2_timed_common import (acquire_lock, load_registry, make_boxes,
                                     print_status)


def main():
    validate_contract(require_release=True)
    lock = acquire_lock()
    try:
        registry = load_registry()
        print_status(registry, make_boxes(registry))
    finally:
        os.close(lock)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
