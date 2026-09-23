#!/usr/bin/env python3
"""Fixed fresh FireFly-1 v2 lanes-0--11 PMA-loopback test on F1."""
import argparse
import sys
import time
from pathlib import Path


parser = argparse.ArgumentParser()
parser.add_argument("stage", choices=("start", "status", "results", "diagnostics"))
parser.add_argument("--cm-interface-root", type=Path, required=True)
args = parser.parse_args()
sys.path.insert(0, str(args.cm_interface_root.parent))

from cm_interface.registry import Registry
from milestone3_12hour_external_soak import (FpgaMailbox, print_platform_diagnostics,
                                             read_lane, read_overview)

VERSION = 0x00020301
SEQUENCE = 1
DURATION_MS = 10000
MANAGED_MASK = 0x00000fff
REQUEST_WORD = 0x00011501

mailbox = FpgaMailbox(Registry(setup="tf", dev_path="/dev/ttyUL4").fpgas["F1"])


def read(address):
    return mailbox.read_u32(address)


def write(address, value):
    mailbox.write_u32(address, value)
    if read(address) != value:
        raise RuntimeError("write verification failed at %#x" % address)


def identity():
    if read(0xc0) != VERSION or read(0xc4) != VERSION:
        raise RuntimeError("FireFly-1 v2 version mismatch")


def start():
    # One fresh request only: do not reset, retry, or change duration/mask.
    if read(0xc8) != 0 or read(0xa0) != 0:
        raise RuntimeError("not fresh IDLE at sequence 0")
    for address, value in ((0xa4, REQUEST_WORD), (0xa8, DURATION_MS),
                           (0xac, 0), (0xb0, MANAGED_MASK), (0xb4, 0),
                           (0xb8, 0), (0xbc, 0)):
        write(address, value)
    write(0xa0, SEQUENCE)
    for unused in range(200):
        if read(0xc8) & 15 == 2:
            print("FIREFLY1_V2_RUN")
            return
        time.sleep(0.05)
    raise RuntimeError("RUN timeout")


def report(diagnostics=False):
    if diagnostics:
        print("Read-only FireFly-1 v2 failure diagnostic; no request, reset, or stimulus.")
        read_overview(mailbox)
        print_platform_diagnostics(mailbox)
        print("\nPublished lane records (0--11):")
        for lane in range(12):
            result = read_lane(mailbox, lane)
            print("lane %d: id/status=%#010x errors=%d tested_bits=%d "
                  "lock_losses=%d valid_cycles=%d" %
                  (lane, result["id_status"], result["errors"],
                   result["tested_bits"], result["lock_losses"],
                   result["valid_cycles"]))
        return

    print("state=%#x request=%#x response=%#x code=%#x run=%#x summary=%#x" %
          (read(0xc8), read(0xa0), read(0xf0), read(0xf4), read(0xf8), read(0xfc)))
    # Preserve the existing diagnostic ABI; selector writes are intentional.
    write(0xcc, 0xfe)
    print("platform_diag=" + " ".join("%08x" % read(0xd0 + 4 * index)
                                       for index in range(8)))


identity()
if args.stage == "start":
    start()
else:
    report(args.stage == "diagnostics")
