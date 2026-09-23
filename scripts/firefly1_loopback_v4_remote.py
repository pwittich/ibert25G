#!/usr/bin/env python3
"""Fixed fresh FireFly-1 v4 lanes-0--11 PMA-loopback test on F1."""
import argparse
import sys
import time
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("stage", choices=("start", "status", "results", "diagnostics"))
parser.add_argument("--cm-interface-root", type=Path, required=True)
parser.add_argument("--fpga", choices=("F1", "F2"), default="F1")
args = parser.parse_args()
sys.path.insert(0, str(args.cm_interface_root.parent))

from cm_interface.registry import Registry
from milestone3_12hour_external_soak import (FpgaMailbox, print_platform_diagnostics,
                                             read_lane, read_overview)

VERSION = 0x00020303
SEQUENCE = 1
DURATION_MS = 10000
MANAGED_MASK = 0x00000fff
REQUEST_WORD = 0x00011501
mailbox = FpgaMailbox(Registry(setup="tf", dev_path="/dev/ttyUL4").fpgas[args.fpga])
print("FIREFLY1_V4_SITE " + args.fpga, flush=True)

def read(address):
    return mailbox.read_u32(address)

def write(address, value):
    mailbox.write_u32(address, value)
    if read(address) != value:
        raise RuntimeError("write verification failed at %#x" % address)

def identity():
    if read(0xc0) != VERSION or read(0xc4) != VERSION:
        raise RuntimeError("FireFly-1 v4 version mismatch")

def start():
    # One fresh request only: do not reset, retry, or change duration/mask.
    if read(0xc8) != 0 or read(0xa0) != 0:
        raise RuntimeError("not fresh IDLE at sequence 0")
    for address, value in ((0xa4, REQUEST_WORD), (0xa8, DURATION_MS),
                           (0xac, 0), (0xb0, MANAGED_MASK), (0xb4, 0),
                           (0xb8, 0), (0xbc, 0)):
        write(address, value)
    write(0xa0, SEQUENCE)
    for unused in range(400):
        state = read(0xc8)
        if state & 0x10000:
            report(True)
            raise RuntimeError("platform fault before RUN; request consumed")
        if state & 15 == 2:
            print("FIREFLY1_V4_RUN")
            return
        time.sleep(0.05)
    raise RuntimeError("RUN timeout")

def report(diagnostics=False):
    if diagnostics:
        print("Read-only FireFly-1 v4 failure diagnostic; no request, reset, or stimulus.")
        read_overview(mailbox)
        print_platform_diagnostics(mailbox)
        print("\nPublished lane records (0--11):")
        for lane in range(12):
            result = read_lane(mailbox, lane)
            print("lane %d: id/status=%#010x errors=%d tested_bits=%d lock_losses=%d valid_cycles=%d" %
                  (lane, result["id_status"], result["errors"], result["tested_bits"],
                   result["lock_losses"], result["valid_cycles"]))
        return
    print("state=%#x request=%#x response=%#x code=%#x run=%#x summary=%#x" %
          (read(0xc8), read(0xa0), read(0xf0), read(0xf4), read(0xf8), read(0xfc)))
    # Preserve the diagnostic ABI; selector writes are intentional.
    write(0xcc, 0xfe)
    print("platform_diag=" + " ".join("%08x" % read(0xd0 + 4 * index)
                                       for index in range(8)))

identity()
if args.stage == "start":
    start()
elif args.stage == "results":
    # C8 reports engine IDLE, not all three controllers' cleanup completion.
    # Observe beyond their fixed 10-second operation timeout before accepting
    # a clean result. Retained faults terminate the observation immediately.
    for unused in range(120):
        if read(0xc8) & 0x10000:
            break
        time.sleep(0.1)
    report(True)
    if any(read(address) != value for address, value in
           ((0xf0, 1), (0xf8, 1), (0xf4, 0x000c0c01), (0xfc, 0x000c0c01))):
        raise RuntimeError("v4 hardware gate failed: sequence/run/summary mismatch")
    for lane in range(12):
        result = read_lane(mailbox, lane)
        if result["errors"] or result["lock_losses"] or not result["tested_bits"] or not result["valid_cycles"]:
            raise RuntimeError("v4 hardware gate failed: lane %d" % lane)
    # Allow bounded post-capture cleanup, but require final healthy IDLE.
    for unused in range(400):
        final_state = read(0xc8)
        if final_state & 0x10000:
            raise RuntimeError("v4 hardware gate failed: retained platform fault after measurement")
        if final_state == 0:
            write(0xcc, 0xfe)
            platform = read(0xd0)
            prbs = read(0xd4)
            if not (platform & 0x40) or platform & 0xff80 or not (prbs & 0x40000000) or prbs & 0x8000001f:
                raise RuntimeError("v4 hardware gate failed: final platform/controller readiness")
            print("PASS: FIREFLY1_V4 twelve clean lanes and healthy IDLE")
            break
        time.sleep(0.05)
    else:
        raise RuntimeError("v4 hardware gate failed: final state is not healthy IDLE")
else:
    report(args.stage == "diagnostics")
