#!/usr/bin/env python3
"""Run a targeted 10-second external-path PRBS31 test on global lane 12.

This Python 3.6-compatible diagnostic follows completed request sequence 1:

  python3 ./milestone3_lane12_external_smoke.py start
  python3 ./milestone3_lane12_external_smoke.py status
  python3 ./milestone3_lane12_external_smoke.py results

Run this test before the lane-15 diagnostic. Do not run the two tests at the
same time or disturb the external optical path during the measurement.
"""

import milestone3_12hour_external_soak as external_test


def main():
    return external_test.main(
        default_sequence=2,
        default_previous_sequence=1,
        default_duration_ms=10_000,
        default_run_label="10-second lane-12 external diagnostic",
        default_lane_mask=0x00001000,
        diagnostic_results=True,
        description=__doc__,
    )


if __name__ == "__main__":
    raise SystemExit(main())
