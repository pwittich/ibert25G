#!/usr/bin/env python3
"""Read the MCU ADC telemetry, including both FPGA temperature channels."""
import pprint
import sys


def main():
    sys.path.insert(0, "/home/cms/25G")
    from cm_interface.registry import Registry
    registry = Registry(setup="tf", dev_path="/dev/ttyUL4")
    pprint.pprint(registry.mcu.read_adc())


if __name__ == "__main__":
    main()
