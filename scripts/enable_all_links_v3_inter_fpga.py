#!/usr/bin/env python3
"""Enable TX/RX q221-q234 on F1 and F2; --test adds a timed external test.

All FireFly quads are disabled. No programming, reset, deployment or retry.
Run on the blade from the packaged v3 runtime directory.
"""
from board_all_links_v3 import recorded_main


if __name__ == "__main__":
    raise SystemExit(recorded_main("enable-inter-fpga"))
