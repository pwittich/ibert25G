#!/usr/bin/env python3
"""Read the FPGA clock-frequency monitor through ``cm_interface``.

This script is compatible with Python 3.6.  It reads the deployed generic-I2C
register ABI: r02-r38 contain direct frequency measurements in kHz and r39 is
the ID/status word.  Multi-byte register data is decoded little-endian, as
required by the FPGA register interface.

Typical use:

  python3 scripts/read_fpga_frequencies.py
  python3 scripts/read_fpga_frequencies.py --fpga F2
  python3 scripts/read_fpga_frequencies.py --json
"""

import argparse
import importlib
import json
from pathlib import Path
import sys
import time
from typing import Any, Dict, List, Tuple


CM_INTERFACE_ROOT = Path("/nfs/cms/hw/wittich/int_test/cm_interface")
DEFAULT_DEVICE = "/dev/ttyUL4"

STATUS_ADDRESS = 0x9C
STATUS_ID = 0x434D
STATUS_CLOCK_COUNT = 37
STATUS_FORMAT_VERSION = 1

# Keep this list in the exact r02-r38 order documented in README.md.
CLOCK_NAMES = [
    "clk_200_ext",
    "lhc_clk",
    "tcds40_clk",
    "rt_x4_r0_clk",
    "rt_x12_r0_clk",
    "lf_x4_r0_clk",
    "lf_x12_r0_clk",
    "clk_100",
    "clk_325",
    "rt_r0_p",
    "rt_r0_n",
    "rt_r0_l",
    "rt_r0_i",
    "rt_r0_g",
    "rt_r0_e",
    "rt_r0_b",
    "lf_r0_y",
    "lf_r0_w",
    "lf_r0_u",
    "lf_r0_r",
    "lf_r0_af",
    "lf_r0_ad",
    "lf_r0_ab",
    "rt_r1_p",
    "rt_r1_n",
    "rt_r1_l",
    "rt_r1_i",
    "rt_r1_g",
    "rt_r1_e",
    "rt_r1_b",
    "lf_r1_y",
    "lf_r1_w",
    "lf_r1_u",
    "lf_r1_r",
    "lf_r1_af",
    "lf_r1_ad",
    "lf_r1_ab",
]


def read_u32(fpga: Any, address: int) -> int:
    """Read one 32-bit generic-port register in little-endian wire order."""
    raw = bytes(fpga.read_reg(address, size=4))
    if len(raw) != 4:
        raise RuntimeError(
            "read_reg({:#04x}, size=4) returned {} bytes".format(
                address, len(raw)
            )
        )
    return int.from_bytes(raw, "little")


def decode_status(value: int) -> Dict[str, Any]:
    return {
        "raw": value,
        "id": (value >> 16) & 0xFFFF,
        "measurement_valid": bool(value & 0x8000),
        "clock_count": (value >> 8) & 0x7F,
        "format_version": value & 0xFF,
    }


def status_matches_abi(status: Dict[str, Any]) -> bool:
    return (
        status["id"] == STATUS_ID
        and status["clock_count"] == STATUS_CLOCK_COUNT
        and status["format_version"] == STATUS_FORMAT_VERSION
    )


def wait_for_valid_status(fpga: Any, timeout: float) -> Dict[str, Any]:
    deadline = time.monotonic() + timeout
    while True:
        status = decode_status(read_u32(fpga, STATUS_ADDRESS))
        if status_matches_abi(status) and status["measurement_valid"]:
            return status
        if time.monotonic() >= deadline:
            return status
        time.sleep(0.05)


def read_clocks(fpga: Any) -> List[Tuple[int, int, str, int]]:
    clocks = []
    for index, name in enumerate(CLOCK_NAMES):
        register = index + 2
        address = register * 4
        clocks.append((register, address, name, read_u32(fpga, address)))
    return clocks


def load_fpga(args: argparse.Namespace) -> Any:
    if args.reg_module is not None:
        registry = importlib.import_module(args.reg_module)
    else:
        # The configured path is the package directory itself, so import from
        # its parent.  Delay Registry construction until after CLI parsing so
        # --help never opens the serial device.
        package_parent = str(args.cm_interface_root.resolve().parent)
        if package_parent not in sys.path:
            sys.path.insert(0, package_parent)
        from cm_interface.registry import Registry

        registry = Registry(setup="tf", dev_path=args.device)
    return registry.fpgas[args.fpga]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fpga", default="F1", help="FPGA key (default: F1)")
    parser.add_argument(
        "--device",
        default=DEFAULT_DEVICE,
        help="MCU serial device (default: /dev/ttyUL4)",
    )
    parser.add_argument(
        "--cm-interface-root",
        type=Path,
        default=CM_INTERFACE_ROOT,
        help="cm_interface package directory",
    )
    parser.add_argument(
        "--reg-module",
        default=None,
        help="optional importable module that directly exposes fpgas",
    )
    parser.add_argument(
        "--wait-valid",
        type=float,
        default=2.0,
        help="seconds to wait for a valid measurement (default: 2)",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="emit machine-readable JSON instead of a table",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        fpga = load_fpga(args)
        status_before = wait_for_valid_status(fpga, max(0.0, args.wait_valid))
        if not status_matches_abi(status_before):
            raise RuntimeError(
                "r39 has unexpected ABI status {:#010x}; expected ID 0x434d, "
                "37 clocks, format 1".format(status_before["raw"])
            )
        if not status_before["measurement_valid"]:
            raise RuntimeError(
                "r39 is {:#010x}; measurement_valid did not assert within "
                "{:.3g} s".format(status_before["raw"], args.wait_valid)
            )

        clocks = read_clocks(fpga)
        status_after = decode_status(read_u32(fpga, STATUS_ADDRESS))
        if not status_matches_abi(status_after) or not status_after["measurement_valid"]:
            raise RuntimeError(
                "r39 became invalid while reading clocks: {:#010x}".format(
                    status_after["raw"]
                )
            )

        if args.json:
            document = {
                "fpga": args.fpga,
                "status": status_after,
                "clocks": [
                    {
                        "register": register,
                        "address": address,
                        "name": name,
                        "frequency_khz": frequency,
                    }
                    for register, address, name, frequency in clocks
                ],
            }
            print(json.dumps(document, indent=2, sort_keys=True))
        else:
            print(
                "{} frequency monitor: r39={:#010x}, valid={}, clocks={}, "
                "format={}".format(
                    args.fpga,
                    status_after["raw"],
                    status_after["measurement_valid"],
                    status_after["clock_count"],
                    status_after["format_version"],
                )
            )
            print(" reg  addr  clock                 frequency (kHz)      MHz")
            for register, address, name, frequency in clocks:
                print(
                    " r{0:02d}  0x{1:02x}  {2:<20} {3:>15d}  {4:>9.3f}".format(
                        register, address, name, frequency, frequency / 1000.0
                    )
                )
        return 0
    except (AttributeError, ImportError, KeyError, OSError, RuntimeError) as error:
        print("ERROR: {}".format(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
