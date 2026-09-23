#!/usr/bin/env python3
"""Run and inspect the Milestone 3 v11 24-hour external qualification.

This Python 3.6-compatible wrapper reuses the validated external-soak
implementation while keeping the 24-hour campaign and its defaults separate:

  python3 scripts/milestone3_24hour_external_qualification.py start
  python3 scripts/milestone3_24hour_external_qualification.py status
  python3 scripts/milestone3_24hour_external_qualification.py results

The defaults continue directly from the accepted 12-hour run: request
sequence 5 after response sequence 4. The expected hardware run ID is 4.
Use a different sequence history if the FPGA has been reprogrammed.
"""

import milestone3_12hour_external_soak as external_test


def main():
    return external_test.main(
        default_sequence=5,
        default_previous_sequence=4,
        default_duration_ms=86_400_000,
        default_run_label="24-hour external qualification",
        diagnostic_results=True,
        description=__doc__,
    )


if __name__ == "__main__":
    raise SystemExit(main())
