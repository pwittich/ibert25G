#!/usr/bin/env python3
"""Force and verify one v2.5.10 acquisition-time full-quad restart."""

import milestone259_forced_restart_acceptance as acceptance

if __name__ == "__main__":
    acceptance.VERSION = 0x0002010A
    acceptance.CANDIDATE_LABEL = "2.5.10"
    try:
        raise SystemExit(acceptance.main())
    except (AttributeError, KeyError, ModuleNotFoundError, RuntimeError) as error:
        import sys
        print("ERROR: {}".format(error), file=sys.stderr)
        raise SystemExit(1)
