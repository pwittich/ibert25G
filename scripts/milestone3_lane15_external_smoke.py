#!/usr/bin/env python3
"""Run a targeted 10-second external-path PRBS31 test on global lane 15.

This Python 3.6-compatible diagnostic follows the lane-12 request sequence 2:

  python3 ./milestone3_lane15_external_smoke.py start
  python3 ./milestone3_lane15_external_smoke.py status
  python3 ./milestone3_lane15_external_smoke.py results

Run this only after the lane-12 diagnostic has completed. Do not disturb the
external optical path during the measurement.
"""

import milestone3_12hour_external_soak as external_test


def main():
    return external_test.main(
        default_sequence=3,
        default_previous_sequence=2,
        default_duration_ms=10_000,
        default_run_label="10-second lane-15 external diagnostic",
        default_lane_mask=0x00008000,
        diagnostic_results=True,
        description=__doc__,
    )


if __name__ == "__main__":
    raise SystemExit(main())
