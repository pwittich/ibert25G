#!/usr/bin/env python3
"""Apollo F1 telemetry only. Alarm reads consume read-to-clear flags."""
import json
import sys
import time


def main():
    sys.path.insert(0, '/home/cms/25G')
    from cm_interface.registry import Registry
    from cm_interface.device.firefly import Firefly4
    registry = Registry(setup='tf', dev_path='/dev/ttyUL4')
    regulator = registry.get_lga80d('F1AVTT/CC')
    result = {'timestamp': time.time(), 'modules': {}, 'power': {}}
    for page in (0, 1):
        result['power'][str(page)] = {
            'telemetry': repr(regulator.read_telemetry(page=page)),
            'status': repr(regulator.read_status(page=page)),
        }
    for name, address in (('F1_5', 0x28), ('F1_6', 0x29)):
        device = Firefly4(registry.uart, address, name)
        result['modules'][name] = {
            'physical_address': address,
            'registers': {str(a): device.read_reg(a).hex()
                          for a in (2, 3, 5, 22, 86, 98, 99, 100, 102, 127)},
            'rx_power_raw': device.read_reg(34, size=4).hex()
                            + device.read_reg(38, size=4).hex(),
        }
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == '__main__':
    main()
