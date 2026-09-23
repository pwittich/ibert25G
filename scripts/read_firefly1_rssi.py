#!/usr/bin/env python3
"""Read only F2_1 RX power via verified x12 Rev4 raw RSSI registers."""
import sys


def main():
    sys.path.insert(0, '/home/cms/25G')
    from cm_interface.registry import Registry
    from cm_interface.device.firefly import FireflyRx
    registry = Registry(setup='tf', dev_path='/dev/ttyUL4')
    device = FireflyRx(registry.uart, 0x2b, 'F2_1_Rx')
    raw = bytes(device.read_block(0x01ce, 24))
    if len(raw) != 24:
        raise RuntimeError('Incomplete RSSI block')
    print('F2_1 RX device_index=11 logical_address=0x2b RSSI_01ce=' + raw.hex())
    for channel in range(12):
        offset = 2 * (11 - channel)
        power = int.from_bytes(raw[offset:offset + 2], 'big') / 10.0
        print('Rx%02d GT_X0Y%d test_lane=%d power_uW=%.1f' %
              (channel, 15 - channel, 11 - channel, power))


if __name__ == '__main__':
    main()
