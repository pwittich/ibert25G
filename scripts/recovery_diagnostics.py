#!/usr/bin/env python3
"""Decode schema-1 selector-0xFD snapshots; usable by future operator scripts.

The caller serializes selector access, selects 0xFD to capture all eight words,
then reads D0..EF using the board's semaphore/mux-safe transport. This module
does not access hardware or infer restart evidence from elapsed time.
"""
import json
import sys

SCHEMA = 0x52430001
SATURATED = 0xFFFFFFFF


def decode_integrity_state(word):
    """Decode selector-FD word 7 when capability bit 1 is present."""
    return {
        "fault": bool(word & 1),
        "error_fault_lanes": (word >> 1) & 0xF,
        "clock_fault": bool(word & (1 << 5)),
        "retained_error_lanes": (word >> 6) & 0xF,
        "retained_clock_fault": bool(word & (1 << 10)),
        "selected_lanes": (word >> 11) & 0xF,
        "monitor_enabled": bool(word & (1 << 15)),
    }


def decode(words):
    if len(words) != 8 or any(w < 0 or w > SATURATED for w in words):
        raise ValueError("expected eight unsigned 32-bit words")
    if words[0] != SCHEMA or not words[1] & 1:
        raise ValueError("restart diagnostic schema/capability unavailable")
    integrity_available = bool(words[1] & 2)
    return {
        "schema": words[0], "capabilities": words[1],
        "heartbeat_test_hook": bool(words[1] & 4),
        "requested": words[2], "completed": words[3],
        "cause": words[4] & 0xFF, "status": (words[4] >> 8) & 0xFF,
        "lanes": (words[4] >> 16) & 0xF, "accepted": words[5],
        "integrity_count": words[6] if integrity_available else None,
        "integrity_state": words[7] if integrity_available else None,
        "integrity": decode_integrity_state(words[7])
        if integrity_available else None,
    }


def require_completed_delta(before, after, expected, cause):
    """Require observed request/accept/completion deltas and last-event cause.

    Take the second snapshot before a differently caused cleanup event replaces
    the last-event fields. Counter reset/wrap/saturation is never a pass.
    """
    if expected <= 0:
        raise ValueError("expected restart delta must be positive")
    for key in ("requested", "accepted", "completed"):
        if before[key] == SATURATED or after[key] == SATURATED:
            raise RuntimeError("{} counter saturated".format(key))
        if after[key] - before[key] != expected:
            raise RuntimeError("{} restart delta mismatch".format(key))
    if after["status"] != 3 or after["cause"] != cause:
        raise RuntimeError("restart completion/cause mismatch")


if __name__ == "__main__":
    try:
        print(json.dumps(decode([int(w, 0) for w in sys.argv[1:]]),
                         indent=2, sort_keys=True))
    except (ValueError, RuntimeError) as error:
        sys.exit(str(error))
