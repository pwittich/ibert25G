#!/usr/bin/env python3
"""Configure/test four physical FireFly loopback quads per FPGA, default q121-q124.

These are external same-FPGA optical loops, not internal PMA loopback.
All other quads are disabled. Run from the packaged v3 runtime directory.
"""
from board_all_links_v3 import recorded_main


if __name__ == "__main__":
    raise SystemExit(recorded_main("loopback-four"))
