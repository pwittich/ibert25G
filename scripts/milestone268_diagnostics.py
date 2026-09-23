#!/usr/bin/env python3
"""Dump v268 raw evidence before interpreting it. No run submission or retries."""
import argparse
import json
import time
from pathlib import Path

import milestone3_12hour_external_soak as test
import recovery_diagnostics
import transition_diagnostics

VERSION = 0x00020112


def page(mailbox, selector, bank=0):
    selection = selector | (bank << 8)
    if bank:
        mailbox.write_u32(test.REG_RESULT_LANE, selection)
    else:
        mailbox.write_u8(test.REG_RESULT_LANE, selector)
    if mailbox.read_u32(test.REG_RESULT_LANE) != selection:
        raise RuntimeError("diagnostic selector readback mismatch")
    return [mailbox.read_u32(0xd0 + 4 * n) for n in range(8)]


def capture(mailbox, result=None):
    if result is None:
        result = {}
    result.update(timestamp=time.time(), overview=test.read_overview(mailbox))
    for key in ("firmware version", "hardware version"):
        if result["overview"][key] != VERSION:
            raise RuntimeError("v268 diagnostic script requires matching FW/HW")
    result["metadata_before"] = page(mailbox, 0xfc)
    result["recovery"] = page(mailbox, 0xfd)
    result["platform"] = page(mailbox, 0xfe)
    result["lanes"] = {}
    for n in range(12, 16):
        result["lanes"][str(n)] = page(mailbox, n)
    result["profiles"] = {}
    for n in range(4):
        result["profiles"][str(n + 12)] = page(mailbox, 0xf8 + n)
    result["slots"] = []
    capacity = transition_diagnostics.metadata(result["metadata_before"])["capacity"]
    for n in range(capacity):
        result["slots"].append(page(mailbox, 0x80 + n % 64, n // 64))
    result["metadata_after"] = page(mailbox, 0xfc)
    result["overview_after"] = test.read_overview(mailbox)
    result["lanes_after"] = {str(n): page(mailbox, n) for n in range(12, 16)}
    return result


def decode(result):
    if result["metadata_before"] != result["metadata_after"]:
        raise RuntimeError("trace changed during readout")
    if result["overview"] != result["overview_after"]:
        raise RuntimeError("mailbox changed during readout")
    if result["lanes"] != result["lanes_after"]:
        raise RuntimeError("lane records changed during readout")
    meta = transition_diagnostics.metadata(result["metadata_before"])
    return dict(metadata=meta, trace=transition_diagnostics.chronological(meta, result["slots"]),
                recovery=recovery_diagnostics.decode(result["recovery"]),
                profiles={n: transition_diagnostics.profile(w)
                          for n, w in result["profiles"].items()})


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--cm-interface-root", type=Path, default=Path("/home/cms/25G/cm_interface"))
    p.add_argument("--device", default="/dev/ttyUL4")
    p.add_argument("--fpga", choices=("F1",), default="F1")
    p.add_argument("--reg-module", default=None)
    args = p.parse_args()
    # Exclusive creation prevents replacing earlier evidence. Raw data is
    # persisted before decoder/validator failures can terminate the command.
    with args.output.open("x") as output:
        raw = {}
        try:
            capture(test.load_mailbox(args), raw)
        finally:
            json.dump(raw, output, indent=2, sort_keys=True)
            output.flush()
    print(json.dumps(decode(raw), indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
