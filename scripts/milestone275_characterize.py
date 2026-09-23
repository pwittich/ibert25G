#!/usr/bin/env python3
"""V275 qualification-candidate operator; no programming, stimulus, or retries."""
import milestone268_characterize as characterization


if __name__ == "__main__":
    characterization.diag.VERSION = 0x00020119
    characterization.LABEL = "V275"
    characterization.VALIDATION_BANNER = "V275 QUALIFICATION-CANDIDATE CLEAN RUN VALIDATED"
    characterization.EXPECTED_RESTART_DELTA = 2
    characterization.EXPECTED_PLANNED_STARTUP_RESTART = True
    characterization.main()
