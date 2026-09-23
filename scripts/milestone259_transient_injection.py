#!/usr/bin/env python3
"""Start or validate the isolated 2.5.9 single-error characterization."""

import milestone257_transient_injection as characterization

if __name__ == "__main__":
    characterization.VERSION = 0x00020109
    characterization.CANDIDATE_LABEL = "2.5.9"
    try:
        raise SystemExit(characterization.main())
    except (AttributeError, KeyError, ModuleNotFoundError, RuntimeError) as error:
        import sys
        print("ERROR: {}".format(error), file=sys.stderr)
        raise SystemExit(1)
