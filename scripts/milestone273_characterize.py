#!/usr/bin/env python3
"""V273 planned-startup-restart operator; no programming or retries."""
import milestone268_characterize as characterization

if __name__ == "__main__":
    characterization.diag.VERSION = 0x00020117
    characterization.LABEL = "V273"
    characterization.EXPECTED_RESTART_DELTA = 2
    characterization.EXPECTED_PLANNED_STARTUP_RESTART = True
    characterization.main()
