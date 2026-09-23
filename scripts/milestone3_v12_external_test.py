#!/usr/bin/env python3
"""Run a version-locked v12 external-path PRBS31 test.

This Python 3.6-compatible wrapper reuses the established Milestone 3 mailbox
implementation while requiring matching v12 firmware and hardware identities.
It defaults to a 60-second, four-lane post-programming smoke:

  python3 scripts/milestone3_v12_external_test.py start
  python3 scripts/milestone3_v12_external_test.py status
  python3 scripts/milestone3_v12_external_test.py results
"""

import milestone3_12hour_external_soak as external_test


V12_VERSION = 0x0002000C


def main():
    # Keep the v11 implementation and its historical version gate unchanged.
    # This wrapper selects the v12 identity before any mailbox check occurs.
    external_test.FW_VERSION = V12_VERSION
    external_test.HW_VERSION = V12_VERSION
    return external_test.main(
        default_sequence=1,
        default_previous_sequence=0,
        default_duration_ms=60_000,
        default_run_label="v12 60-second external smoke",
        description=__doc__,
    )


if __name__ == "__main__":
    raise SystemExit(main())
