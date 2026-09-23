#!/usr/bin/env python3
"""Read-only preserved-result dump for all-links-v2 direct-link gates."""
import os

from all_links_v2_timed_common import acquire_lock, load_registry, make_boxes
from all_links_v2_timed_contract import DIRECT_MASKS, mask_lanes, validate_contract
from milestone3_12hour_external_soak import (print_platform_diagnostics,
                                             read_lane)


def main():
    validate_contract(require_release=True)
    lock = acquire_lock()
    try:
        boxes = make_boxes(load_registry())
        for site in ("F1", "F2"):
            box = boxes[site]
            print("RESULT_STATUS site=%s state=%#010x request=%d response=%d "
                  "code=%#010x run=%d summary=%#010x" %
                  (site, box.read_u32(0xc8), box.read_u32(0xa0),
                   box.read_u32(0xf0), box.read_u32(0xf4),
                   box.read_u32(0xf8), box.read_u32(0xfc)), flush=True)
            print_platform_diagnostics(box)
            for lane in mask_lanes(DIRECT_MASKS[site]):
                print("RESULT_RECORD site=%s lane=%d data=%r" %
                      (site, lane, read_lane(box, lane)), flush=True)
    finally:
        os.close(lock)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
