#!/usr/bin/env python3
"""Explicit F1/F2 programming of fixed, hash-pinned images through lnx4189.

Preserve results and check power/temperature before use. No automatic retries.
Separate from the diagnostic helper: this command intentionally changes hardware.
"""
import argparse
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parent.parent
SSH = ['ssh', '-F', '/dev/null', '-S',
       '/home/wittich/.ssh/master-pw94@lnx4189:22', '-o', 'BatchMode=yes',
       '-o', 'ConnectTimeout=10', 'pw94@lnx4189']


def command(image):
    if image in ('firefly1_loopback_v4_f2', 'firefly1_loopback_v5', 'firefly1_loopback_v5_f2',
                 'direct_quad_v6_f1', 'direct_quad_v6_f2',
                 'direct_all_v8_f1', 'direct_all_v8_f2',
                 'direct_all_v9_f1', 'direct_all_v9_f2',
                 'direct_all_v10_f1', 'direct_all_v10_f2',
                 'direct_all_v11_f1', 'direct_all_v11_f2',
                 'direct_all_v12_f1', 'direct_all_v12_f2',
                 'all_links_v2_f1', 'all_links_v2_f2'):
        return SSH + ['flock -n /tmp/pw94-apollo3010-f1-program.lock '
                      '/nfs/opt/Xilinx/Vivado/2023.2/bin/xsdb '
                      '/nfs/cms/hw/wittich/25G_2/vu13p_ibert_25g/scripts/board_program.tcl ' + image]
    if image not in ('v270', 'v271', 'v272', 'v273', 'v274', 'v275', 'v13', 'v14', 'v15', 'firefly1_loopback_v1', 'firefly1_loopback_v2', 'firefly1_loopback_v3', 'firefly1_loopback_v4', 'right221_223_proof', 'right221_223_managed_proof', 'golden'):
        raise ValueError('unsupported image')
    # All remote shell tokens are fixed, not supplied by the caller. The remote
    # lock prevents overlapping invocations of this helper, not legacy tools.
    return SSH + ['flock -n /tmp/pw94-apollo3010-f1-program.lock '
                  '/nfs/opt/Xilinx/Vivado/2023.2/bin/xsdb '
                  '/nfs/cms/hw/wittich/25G_2/vu13p_ibert_25g/scripts/board_program.tcl ' + image]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('image', choices=('v270', 'v271', 'v272', 'v273', 'v274', 'v275', 'v13', 'v14', 'v15', 'firefly1_loopback_v1', 'firefly1_loopback_v2', 'firefly1_loopback_v3', 'firefly1_loopback_v4', 'firefly1_loopback_v4_f2', 'firefly1_loopback_v5', 'firefly1_loopback_v5_f2', 'direct_quad_v6_f1', 'direct_quad_v6_f2', 'direct_all_v8_f1', 'direct_all_v8_f2', 'direct_all_v9_f1', 'direct_all_v9_f2', 'direct_all_v10_f1', 'direct_all_v10_f2', 'direct_all_v11_f1', 'direct_all_v11_f2', 'direct_all_v12_f1', 'direct_all_v12_f2', 'all_links_v2_f1', 'all_links_v2_f2', 'right221_223_proof', 'right221_223_managed_proof', 'golden'))
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    argv = command(args.image)
    if args.dry_run:
        print(repr(argv))
        return 0
    if args.image in ('firefly1_loopback_v4', 'firefly1_loopback_v4_f2',
                      'firefly1_loopback_v5', 'firefly1_loopback_v5_f2',
                      'direct_quad_v6_f1', 'direct_quad_v6_f2',
                      'direct_all_v8_f1', 'direct_all_v8_f2',
                      'direct_all_v9_f1', 'direct_all_v9_f2',
                      'direct_all_v10_f1', 'direct_all_v10_f2',
                      'direct_all_v11_f1', 'direct_all_v11_f2',
                      'direct_all_v12_f1', 'direct_all_v12_f2',
                      'all_links_v2_f1', 'all_links_v2_f2'):
        target = 'F2' if args.image.endswith('_f2') else 'F1'
        version = ('all-links-v2' if args.image.startswith('all_links_v2') else
                   ('v12' if args.image.startswith('direct_all_v12') else
                   ('v11' if args.image.startswith('direct_all_v11') else
                   ('v10' if args.image.startswith('direct_all_v10') else
                   ('v9' if args.image.startswith('direct_all_v9') else
                   ('v8' if args.image.startswith('direct_all_v8') else
                   ('v6' if args.image.startswith('direct_quad_v6') else
                    ('v5' if args.image.startswith('firefly1_loopback_v5') else 'v4'))))))))
        evidence = ROOT / 'build' / 'diagnostic_archive' / (
            'firefly1-%s-%s-program-%d.log' % (version, target, int(time.time() * 1000000)))
        with evidence.open('x') as stream:
            result = subprocess.run(argv, cwd=str(ROOT), stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, universal_newlines=True)
            stream.write(result.stdout)
        print(result.stdout, end='')
        print('PROGRAM_EVIDENCE ' + str(evidence))
        if result.returncode:
            return result.returncode
        if 'PROGRAM_%s_COMPLETE' % target not in result.stdout:
            print('Programming completion marker absent; verify mailbox identity before any request.')
            return 2
        return 0
    return subprocess.run(argv, cwd=str(ROOT)).returncode


if __name__ == '__main__':
    raise SystemExit(main())
