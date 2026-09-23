#!/usr/bin/env python3
"""Run the isolated 2.5.5 recovery and FireFly-loss characterization."""

import milestone254_firefly_characterization as characterization


def main():
    characterization.VERSION = 0x00020105
    characterization.CANDIDATE_LABEL = "2.5.5"
    return characterization.main()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AttributeError, KeyError, ModuleNotFoundError, RuntimeError) as error:
        import sys
        print("ERROR: {}".format(error), file=sys.stderr)
        raise SystemExit(1)
