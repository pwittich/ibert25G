#!/usr/bin/env python3
"""Deploy/run fixed all-direct cleanup-repair gates; no program, reset or retry."""
import argparse
import hashlib
from pathlib import Path
import subprocess
import time

from all_direct_v7_contract import (ENDPOINTS, REMOTE_DIRECTORY,
                                    validate_contract)
from board_firefly1_loopback_v4 import ROOT, SSH, SCP, REMOTE

FILES = ('all_direct_v7_contract.py', 'all_direct_v7_remote.py',
         'milestone3_12hour_external_soak.py')


def file_sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify_release(root=ROOT):
    validate_contract()
    for site in ('F1', 'F2'):
        profile = ENDPOINTS[site]
        for kind in ('bit', 'dcp', 'elf'):
            path = root / profile[kind + '_path']
            if not path.is_file():
                raise RuntimeError('%s %s artifact missing: %s' %
                                   (site, kind, path))
            if file_sha256(path) != profile[kind + '_sha256']:
                raise RuntimeError('%s %s artifact hash mismatch' %
                                   (site, kind))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage', choices=('deploy', 'status', 'pma-f1',
                                         'pma-f2', 'external'))
    args = parser.parse_args()
    verify_release()
    if args.stage == 'deploy':
        subprocess.run(SSH + ['mkdir ' + REMOTE_DIRECTORY], check=True)
        subprocess.run(SCP + [str(ROOT / 'scripts' / name) for name in FILES] +
                       [REMOTE + ':' + REMOTE_DIRECTORY + '/'], check=True)
    output = subprocess.check_output(
        SSH + ['cd ' + REMOTE_DIRECTORY + ' && sha256sum ' + ' '.join(FILES)],
        universal_newlines=True)
    found = dict((line.split()[1], line.split()[0])
                 for line in output.splitlines())
    for name in FILES:
        expected = file_sha256(ROOT / 'scripts' / name)
        if found.get(name) != expected:
            raise RuntimeError('remote hash mismatch: ' + name)
    if args.stage == 'deploy':
        print('ALL_DIRECT_V12_DEPLOY_VERIFIED ' + REMOTE_DIRECTORY)
        print('PROGRAM_CHOICES F1=%s F2=%s' %
              (ENDPOINTS['F1']['program_choice'],
               ENDPOINTS['F2']['program_choice']))
        return 0
    evidence = ROOT / 'build' / 'diagnostic_archive' / (
        'all-direct-v12-%s-%d.log' %
        (args.stage, int(time.time() * 1000000)))
    command = ('cd %s && python3 -u all_direct_v7_remote.py %s' %
               (REMOTE_DIRECTORY, args.stage))
    with evidence.open('x') as stream:
        process = subprocess.Popen(SSH + [command], cwd=str(ROOT),
                                   stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT,
                                   universal_newlines=True)
        for line in iter(process.stdout.readline, ''):
            print(line, end='')
            stream.write(line)
            stream.flush()
        code = process.wait()
    print('ALL_DIRECT_V12_EVIDENCE ' + str(evidence))
    if code:
        raise RuntimeError('gate failed; preserve evidence, no replay')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
