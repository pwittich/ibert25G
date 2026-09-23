#!/usr/bin/env python3
"""Fixed two-v5 one-way gate. No arbitrary commands, program, reset or retry."""
import argparse
import hashlib
import subprocess
import time
from board_firefly1_loopback_v4 import ROOT, SSH, SCP, REMOTE

DIRECTORY = '/tmp/firefly1-v5-managed-oneway-20260916'
FILES = ('firefly1_v5_managed_oneway_remote.py', 'firefly1_v5_oneway_remote.py',
         'milestone3_12hour_external_soak.py')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage', choices=('deploy', 'start', 'status', 'deploy-receive', 'start-receive', 'status-receive', 'deploy-all12', 'start-all12', 'repeat-all12', 'status-all12', 'deploy-soak1h', 'start-soak1h', 'status-soak1h', 'results-soak1h', 'deploy-loss', 'start-loss', 'status-loss', 'results-loss', 'deploy-alarm', 'start-alarm', 'status-alarm', 'results-alarm', 'deploy-closeout', 'start-closeout', 'status-closeout', 'results-closeout'))
    args = parser.parse_args()
    revised = args.stage.endswith('-receive')
    stage = args.stage.split('-')[0]
    directory = '/tmp/firefly1-v5-managed-receive-20260916' if revised else DIRECTORY
    remote_script = 'firefly1_v5_managed_receive_remote.py' if revised else FILES[0]
    files = FILES + (remote_script,) if revised else FILES
    if args.stage.endswith('-all12'):
        directory = '/tmp/firefly1-v5-all12-20260916'
        remote_script = 'firefly1_v5_all12_remote.py'
        files = FILES + ('firefly1_v5_managed_receive_remote.py', remote_script)
    if args.stage.endswith('-soak1h'):
        directory = '/tmp/firefly1-v5-soak1h-20260916'
        remote_script = 'firefly1_v5_soak1h_remote.py'
        files = FILES + ('firefly1_v5_managed_receive_remote.py', 'firefly1_v5_all12_remote.py', remote_script)
    if args.stage.endswith('-loss'):
        directory = '/tmp/firefly1-v5-loss-20260916'
        remote_script = 'firefly1_v5_loss_remote.py'
        files = FILES + ('firefly1_v5_managed_receive_remote.py', 'firefly1_v5_all12_remote.py', 'firefly1_v5_soak1h_remote.py', remote_script)
    if args.stage.endswith('-alarm'):
        directory = '/tmp/firefly1-v5-alarm-20260916'
        remote_script = 'firefly1_v5_alarm_remote.py'
        files = FILES + ('firefly1_v5_managed_receive_remote.py', 'firefly1_v5_all12_remote.py', 'firefly1_v5_soak1h_remote.py', 'firefly1_v5_loss_remote.py', remote_script)
    if args.stage.endswith('-closeout'):
        directory = '/tmp/firefly1-v5-closeout-20260916'
        remote_script = 'firefly1_v5_closeout_remote.py'
        files = FILES + ('firefly1_v5_managed_receive_remote.py', 'firefly1_v5_all12_remote.py', remote_script)
    if stage == 'deploy':
        subprocess.run(SSH + ['mkdir ' + directory], check=True)
        subprocess.run(SCP + [str(ROOT / 'scripts' / f) for f in files] +
                       [REMOTE + ':' + directory + '/'], check=True)
    hashes = subprocess.check_output(SSH + ['cd ' + directory + ' && sha256sum ' + ' '.join(files)], universal_newlines=True)
    found = {line.split()[1]: line.split()[0] for line in hashes.splitlines()}
    for name in files:
        if found.get(name) != hashlib.sha256((ROOT / 'scripts' / name).read_bytes()).hexdigest():
            raise RuntimeError('remote hash mismatch: ' + name)
    if stage == 'deploy':
        print('MANAGED_ONEWAY_DEPLOY_VERIFIED')
        return
    evidence = ROOT / 'build/diagnostic_archive' / ('firefly1-v5-managed-oneway-%s-%d.log' % (args.stage, int(time.time()*1000000)))
    with evidence.open('x') as stream:
        process = subprocess.Popen(SSH + ['cd ' + directory + ' && python3 -u ' + remote_script + ' ' + stage],
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)
        for line in iter(process.stdout.readline, ''):
            print(line, end='')
            stream.write(line)
            stream.flush()
        code = process.wait()
    print('MANAGED_ONEWAY_EVIDENCE ' + str(evidence))
    if code:
        raise RuntimeError('gate failed; preserve evidence, no replay')


if __name__ == '__main__':
    main()
