#!/usr/bin/env python3
"""New fixed F2-only diagnostic; no programming/reset/retry or F1 access."""
import argparse
import hashlib
import subprocess
import time
from board_firefly1_loopback_v4 import ROOT, SSH, SCP, REMOTE
from firefly1_v5_oneway_remote import REVIEW_RELEASED

DIRECTORY = '/tmp/firefly1-v5-oneway-20260916'
FILES = ('firefly1_v5_oneway_remote.py', 'milestone3_12hour_external_soak.py')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage', choices=('deploy', 'preflight', 'start', 'status', 'results'))
    args = parser.parse_args()
    if not REVIEW_RELEASED:
        raise RuntimeError('HOLD: golden evidence, subset simulation and parent review pending; no network access')
    if args.stage == 'deploy':
        subprocess.run(SSH + ['mkdir -p ' + DIRECTORY], check=True)
        subprocess.run(SCP + [str(ROOT / 'scripts' / f) for f in FILES] + [REMOTE + ':' + DIRECTORY + '/'], check=True)
    hashes = subprocess.check_output(SSH + ['cd ' + DIRECTORY + ' && sha256sum ' + ' '.join(FILES)], universal_newlines=True)
    found = {line.split()[1]: line.split()[0] for line in hashes.splitlines()}
    for name in FILES:
        if found.get(name) != hashlib.sha256((ROOT / 'scripts' / name).read_bytes()).hexdigest():
            raise RuntimeError('remote bundle differs: ' + name)
    if args.stage == 'deploy':
        print('V5_ONEWAY_DEPLOY_VERIFIED')
        return
    evidence = ROOT / 'build/diagnostic_archive' / ('firefly1-v5-oneway-%s-%d.log' % (args.stage, int(time.time()*1000000)))
    with evidence.open('x') as stream:
        process = subprocess.Popen(SSH + ['cd ' + DIRECTORY + ' && python3 -u firefly1_v5_oneway_remote.py ' + args.stage],
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)
        for line in iter(process.stdout.readline, ''):
            print(line, end='')
            stream.write(line)
            stream.flush()
        code = process.wait()
    print('V5_ONEWAY_EVIDENCE ' + str(evidence))
    if code:
        raise RuntimeError('stage failed; preserve evidence, no retry')


if __name__ == '__main__':
    main()
