# V269 diagnostic baseline — 2026-09-12

Historical record below. F1 was subsequently programmed with audited v270;
[both v270 baseline gates passed](v270-hardware-baselines.md). The v269
failure evidence and artifacts remain unchanged.

**Stopped after the first run failed validation. No second request, injection,
FireFly disable, or subsequent reprogramming was performed.** F1 remains v269,
sequence/run ID 1, engine IDLE. This is not a qualification candidate.

## Identity and preflight

Loaded the audited compressed bitstream identified in
[incremental build provenance](incremental-diagnostic-builds.md), SHA-256
`24a8b973c7eac9546ce50c07d281eaf496edf4b27aa9c6a7052d20bcc462c07d`.
XSDB ran on lnx4189, connecting with `-url TCP:lnx4189:3121`; target 1 was F1,
target 3 its running MicroBlaze, target 4 F2. Only F1 was programmed, using
embedded firmware BRAM INIT. Both mailbox version words subsequently read
`0x00020113`, with request/response/run ID zero. A premature mailbox read
during configuration returned ADDR_ACK_ERROR; no request was issued then.

The old v268 run-1 result was dumped before programming and remained clean.
Original v268 JSON/log hashes were verified against their previous record.
During collection, generic local filenames briefly received v269 data; v269
was moved to explicit version-prefixed names and the original v268 files were
restored from the untouched Apollo copies, with exact original hashes verified.

Preprogram JTAG SysMon: F1 26.0 C, F2 24.5 C
(`build/temperature-preprogram269.log`). Regulator page 0: Vin 11.9375 V,
Vout 1.19921875 V, raw Iout -0.6474609375 A, 32.5625 C; page 1:
Vin 11.96875 V, Vout 0.905029296875 V, raw Iout -0.25341796875 A,
32.0625 C. All status fields zero. Negative current readings are not validated
current measurements. FireFly 38 C, 3.304 V, byte 86 zero (outputs enabled).

## First 10-second external baseline

Operator: `milestone269_characterize.py --sequence 1 --previous-sequence 0
--expected-run-id 1 --stimulus clean --duration-ms 10000`.
Mailbox mask readback was `0xF000`, including after failure. Read-only XSDB
confirmed the actual AXI descriptor at `0x44A0002C` also remained `0xF000`;
engine status at `0x44A00010` was zero. No CPU halt occurred.

- Exactly one request/run completed, but response and hardware summary were
  `0x00030301`, not expected `0x00040401`.
- Lane 12 published status `0x0000000C`: **unselected**, zero counts.
- Lanes 13–15 each passed with zero errors/losses, 257,808,273,120 bits and
  3,222,603,414 valid cycles. This is not a four-lane pass.
- Trace schema `0x54520002`, epoch 1: all **127 events retained**, frozen,
  no overflow, stable metadata/overview/lane records across the full readout.
- Start and stop acknowledgement masks reached `0xF`, but actual steady
  TX/RX PRBS select words were `0x5550` (lane 12 off).
- At tick 20,000,100, acquisition entered quad-restart request (100.0005 ms
  after epoch start). Measurement began at tick 20,790,602; a separate cleanup
  restart followed capture. FD recorded 2 requested/accepted/completed restarts,
  latest cause 3, status 3, mask `0xE`, rather than the required single cleanup.
- All four native profiles were valid with elapsed 3,222,603,413 and zero
  error-active cycles. Profiles use global measurement enable, so lane 12's
  zero profile does **not** demonstrate that lane was selected or tested.

The ordinary result dump was collected immediately after validation failed.
No retry was attempted. The trace recorder capacity/readout worked on this run;
the acquisition/descriptor behavior failed the baseline gate.

## Post-failure state

JTAG SysMon F1 25.5 C, F2 24.0 C (`build/temperature-post269-run1.log`).
Regulator page 0: Vin 11.921875 V, Vout 1.207763671875 V,
raw Iout -0.6279296875 A, 32.0625 C; page 1: Vin 11.9375 V,
Vout 0.90625 V, raw Iout -0.078125 A, 32.0625 C. Status fields all zero.
Clock readings at 08/24/28/98 were 200000/100000/324999/322262 kHz;
recorded RX readings before/after measurement were 322262/322263 kHz.
FireFly 37 C, 3.309 V, byte 86 zero. Read-to-clear bytes 3 and 5 returned
`0xFF/0xFF`, including a later clear/read with a one-second interval. These
all-channel flags are unresolved and are not evidence of a controlled lane-12
outage; no such stimulus occurred. Direct external optical-partner state was
not independently measured. Adjacent lanes' clean PRBS results and native GT
status are preserved, not substituted for that missing measurement.

## Focused CDC reproducer and next gate

`gt_test_engine_core.sv` updates active descriptor selection/mode and toggles
start on the same management edge. `gt_lane_engine.sv` separately synchronizes
the start toggle, selected bit and PRBS mode with equal-depth chains, then
latches the synchronized descriptor when the start event is seen. Holding the
source descriptor afterward does not ensure it arrived before the event.

New `sim/tb_gt_lane_descriptor_skew.sv` compares an ordinary zero-skew start
with a single extra first-stage capture cycle on the selected bit. The first
case selects lane 12; the skewed case acknowledges start but remains
unselected even once the descriptor synchronizer has settled. The simulator
reported `REPRODUCED` in `build/v269-skew-reproducer.log`. This demonstrates a
logical CDC defect consistent with the hardware signature, not analog
metastability simulation or proof of the exact hardware capture timing.
No design RTL, bitstream, or existing frozen source archive was changed.

Next: fix bundled descriptor/start transfer, explicitly testing relative
capture latency for selection and every PRBS-mode bit, both toggle phases,
stopped clocks and recovery. Require the accepted lane mask to match the
requested mask, rather than silently reporting a smaller successful run.
Only after those regressions and build/audit should another diagnostic image
be programmed. Re-establish two clean full-four-lane baselines before pulses
or FireFly-loss characterization. Also resolve the all-ones module alarm
readback before interpreting subsequent optical stimuli.

## Evidence

Apollo originals: `/tmp/v269-diagnostic-20260912/`.
Local files under `build/diagnostic_archive/`:

- `v269-run1-clean.json`: SHA-256
  `9acfe52798e05292f7940de507f59faf980183ff4033024f8061ea4c78bc1b7d`.
- `v269-run1-clean.log`: SHA-256
  `f205d246e91670fc7b6bb478dd92b293de1a1ba914b00d6af8496654d431dce4`.
- `v269-run1-failure-dump.log`: SHA-256
  `93e5356704e985a9b843d1d4431104a0ae7b4ea42f88b4f8f8cf8ee9d6d4735e`.
