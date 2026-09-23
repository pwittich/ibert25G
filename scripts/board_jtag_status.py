#!/usr/bin/env python3
"""Read only Apollo's fixed XVC JTAG target list from lnx4189."""
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parent.parent
SSH = ['ssh', '-F', '/dev/null', '-S',
       '/home/wittich/.ssh/master-pw94@lnx4189:22', '-o', 'BatchMode=yes',
       '-o', 'ConnectTimeout=10', 'pw94@lnx4189']


def main():
    command = SSH + ['/nfs/opt/Xilinx/Vivado/2023.2/bin/xsdb ' +
                     str(ROOT / 'scripts' / 'board_jtag_status.tcl')]
    return subprocess.run(command, cwd=str(ROOT)).returncode


if __name__ == '__main__':
    raise SystemExit(main())
