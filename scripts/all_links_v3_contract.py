"""Versioned bench contract. Release requires an independent routed audit."""
import re

VERSION = 0x00020502
RELEASED = False
BIT_SHA256 = '60c8311daabf487184672bf987773fbb6fd808bb7e070fde4588854e40d40ed1'
DCP_SHA256 = 'ca56c79ccc90b5cf67e6d85d982238b2c3d03997b79fe45d7eccd100354fb684'
ELF_SHA256 = 'c8b1e6c53d9649c0fda090384944d1b9165607c58fe95d1c66065a1db9753911'
CM_COMMIT = "64260cf23b01c9da987feda1fbf51567240c2c71"
QUADS = tuple(range(121, 135)) + tuple(range(221, 235))
UNFITTED = {"F1": (70, 71), "F2": (96, 97)}


def quad_mask(spec):
    if spec.lower() == "all":
        return (1 << 28) - 1
    if spec.lower() == "none":
        return 0
    result = 0
    for item in spec.lower().split(","):
        match = re.fullmatch(r"\s*q?(\d{3})(?:-q?(\d{3}))?\s*", item)
        if not match:
            raise ValueError("invalid quad selector: " + item)
        first = int(match.group(1))
        last = int(match.group(2) or first)
        if first > last or first not in QUADS or last not in QUADS or first // 100 != last // 100:
            raise ValueError("ranges must stay within q121-q134 or q221-q234")
        for quad in range(first, last + 1):
            result |= 1 << QUADS.index(quad)
    return result


def receive_words(site, mask):
    words = [0, 0, 0, 0]
    for lane in range(112):
        if mask & (1 << (lane // 4)) and lane not in UNFITTED[site]:
            words[lane // 32] |= 1 << (lane % 32)
    return tuple(words)


def require_release():
    if not RELEASED or any(value is None or not re.fullmatch(r"[0-9a-f]{64}", value)
                           for value in (BIT_SHA256, DCP_SHA256, ELF_SHA256)):
        raise RuntimeError("all-links v3 is UNRELEASED: routed audit and artifact pins required")


def required_refclks(enabled):
    # Physical REFCLK0 groups, in unchanged global-quad ordering.
    left = (0x5c,) * 3 + (0x58,) + (0x54,) * 3 + (0x50,) * 3 + (0x4c,) + (0x48,) * 3
    right = (0x30,) * 3 + (0x2c,) + (0x44,) * 3 + (0x40,) * 3 + (0x3c,) + (0x38,) * 3
    return tuple(sorted({address for q, address in enumerate(left + right) if enabled & (1 << q)}))
