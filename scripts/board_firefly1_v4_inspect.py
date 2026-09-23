#!/usr/bin/env python3
"""Fixed read-only F1/F2 mailbox and clock inspection; no selector writes."""
import argparse
import subprocess
import time
from pathlib import Path
from board_diagnostics import SSH, ROOT


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage', choices=('preflight', 'verify', 'pma-complete'))
    args = parser.parse_args()
    source = ROOT / 'scripts/firefly1_v4_inspect_remote.py'
    evidence = ROOT / 'build/diagnostic_archive' / (
        'firefly1-v4-dual-%s-%d.log' % (args.stage, int(time.time() * 1000000)))
    command = SSH + ['python3 -u - ' + args.stage]
    with evidence.open('x') as stream:
        result = subprocess.run(command, input=source.read_text(),
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                universal_newlines=True, timeout=120)
        stream.write(result.stdout)
    print(result.stdout, end='')
    print('INSPECT_EVIDENCE ' + str(evidence))
    return result.returncode


if __name__ == '__main__':
    raise SystemExit(main())
