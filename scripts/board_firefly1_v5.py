#!/usr/bin/env python3
"""Fixed v5 dual-board gates; no programming, reset, arbitrary requests or retry."""
import argparse
import hashlib
import subprocess
import time
from board_firefly1_loopback_v4 import ROOT, SSH, SCP, REMOTE

DIRECTORY = '/tmp/firefly1-v5-dual-20260916'
FILES = ('firefly1_v5_remote.py', 'milestone3_12hour_external_soak.py')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage', choices=('deploy', 'status', 'pma', 'external', 'optics-api', 'optics'))
    args = parser.parse_args()
    if args.stage == 'deploy':
        subprocess.run(SSH + ['mkdir -p ' + DIRECTORY], check=True)
        subprocess.run(SCP + [str(ROOT / 'scripts' / f) for f in FILES] + [REMOTE + ':' + DIRECTORY + '/'], check=True)
    hashes = subprocess.check_output(SSH + ['cd ' + DIRECTORY + ' && sha256sum ' + ' '.join(FILES)], universal_newlines=True)
    found = {line.split()[1]: line.split()[0] for line in hashes.splitlines()}
    for name in FILES:
        if found.get(name) != hashlib.sha256((ROOT / 'scripts' / name).read_bytes()).hexdigest():
            raise RuntimeError('remote bundle differs: ' + name)
    if args.stage == 'deploy':
        print('V5_DEPLOY_VERIFIED')
        return
    evidence = ROOT / 'build/diagnostic_archive' / ('firefly1-v5-%s-%d.log' % (args.stage, int(time.time()*1000000)))
    with evidence.open('x') as stream:
        process = subprocess.Popen(SSH + ['cd ' + DIRECTORY + ' && python3 -u firefly1_v5_remote.py ' + args.stage],
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)
        for line in iter(process.stdout.readline, ''):
            print(line, end=''); stream.write(line); stream.flush()
        code = process.wait()
    print('V5_EVIDENCE ' + str(evidence))
    if code:
        raise RuntimeError('v5 stage failed; preserve evidence, no retry')

if __name__ == '__main__':
    main()
