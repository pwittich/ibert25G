#!/usr/bin/env python3
"""Run the fresh v13 60-second external-path PRBS31 smoke.

This Python 3.6-compatible wrapper pins the common Milestone 3 mailbox test
to full Milestone 3 v13 (firmware and hardware identity ``0x0002000D``).
Run one stage at a time after programming the audited v13 image:

  python3 scripts/milestone3_v13_external_smoke.py start
  python3 scripts/milestone3_v13_external_smoke.py status
  python3 scripts/milestone3_v13_external_smoke.py results

The test uses external GT mode (LOOPBACK=000), PRBS31, and managed lanes
12--15.  It begins with unique request sequence 1 after a reprogrammed FPGA.
"""

import milestone3_12hour_external_soak as external_test


VERSION = 0x0002000D


def main():
    external_test.FW_VERSION = VERSION
    external_test.HW_VERSION = VERSION
    return external_test.main(
        default_sequence=1,
        default_previous_sequence=0,
        default_duration_ms=60_000,
        default_run_label="v13 60-second external smoke",
        diagnostic_results=True,
        description=__doc__,
    )


if __name__ == "__main__":
    raise SystemExit(main())
