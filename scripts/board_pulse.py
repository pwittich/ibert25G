#!/usr/bin/env python3
"""Arm one fixed, reviewed XSDB pulse watcher through lnx4189."""
import argparse
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parent.parent
SSH = ['ssh', '-F', '/dev/null', '-S',
       '/home/wittich/.ssh/master-pw94@lnx4189:22', '-o', 'BatchMode=yes',
       '-o', 'ConnectTimeout=10', 'pw94@lnx4189']


def command(action):
    if action != 'v272-run3':
        raise ValueError('unsupported pulse action')
    return SSH + ['flock -n /tmp/pw94-apollo3010-f1-pulse.lock '
                  '/nfs/opt/Xilinx/Vivado/2023.2/bin/xsdb '
                  '/nfs/cms/hw/wittich/25G_2/vu13p_ibert_25g/scripts/'
                  'milestone272_pulse.tcl']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('v272-run3',))
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    argv = command(args.action)
    if args.dry_run:
        print(repr(argv))
        return 0
    return subprocess.run(argv, cwd=str(ROOT)).returncode


if __name__ == '__main__':
    raise SystemExit(main())
