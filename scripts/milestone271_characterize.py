#!/usr/bin/env python3
"""Matching v271 diagnostic operator; no implicit programming or retries."""
import milestone268_characterize as characterization

if __name__ == "__main__":
    characterization.diag.VERSION = 0x00020115
    characterization.LABEL = "V271"
    characterization.main()
