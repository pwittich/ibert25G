#!/usr/bin/env python3
"""Briefly disable one FireFly-5 TX channel during a running v11 test.

FireFly-5 channels 0-3 map in ascending order to managed global lanes 12-15.
The x4 module's lower-page byte 86 (0x56) is the per-channel TX-disable mask.
This utility preserves the complete original byte and restores it even when a
readback or timing check fails.
"""

import argparse
from pathlib import Path
import sys
import time


FW_VERSION = 0x0002000B
HW_VERSION = 0x0002000B
REG_ENGINE_STATE = 0xC8
REG_FW_VERSION = 0xC0
REG_HW_VERSION = 0xC4
STATE_RUN = 2
FIREFLY_LOCATION = "F1_5"
FIREFLY_DEVICE_INDEX = 8
TX_DISABLE_REGISTER = 0x56
LOS_ALARM_REGISTER = 0x03
CDR_LOL_ALARM_REGISTER = 0x05


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--cm-interface-root",
        type=Path,
        default=Path("/nfs/cms/tracktrigger/wittich/int_test/cm_interface"),
        help="cm_interface package directory",
    )
    parser.add_argument("--device", default="/dev/ttyUL4")
    parser.add_argument(
        "--channel", type=int, choices=range(4), default=0,
        help="zero-based FireFly-5 channel (default: 0, global lane 12)",
    )
    parser.add_argument(
        "--disable-seconds", type=float, default=1.0,
        help="time to hold the selected TX disabled (default: 1.0)",
    )
    return parser.parse_args()


def read_u32(fpga, address):
    return int.from_bytes(bytes(fpga.read_reg(address, size=4)), "little")


def main():
    args = parse_args()
    if args.disable_seconds <= 0:
        raise SystemExit("--disable-seconds must be positive")

    package_parent = str(args.cm_interface_root.resolve().parent)
    if package_parent not in sys.path:
        sys.path.insert(0, package_parent)
    from cm_interface.device.firefly import Firefly4
    from cm_interface.registry import Registry

    registry = Registry(setup="tf", dev_path=args.device)
    fpga = registry.fpgas["F1"]
    # The MCU's FF indices follow the fixed generic physical-slot map. F1_5
    # is index 8; do not use the mutable populated-device preset, which packs
    # configured entries and can point F1_5 at index 0 instead.
    firefly = Firefly4(
        registry.uart, 0x20 + FIREFLY_DEVICE_INDEX, FIREFLY_LOCATION
    )

    fw_version = read_u32(fpga, REG_FW_VERSION)
    hw_version = read_u32(fpga, REG_HW_VERSION)
    engine_state = read_u32(fpga, REG_ENGINE_STATE)
    print("firmware version = 0x{:08x}".format(fw_version))
    print("hardware version = 0x{:08x}".format(hw_version))
    print("engine state     = 0x{:08x}".format(engine_state))
    if fw_version != FW_VERSION or hw_version != HW_VERSION:
        raise RuntimeError("F1 is not running matching Milestone-3 v11")
    if (engine_state & 0xF) != STATE_RUN:
        raise RuntimeError("F1 engine is not in ST_RUN")

    original = firefly.read_reg(TX_DISABLE_REGISTER)[0]
    # Bytes 3 and 5 are read-to-clear interrupt flags. Reading the baseline
    # intentionally clears prior history before the controlled interruption.
    baseline_los = firefly.read_reg(LOS_ALARM_REGISTER)[0]
    baseline_lol = firefly.read_reg(CDR_LOL_ALARM_REGISTER)[0]
    bit = 1 << args.channel
    disabled = original | bit
    print("{} part ID       = {!r}".format(FIREFLY_LOCATION, firefly.part_id))
    print("MCU FireFly index = {}".format(FIREFLY_DEVICE_INDEX))
    print("original byte 86 = 0x{:02x}".format(original))
    print("baseline LOS     = 0x{:02x}".format(baseline_los))
    print("baseline CDR LOL = 0x{:02x}".format(baseline_lol))
    print(
        "disabling channel {} / global lane {} with byte 86 = 0x{:02x}".format(
            args.channel, 12 + args.channel, disabled
        )
    )

    restored = False
    try:
        firefly.write_reg(TX_DISABLE_REGISTER, bytes([disabled]))
        readback = firefly.read_reg(TX_DISABLE_REGISTER)[0]
        if readback != disabled:
            raise RuntimeError(
                "TX-disable readback mismatch: wrote 0x{:02x}, read 0x{:02x}".format(
                    disabled, readback
                )
            )
        sample_delay = min(1.0, args.disable_seconds / 2.0)
        time.sleep(sample_delay)
        active_los = firefly.read_reg(LOS_ALARM_REGISTER)[0]
        active_lol = firefly.read_reg(CDR_LOL_ALARM_REGISTER)[0]
        print("disabled LOS     = 0x{:02x}".format(active_los))
        print("  RX/TX LOS      = 0x{:x}/0x{:x}".format(
            active_los & 0x0F, (active_los >> 4) & 0x0F
        ))
        print("disabled CDR LOL = 0x{:02x}".format(active_lol))
        print("  RX/TX CDR LOL  = 0x{:x}/0x{:x}".format(
            active_lol & 0x0F, (active_lol >> 4) & 0x0F
        ))
        time.sleep(args.disable_seconds - sample_delay)
    finally:
        firefly.write_reg(TX_DISABLE_REGISTER, bytes([original]))
        restore_readback = firefly.read_reg(TX_DISABLE_REGISTER)[0]
        restored = restore_readback == original
        print("restored byte 86 = 0x{:02x}".format(restore_readback))

    restored_los = firefly.read_reg(LOS_ALARM_REGISTER)[0]
    restored_lol = firefly.read_reg(CDR_LOL_ALARM_REGISTER)[0]
    print("restored LOS     = 0x{:02x}".format(restored_los))
    print("restored CDR LOL = 0x{:02x}".format(restored_lol))

    if not restored:
        raise RuntimeError("failed to restore the original TX-disable byte")
    print("FIREFLY TX INTERRUPTION COMPLETED")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AttributeError, KeyError, ModuleNotFoundError, RuntimeError) as error:
        print("ERROR: {}".format(error), file=sys.stderr)
        raise SystemExit(1)
