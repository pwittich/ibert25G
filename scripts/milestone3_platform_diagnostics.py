#!/usr/bin/env python3
"""Read and decode Milestone 3 v11 live and persistent fault diagnostics.

This Python 3.6-compatible utility does not start, abort, acknowledge, or
clear a run. Its only write selects diagnostic result page 0xfe at register
0xcc. The first-fault snapshot remains valid until FPGA reprogramming.

  python3 scripts/milestone3_platform_diagnostics.py
"""

import argparse
from pathlib import Path
import sys

import milestone3_12hour_external_soak as external_test


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--cm-interface-root",
        type=Path,
        default=Path("/nfs/cms/hw/wittich/int_test/cm_interface"),
        help="cm_interface package directory",
    )
    parser.add_argument(
        "--device",
        default="/dev/ttyUL4",
        help="MCU serial device used by Registry (default: /dev/ttyUL4)",
    )
    parser.add_argument(
        "--reg-module",
        default=None,
        help="optional importable module that directly exposes fpgas",
    )
    parser.add_argument("--fpga", default="F1", help="FPGA key (default: F1)")
    return parser.parse_args()


def main():
    args = parse_args()
    try:
        mailbox = external_test.load_mailbox(args)
        firmware = mailbox.read_u32(external_test.REG_FW_VERSION)
        hardware = mailbox.read_u32(external_test.REG_HW_VERSION)
        state = mailbox.read_u32(external_test.REG_ENGINE_STATE)
        print("Milestone 3 diagnostic preface:")
        print("  firmware version = {:#010x}".format(firmware))
        print("  hardware version = {:#010x}".format(hardware))
        print("      engine status = {:#010x}".format(state))
        if firmware != external_test.FW_VERSION:
            print(
                "WARNING: expected v11 firmware {:#010x}".format(
                    external_test.FW_VERSION
                ),
                file=sys.stderr,
            )
        if hardware != external_test.HW_VERSION:
            print(
                "WARNING: expected v11 hardware {:#010x}".format(
                    external_test.HW_VERSION
                ),
                file=sys.stderr,
            )
        external_test.print_platform_diagnostics(mailbox)
        return 0
    except (AttributeError, KeyError, ModuleNotFoundError, RuntimeError) as error:
        print("ERROR: {}".format(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
