#!/usr/bin/env python3
"""One fresh v270 clean baseline with timed F1_5 alarms; no module writes."""
import json
import sys
import time
from pathlib import Path
import milestone268_characterize as checks
import milestone268_diagnostics as diag
import milestone3_12hour_external_soak as test
import transition_diagnostics


def main():
    if len(sys.argv) != 2:
        raise SystemExit('usage: milestone270_alarm_baseline.py NEW_OUTPUT.json')
    sys.path.insert(0, '/home/cms/25G')
    from cm_interface.registry import Registry
    from cm_interface.device.firefly import Firefly4
    diag.VERSION = test.FW_VERSION = test.HW_VERSION = 0x00020114
    raw = {'timestamp': time.time(), 'alarm_samples': []}
    with Path(sys.argv[1]).open('x') as output:
        registry = Registry(setup='tf', dev_path='/dev/ttyUL4')
        mailbox = test.FpgaMailbox(registry.fpgas['F1'])
        firefly = Firefly4(registry.uart, 0x28, 'F1_5')

        def sample(phase, expected):
            record = {'phase': phase, 'begin': time.time(),
                      'engine_before': mailbox.read_u32(test.REG_ENGINE_STATE)}
            raw['alarm_samples'].append(record)
            record['registers'] = {str(a): firefly.read_reg(a).hex()
                                   for a in (2, 3, 5, 86, 98, 99)}
            record['rx_clock_khz'] = mailbox.read_u32(0x98)
            record['engine_after'] = mailbox.read_u32(test.REG_ENGINE_STATE)
            record['end'] = time.time()
            print(json.dumps(record, sort_keys=True), flush=True)
            checks.require(record['engine_before'] == expected and
                           record['engine_after'] == expected, 'sample crossed engine phase')

        try:
            raw['before'] = test.read_overview(mailbox)
            for key, value in (('firmware version', diag.VERSION), ('hardware version', diag.VERSION),
                               ('engine state', 0), ('request sequence', 0),
                               ('response sequence', 0), ('hardware run ID', 0)):
                checks.require(raw['before'][key] == value, 'preflight ' + key)
            checks.require(firefly.read_reg(86)[0] == 0, 'outputs disabled')
            raw['restart_before'] = diag.page(mailbox, 0xfd)
            raw['epoch_before'] = diag.page(mailbox, 0xfc)[2]
            sample('idle_before_first', 0)
            time.sleep(1)
            sample('idle_before_repeat', 0)
            test.start_soak(mailbox, 1, 0, 10000, 'V270 timed alarm baseline', test.MANAGED_LANE_MASK)
            sample('run_first', 2)
            time.sleep(1)
            sample('run_1s', 2)
            time.sleep(2)
            sample('run_3s', 2)
            deadline = time.monotonic() + 30
            while mailbox.read_u32(test.REG_RESPONSE_SEQUENCE) != 1:
                checks.require(time.monotonic() < deadline, 'completion timeout; no retry')
                time.sleep(0.2)
            while transition_diagnostics.metadata(diag.page(mailbox, 0xfc))['active']:
                checks.require(time.monotonic() < deadline, 'cleanup timeout')
                time.sleep(0.1)
            sample('idle_after_first', 0)
            time.sleep(1)
            sample('idle_after_repeat', 0)
        except Exception as error:
            raw['operation_error'] = repr(error)
        finally:
            try:
                raw['capture'] = {}
                diag.capture(mailbox, raw['capture'])
            except Exception as error:
                raw['capture_error'] = repr(error)
            json.dump(raw, output, indent=2, sort_keys=True)
            output.flush()
    checks.require('operation_error' not in raw, raw.get('operation_error'))
    checks.require('capture_error' not in raw, raw.get('capture_error'))
    result = checks.validate(raw, 1, 1, 'clean')
    print(json.dumps({'metadata': result['metadata'], 'recovery': result['recovery']}, sort_keys=True))
    print('V270 ALARM BASELINE VALIDATED; NOT QUALIFICATION', flush=True)


if __name__ == '__main__':
    main()
