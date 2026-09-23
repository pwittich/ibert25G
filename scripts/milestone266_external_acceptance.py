#!/usr/bin/env python3
"""Run one clean isolated 2.5.16 four-lane external acceptance request."""

import milestone257_external_acceptance as acceptance

if __name__ == "__main__":
    acceptance.VERSION = 0x00020110
    acceptance.CANDIDATE_LABEL = "2.5.16"
    try:
        raise SystemExit(acceptance.main())
    except (AttributeError, KeyError, ModuleNotFoundError, RuntimeError) as error:
        import sys
        print("ERROR: {}".format(error), file=sys.stderr)
        raise SystemExit(1)
