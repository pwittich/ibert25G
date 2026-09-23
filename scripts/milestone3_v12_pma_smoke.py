#!/usr/bin/env python3
"""Run a version-locked ten-second v12 near-end-PMA PRBS31 smoke test.

This isolates the managed GT datapath from the external FireFly optical path.
Use it after an explicitly recorded/reloaded external-acquisition failure.
"""

import milestone3_12hour_external_soak as test


VERSION = 0x0002000C
COMMAND_PMA_PRBS31_MS = 0x00011501


def main():
    test.FW_VERSION = VERSION
    test.HW_VERSION = VERSION
    test.COMMAND_EXTERNAL_PRBS31_MS = COMMAND_PMA_PRBS31_MS
    return test.main(
        default_sequence=1,
        default_previous_sequence=0,
        default_duration_ms=10_000,
        default_run_label="v12 ten-second near-end-PMA smoke",
        description=__doc__,
    )


if __name__ == "__main__":
    raise SystemExit(main())
