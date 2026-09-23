# V270 RUN versus IDLE alarms — 2026-09-12

The user authorized reloading v270 after the golden comparison and running
one clean 10-second baseline with timed F1_5 alarm samples. A separate
programming helper and approval rule were installed after the interrupted
legacy reload. No surviving batch programmer was found; the mailbox still
had zero version words, consistent with golden. The unrelated interactive
XSDB process on lnx4189 was not changed.

`scripts/board_program.py v270` completed successfully with its fixed image
and ELF hash checks, remote lock and F1 target check. Programming timestamps
were 1789259891–1789259929. The diagnostic helper then verified firmware and
hardware 0x00020114, engine IDLE, fresh request/response/run IDs zero. Preload
FPGA temperatures F1/F2 were 53.3/25.0 C.

Operator: `scripts/milestone270_alarm_baseline.py`, Python 3.6 syntax checked.
Local and deployed SHA-256 matched:
`3270a2f5f9ac928656f2ce1f95a57dc9c4ecb3e882c416520215294500fba475`.
One request sequence 1 after 0 / run ID 1 was submitted; no retry, second
request or subsequent reconfiguration. No FireFly control write was made.

## Alarm result

Each sample bracketed the module reads with matching engine-state reads.
Flags clear on read; first samples can retain earlier phase conditions.

| Phase | Sample start (Unix seconds) | LOS | CDR LOL | RX clock kHz |
| --- | ---: | --- | --- | ---: |
| IDLE, first | 1789260112.3492281 | FF | FF | 322008 |
| IDLE, repeat | 1789260113.60255 | FF | FF | 322009 |
| RUN, first | 1789260113.923302 | FF | 00 | 322260 |
| RUN, approximately 1 s | 1789260115.0779421 | 00 | 00 | 322260 |
| RUN, approximately 3 s | 1789260117.2590091 | 00 | 00 | 322261 |
| IDLE after, first | 1789260124.1198084 | FF | FF | 322262 |
| IDLE after, repeat | 1789260125.3064985 | FF | FF | 322263 |

Byte 86 remained 00, byte 98 FF and rate select 00 in every sample. Module
status byte 2 was 02 in the repeated RUN samples, 00 otherwise.

This demonstrates phase-dependent module alarms without changing the optical
path: persistent IDLE FF/FF is not proof of a failing active PRBS link. It also
explains why continuous golden transmission produced clear module alarms.
Source `gt_lane_engine.sv` clears TX PRBS selection on stop, consistent with
different IDLE signaling; the precise module response to that signaling is
not independently characterized here. RX clock remained near nominal in the
immediate post-RUN IDLE samples; do not claim it always falls in IDLE.

## Important qualification: diagnostic profile validation failed

Hardware response/summary was 0x00040401, engine IDLE, matching sequence/run
ID 1. All four ordinary lane records were selected/locked, zero errors/losses,
each 3,222,603,184 cycles and 257,808,254,720 tested bits. Overview and lane
records were identical before/after the full capture.

However, the operator exited 1 with `ValueError: inconsistent RX profile`:
lane 12's profile was `[0x45520001, 0, 0, 0, 0, 0, 1, 0]` — marked valid but
zero elapsed cycles. Lanes 13–15 each had elapsed 3,222,603,183, zero errors,
valid 1. No operation or capture error was recorded before validation.
Do not describe the complete diagnostic run as validated, suppress the check,
or interpret lane 12's zero profile as a valid zero-error measurement.

Trace metadata was `[0x54520002, 51914, 1, 101, 0, 0, 0, 0]`; the restart
record had requested/accepted/completed 1/1/1. Raw data remains available for
offline inspection rather than a repeated hardware run.

Apollo original: `/tmp/v270-diagnostic-20260912/after-golden-run1-alarms.json`.
Local archive: `build/diagnostic_archive/v270-after-golden-run1-alarms.json`.
Local SHA-256: `b06aa231e78f5c1d84036b7ea834b5384f9e68ae44522f848c2b7b0849be9778`.
The standard result-dump helper was run immediately after validation failed;
its ordinary lane results agreed with the stored capture.

Post-failure helper telemetry: F1/F2 FPGA temperatures 25.5/24.0 C; both
F1AVTT/CC supply status sets clear, Vout 1.204345703125/0.90380859375 V,
raw currents -0.7490234375/-0.1396484375 A (unvalidated). F1_5/F1_6 module
temperatures 38/39 C, alarms FF/FF in IDLE, outputs enabled and CDR enable FF.

Next: inspect the zero-elapsed lane-12 diagnostic profile and its reset/capture
path offline, preserving this hardware state. Future optical characterization
must establish alarm state during RUN, not use IDLE flags as its baseline.
