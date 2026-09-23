#!/usr/bin/env python3
"""Fixed diagnostic entry points; no arbitrary commands or hardware controls.

Run locally with Python 3.6+. No remote script deployment is needed for clocks
or modules. Temperature telemetry uses the MCU path, not hw_server. Results
uses the existing, version-matched Apollo diagnostic bundle. Alarm reads clear
flags; result reads select lane pages. Neither starts a run.
"""
import argparse
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent
SSH = ['ssh', '-F', '/dev/null', '-S',
       '/home/wittich/.ssh/master-cms@apollo3010-1:22',
       '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=10', 'cms@apollo3010-1']


def invocation(action):
    if action == 'firefly1-rssi':
        return SSH + ['python3 -'], ROOT / 'scripts/read_firefly1_rssi.py'
    if action == 'clocks':
        return SSH + ['python3 - --fpga F1 --cm-interface-root /home/cms/25G/cm_interface'], ROOT / 'scripts/read_fpga_frequencies.py'
    if action == 'modules':
        return SSH + ['python3 -'], ROOT / 'scripts/read_board_snapshot.py'
    if action in ('mcu_temperatures', 'temperatures'):
        return SSH + ['python3 -'], ROOT / 'scripts/read_mcu_temperatures.py'
    if action == 'results':
        return SSH + ['cd /tmp/v270-diagnostic-20260912 && python3 -B milestone3_dump_results.py --cm-interface-root /home/cms/25G/cm_interface'], None
    raise ValueError('unsupported diagnostic')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('clocks', 'modules', 'mcu_temperatures', 'results', 'temperatures', 'firefly1-rssi'))
    parser.add_argument('--dry-run', action='store_true', help='show argv without connecting')
    args = parser.parse_args()
    command, source = invocation(args.action)
    if args.dry_run:
        print(repr(command))
        print('stdin source:', source)
        return 0
    # No shell=True, caller-provided code, paths, SSH flags, or remote commands.
    payload = source.read_bytes() if source else None
    return subprocess.run(command, input=payload, cwd=str(ROOT)).returncode


if __name__ == '__main__':
    raise SystemExit(main())
