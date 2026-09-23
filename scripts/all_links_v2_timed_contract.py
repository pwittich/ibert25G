#!/usr/bin/env python3
"""Frozen contract shared by the released all-links-v2 timed tests."""

RELEASED = True
VERSION = 0x00020501
DEFAULT_DURATION_SECONDS = 90
MAX_DURATION_SECONDS = 86340  # Leave 60 s below the firmware's 24 h limit.
RXUSRCLK_HZ = 322265625
CAPABILITY = 1 << 20
SESSION_ACTIVE = 1 << 17
SESSION_READY = 1 << 21

BIT_SHA256 = "163172d938f5aa87fd606061e75e058f5d7040916d86d4744a206309f970b66f"
DCP_SHA256 = "323ff58252ae66a81e42c84d38b528ce053561804cdc7eeecb99d3066107993a"
ELF_SHA256 = "d947fd47e684a1e0be08296d34b4de1b1e28d7c056ecabffcbfb681786730f9c"

REFCLK_ADDRESSES = (0x2c, 0x30, 0x38, 0x3c, 0x40, 0x44,
                     0x48, 0x4c, 0x50, 0x54, 0x58, 0x5c)
ALL_MASK = (0xffffffff, 0xffffffff, 0xffffffff, 0x0000ffff)

# The two unpopulated direct receivers are different at the two endpoints.
# These masks cover the 54 fitted receive lanes at each endpoint.
DIRECT_MASKS = {
    "F1": (0, 0xff000000, 0xffffff3f, 0x0000ffff),  # omit 70,71
    "F2": (0, 0xff000000, 0xffffffff, 0x0000fffc),  # omit 96,97
}

FIREFLY_QUADS = tuple(range(121, 135))


def mask_lanes(words):
    return tuple(lane for lane in range(112)
                 if words[lane // 32] & (1 << (lane % 32)))


def validate_duration(seconds):
    if not isinstance(seconds, int) or isinstance(seconds, bool):
        raise ValueError("duration must be an integer number of seconds")
    if not 1 <= seconds <= MAX_DURATION_SECONDS:
        raise ValueError("duration must be between 1 and %d seconds" %
                         MAX_DURATION_SECONDS)
    return seconds * 1000


def expected_cycles(duration_ms):
    return RXUSRCLK_HZ * duration_ms // 1000


def validate_contract(require_release=True):
    if require_release and not RELEASED:
        raise RuntimeError("all-links-v2 timed hardware tests are UNRELEASED")
    if VERSION != 0x00020501 or DEFAULT_DURATION_SECONDS != 90:
        raise RuntimeError("identity or default duration changed")
    if validate_duration(DEFAULT_DURATION_SECONDS) != 90000 or \
            expected_cycles(90000) != 29003906250:
        raise RuntimeError("default-duration cycle contract changed")
    if len(mask_lanes(DIRECT_MASKS["F1"])) != 54 or len(mask_lanes(DIRECT_MASKS["F2"])) != 54:
        raise RuntimeError("direct fitted-lane masks changed")
    if FIREFLY_QUADS != tuple(range(121, 135)):
        raise RuntimeError("FireFly quad range changed")
    for value in (BIT_SHA256, DCP_SHA256, ELF_SHA256):
        if len(value) != 64 or any(ch not in "0123456789abcdef" for ch in value):
            raise RuntimeError("artifact SHA-256 pin is incomplete")
    return True
