#!/usr/bin/env python3
"""Run the 60-second external-path smoke before the 12-hour soak.

This Python 3.6-compatible wrapper uses the same implementation and checks as
``milestone3_12hour_external_soak.py``, with safe post-reprogram defaults:

  python3 scripts/milestone3_60second_external_smoke.py start
  python3 scripts/milestone3_60second_external_smoke.py status
  python3 scripts/milestone3_60second_external_smoke.py results

The Milestone 3 FPGA must have been reloaded after the prior latched fault.
Confirm C8 is zero and the external optical PRBS31 path is ready before start.
"""

import milestone3_12hour_external_soak as external_test


def main():
    return external_test.main(
        default_sequence=1,
        default_previous_sequence=0,
        default_duration_ms=60_000,
        default_run_label="60-second external smoke",
        diagnostic_results=True,
        description=__doc__,
    )


if __name__ == "__main__":
    raise SystemExit(main())
