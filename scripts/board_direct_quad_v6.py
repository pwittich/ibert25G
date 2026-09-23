#!/usr/bin/env python3
"""Deploy/run the fixed v6 direct-quad gate; no arbitrary path, command or retry."""
import argparse
import hashlib
import subprocess
import time
from board_firefly1_loopback_v4 import ROOT, SSH, SCP, REMOTE

# Earlier v6 directories contain consumed one-shot markers and evidence.  Use
# a distinct revision directory for the complete q233 repair so deploy cannot
# overwrite or inherit any of those markers.
DIRECTORY = '/tmp/direct-quad-v6r2-20260917'
FILES = ('direct_quad_v6_remote.py', 'milestone3_12hour_external_soak.py')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage', choices=('deploy', 'status', 'pma', 'pma-f2-repair', 'external'))
    args = parser.parse_args()
    if args.stage == 'deploy':
        subprocess.run(SSH + ['mkdir ' + DIRECTORY], check=True)
        subprocess.run(SCP + [str(ROOT / 'scripts' / name) for name in FILES] +
                       [REMOTE + ':' + DIRECTORY + '/'], check=True)
    output = subprocess.check_output(
        SSH + ['cd ' + DIRECTORY + ' && sha256sum ' + ' '.join(FILES)],
        universal_newlines=True)
    found = dict((line.split()[1], line.split()[0]) for line in output.splitlines())
    for name in FILES:
        expected = hashlib.sha256((ROOT / 'scripts' / name).read_bytes()).hexdigest()
        if found.get(name) != expected:
            raise RuntimeError('remote hash mismatch: ' + name)
    if args.stage == 'deploy':
        print('DIRECT_V6_DEPLOY_VERIFIED ' + DIRECTORY)
        return 0
    evidence = ROOT / 'build' / 'diagnostic_archive' / (
        'direct-v6-%s-%d.log' % (args.stage, int(time.time() * 1000000)))
    command = 'cd %s && python3 -u direct_quad_v6_remote.py %s' % (DIRECTORY, args.stage)
    with evidence.open('x') as stream:
        process = subprocess.Popen(SSH + [command], cwd=str(ROOT), stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, universal_newlines=True)
        for line in iter(process.stdout.readline, ''):
            print(line, end='')
            stream.write(line)
            stream.flush()
        code = process.wait()
    print('DIRECT_V6_EVIDENCE ' + str(evidence))
    if code:
        raise RuntimeError('gate failed; preserve evidence, no replay')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
