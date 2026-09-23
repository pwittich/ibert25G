#!/usr/bin/env python3
"""Fixed read-only golden capture via Apollo XVC; no GUI server dependency."""
import argparse
import fcntl
import os
from pathlib import Path
import signal
import socket
import subprocess
import time
from board_program import SSH

ROOT = Path(__file__).resolve().parent.parent
TOOLS = '/nfs/opt/Xilinx/Vivado/2023.2/bin'
PORT = 43121


def local_capture():
    if not socket.gethostname().split('.')[0] == 'lnx4189':
        raise RuntimeError('local capture must execute on lnx4189')
    # Same lock as fixed programming helpers; never overlap those operations.
    with open('/tmp/pw94-apollo3010-f1-program.lock', 'a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        with socket.socket() as probe:
            # TIME_WAIT from the previous capture is not a live server.
            # SO_REUSEADDR still refuses an existing listening socket.
            probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            probe.bind(('127.0.0.1', PORT))  # Refuse an occupied private port.
        logs = ROOT / 'build/logs'
        logs.mkdir(parents=True, exist_ok=True)
        log = logs / ('golden-xvc-bridge-%d.log' % int(time.time() * 1000000))
        with log.open('x') as stream:
            bridge = subprocess.Popen([TOOLS + '/hw_server', '-s',
                                       'TCP:127.0.0.1:%d' % PORT],
                                      stdout=stream, stderr=subprocess.STDOUT,
                                      start_new_session=True)
            try:
                deadline = time.monotonic() + 15
                while True:
                    if bridge.poll() is not None:
                        raise RuntimeError('private bridge exited; inspect ' + str(log))
                    try:
                        with socket.create_connection(('127.0.0.1', PORT), timeout=.5):
                            break
                    except OSError:
                        if time.monotonic() >= deadline:
                            raise RuntimeError('private bridge startup timeout')
                        time.sleep(.2)
                subprocess.run(['bash', 'skills/vivado-build-project/scripts/run-vivado.sh',
                                'scripts/capture_firefly1_golden_readonly.tcl'],
                               cwd=str(ROOT), check=True, timeout=300)
            finally:
                # Terminate only the child created here; never touch the GUI server.
                os.killpg(bridge.pid, signal.SIGTERM)
                try:
                    bridge.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    os.killpg(bridge.pid, signal.SIGKILL)
                    bridge.wait()
                # Shell exit can precede the actual server's shutdown.
                deadline = time.monotonic() + 15
                while True:
                    try:
                        with socket.create_connection(('127.0.0.1', PORT), timeout=.5):
                            pass
                    except OSError:
                        print('XVC_BRIDGE_PORT_RELEASED', flush=True)
                        break
                    if time.monotonic() >= deadline:
                        raise RuntimeError('private bridge port still occupied after cleanup')
                    time.sleep(.2)
                print('XVC_BRIDGE_LOG ' + str(log), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('capture', 'local-capture', 'dry-run'))
    args = parser.parse_args()
    command = SSH + ['python3 /nfs/cms/hw/wittich/25G_2/vu13p_ibert_25g/'
                     'scripts/board_golden_xvc.py local-capture']
    if args.operation == 'dry-run':
        print(repr(command))
    elif args.operation == 'local-capture':
        local_capture()
    else:
        return subprocess.run(command, check=False).returncode
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
