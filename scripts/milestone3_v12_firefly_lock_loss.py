#!/usr/bin/env python3
"""Disable one FireFly-5 TX channel during a running v12 test.

The implementation preserves and restores lower-page byte 86 and samples the
read-to-clear LOS and CDR-LOL flags.  This wrapper changes only the required
firmware/hardware identity; the accepted v11 operator remains historical.
"""

import milestone3_firefly_lock_loss as lock_loss_test
import sys


V12_VERSION = 0x0002000C


def main():
    lock_loss_test.FW_VERSION = V12_VERSION
    lock_loss_test.HW_VERSION = V12_VERSION
    lock_loss_test.__doc__ = __doc__
    return lock_loss_test.main()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AttributeError, KeyError, ModuleNotFoundError, RuntimeError) as error:
        print("ERROR: {}".format(error), file=sys.stderr)
        raise SystemExit(1)
