#!/usr/bin/env python3
"""V274 planned-startup operator; no programming, stimulus, or retries."""
import milestone268_characterize as characterization


if __name__ == "__main__":
    characterization.diag.VERSION = 0x00020118
    characterization.LABEL = "V274"
    characterization.EXPECTED_RESTART_DELTA = 2
    characterization.EXPECTED_PLANNED_STARTUP_RESTART = True
    characterization.main()
