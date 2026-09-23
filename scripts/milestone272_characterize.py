#!/usr/bin/env python3
"""Matching v272 diagnostic operator; no implicit programming or retries."""
import milestone268_characterize as characterization

if __name__ == "__main__":
    characterization.diag.VERSION = 0x00020116
    characterization.LABEL = "V272"
    characterization.main()
