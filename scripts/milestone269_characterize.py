#!/usr/bin/env python3
"""Matching v269 diagnostic operator entry; rejects all other FW/HW versions."""
import milestone268_characterize as characterization

if __name__ == "__main__":
    characterization.diag.VERSION = 0x00020113
    characterization.LABEL = "V269"
    characterization.main()
