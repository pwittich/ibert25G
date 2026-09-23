# Existing-v5 one-way subset diagnostic (not executed)

Offline launcher preparation only. `REVIEW_RELEASED=False` blocks the new
launcher before network access and the remote helper before Registry creation.
Release requires parent review of the golden reference evidence, three-quad
subset simulation, and explicit authorization for the new hardware gate.
No hardware commands, deployment, or programming were performed to create it.

## Prerequisites

- Preserve golden F1 as the known-good PRBS31 transmitter, external mode,
  TXDIFFCTRL=01001 (GUI 630 mV), pre/postcursor zero. Archive actual per-lane
  settings and a timed eleven-lane F2 golden baseline first. Do not infer live
  loopback settings from earlier reports.
- Review subset simulation with lane9 unlocked and excluded; three physical
  quads must acquire without requiring that lane's PRBS lock. Full physical
  reset/clock faults are not bypassed by a reduced lane mask.
- Separately authorize/program F2 ONLY with the exact audited v5 image using
  the existing fixed `board_program.py firefly1_loopback_v5_f2` choice.
  Bit SHA256 `a1014f7d2451045ae6fbae66f0d2d1faef60d74c4a74190584be20b6a821f28e`;
  ELF SHA256 `37972efc9f7cd65ff2bd2569bd6b776bec0263d2ad00a32e9c3de2975ab06528`.
  The launcher does not program or silently reload. Historical same-image PMA
  evidence is the prerequisite; this diagnostic adds no new PMA run.
- F1_1 TX is physically connected to F2_1 RX only. F2 TX is unconnected, but
  v5 requires a bounded local TX lease to accept an external RX measurement.
- Serialize all MCU UART users, including manual tools. The installed MCU FP
  transport owns I2C5 semaphore/mux selection per transaction. No F1 generic
  mailbox object is accessed, and no module controls or JTAG controls are used.

## Fixed protocol

Fresh F2 must report FW/HW 0x00020304, seq/ack/run0, healthy IDLE, session off,
valid required clocks, no retained platform fault, and controller IDLE.

| Operation | Sequence | Run ID afterward | Mask | Duration |
|---|---:|---:|---|---:|
| Start local TX lease (command2) | 1 | 0 | 0xFFF | 180000 ms |
| One external PRBS31 RX request (0x10501) | 2 | 1 | 0xDFF | 10000 ms |
| Stop local TX lease (command3) | 3 | 1 | 0xFFF | 0 |

RX mask excludes test lane9 = X0Y13 = optical Rx02. Session masks must remain
FFF as required by the firmware. Success summary is **0x000B0B01**, derived
from eleven selected/passed lanes and normal stop reason1. Selected records
must have exact status 0x1800+lane, nonzero bits/cycles, zero errors/losses.
Excluded lane9 must have no selected flag and zero counters; its sampled lock
flag may be either value because the RTL snapshots qualified_lock independently
of selection. Measurement increments run ID exactly once; sessions do not.
Each selected record must satisfy tested_bits = 80 * valid_cycles and have
3,222,656,250 cycles within 1% (the nominal ten-second interval at
322.265625 MHz). The duration tolerance is conservative and independent of
the tighter 0.1% required clock-monitor checks. The published run/summary
must remain stable across reading all records, and all records must remain
identical across the session-stop command.

The new remote directory `/tmp/firefly1-v5-oneway-20260916` and exclusive
`oneway.started` sentinel are independent of consumed historical dual-board
tests. Never delete the sentinel or replay start, even if preflight/SSH fails.
Each descriptor field is read back before a single non-retried doorbell write.
Response polling is bounded (5 s for session command, 40 s RX); a 12 s cleanup
observation follows publication. Raw lane records, mailbox, clocks and FE are
captured before cleanup and on failure. A stop is issued only for an exactly
healthy active idle session with acknowledged (seq,run)=(1,0) or (2,1).
Fault/busy/ambiguous state receives no reset, abort, retry, or extra measurement;
the hardware lease remains the transmission bound. Session-stop response
replaces mailbox response code, so pre-stop evidence preserves RX failure.
If setup fails after session1 but before RX2, cleanup may go directly to stop3
without a measurement or run-ID increment. This is permitted by the actual
firmware loop (`sequence != handled_sequence`); it does not require consecutive
sequence values. The unused sequence2 is not submitted afterward.

## Future reviewed commands (currently hard-blocked)

`python3 scripts/board_firefly1_v5_oneway.py deploy|preflight|start|status|results`

Deployment hash-verifies both remote files; every subsequent operation
revalidates that bundle. Logs are exclusive timestamped files under
`build/diagnostic_archive/firefly1-v5-oneway-*`. Status/results change only the
F2 diagnostic selector; results additionally validate successful final state.
New launcher execution needs its own narrowly scoped permission and task
authorization. Do not expand an existing consumed gate's approval.

An eleven-lane pass isolates managed acquisition; it is not twelve-lane optical
qualification, a reverse-direction test, or a justification for changing TX
fault policy. The failed Rx02 optical path remains separate work.

Offline tests: `python3 -m unittest discover -s scripts -p test_firefly1_v5_oneway.py`.
