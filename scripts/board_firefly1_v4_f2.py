#!/usr/bin/env python3
"""Fixed F2-only v4 sequence-1, ten-second PMA gate. No program/reset/retry."""
import board_firefly1_loopback_v4 as gate

if __name__ == '__main__':
    gate.REMOTE_DIR = '/tmp/firefly1-v4-f2-pma-20260916'
    gate.REMOTE_ARGS = ' --fpga F2'
    gate.EVIDENCE_PREFIX = 'firefly1-v4-f2'
    gate.main()
