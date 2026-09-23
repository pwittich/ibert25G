#!/usr/bin/env python3
"""Run one fresh v15 60-second external-path PRBS31 smoke.

This Python 3.6-compatible wrapper pins the common mailbox test to full v15
(``0x0002000F``). It uses external mode, PRBS31, and managed lanes 12--15.
Only run its start stage after programming the exact hash-pinned v15 image.
"""

import milestone3_12hour_external_soak as external_test


VERSION = 0x0002000F


def main():
    external_test.FW_VERSION = VERSION
    external_test.HW_VERSION = VERSION
    return external_test.main(
        default_sequence=1,
        default_previous_sequence=0,
        default_duration_ms=60_000,
        default_run_label="v15 60-second external smoke",
        diagnostic_results=True,
        description=__doc__,
    )


if __name__ == "__main__":
    raise SystemExit(main())
