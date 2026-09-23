# FireFly-1 v4 F2 bring-up — 2026-09-16

## Latest: F2 PMA gate passed; optical timing issue reproduced

F2 completed its one fresh sequence/run 1 ten-second PMA gate. All twelve
lanes recorded 257,808,259,520 bits / 3,222,603,244 cycles, zero errors and
native lock losses, summary/response 0x000c0c01. Final engine/controller IDLE,
platform ready, fault count and first-fault words zero. Retained quad-0
acquisition diagnostics sampled unlock mask 0x6, no sampled errors, maximum
clean streak 199,980 of 200,000 cycles; this initial acquisition observation
is distinct from the clean measurement. FE reports only one quad's context.

F1 remained at its passed run 1. Dual read-only verification confirms both
versions 0x00020303, both summary/response 0x000c0c01, valid 37-clock monitors,
100.000/325.000 MHz, FF1 references 322.260/322.261 MHz. Post-gate MCU F1/F2
temperatures 29.0625/27.578125 C; AVTT 1.2021484375/1.203125 V.

Evidence under `build/diagnostic_archive/`:

- `firefly1-v4-f2-start-1789577812.log`
- `firefly1-v4-f2-results-1789577818.log`
- `firefly1-v4-dual-pma-complete-1789577878335296.log`

New fixed approved F2 helper: `python3 scripts/board_firefly1_v4_f2.py
deploy|start|status|results|diagnostics`. It reuses the v4 gate with F2 fixed,
a separate deployment directory and separate exclusive logs. Six offline
gate tests pass, including F2 selection and refusal to resubmit a consumed
sequence. F2 `start` is now consumed. Neither FPGA was reset/reloaded.

### Bidirectional window simulation

`scripts/run_dual_endpoint_window_sim.tcl` through the required Vivado helper
compiled two actual `gt_test_engine_core`/`gt_lane_engine` instances. Each
retains the 112-lane ABI with one managed lane, same-clock snapshot transfer,
modeled acquisition readiness, and a behavioral error input when peer TX
PRBS is disabled. No GT analog, CDR or actual optical waveform is modeled.

With simultaneous request submission, equal 1,000-cycle durations, and
400-cycle acquisition skew, the early receiver passes (0x00010101), but
the late receiver fails from modeled source-off errors (0x01000101).
The explicit uncovered-window assertion passes. Thus this is a successful
reproduction of an unsafe test arrangement, NOT a passing optical test.

Log: `build/logs/run_dual_endpoint_window_sim-20260916T165741Z.log`.

Reason: the engine disables controls at IDLE after local publication; the
lane then clears TX PRBS. Its peer's measurement window can still be active.
Submission timing alone cannot guarantee equal acquisition completion.

Recommended next design: a separately versioned, default-off, external-only
bounded TX hold extending beyond local receive capture/publication, without
altering frozen results. It must use a clock independent of the receiver,
have a maximum duration and fault/reset release policy, and not bypass any
platform failure handling. Set the bound from explicit submission/acquisition
skew limits plus guard margin; test both directions, missing/late partner,
fault, abort and expiry. The launcher must enforce those limits and defer
subsequent requests until the hold ends. Re-simulate, build and audit before
loading that new image. No RTL change or new bitstream has been made yet.

Alternative test arrangements need equivalent evidence that each measured
receive window lies entirely inside its peer's valid PRBS transmission.
No optical request or stimulus has been issued.

## Historical initial bring-up (before the PMA gate)

User authorized loading the same bit onto F2 and checking general behavior
and clocks. User confirms all twelve-channel Fireflies are wired quad-to-quad
between F1 and F2, with matching reference clocks.

## Completed

- Verified existing independent routed-audit PASS and exact bit/ELF hashes:
  `cc450c14786a2a00fca7ad844d47be7e5438d160590b463f8f2bd85ffc17443a` /
  `abe06ba6f83ca94b0748076092c9bd3a2763d338987edfa14eb1e73d64956ab2`.
- Read-only JTAG preflight showed F1 target 1 with running MicroBlaze and F2
  target 4 without a MicroBlaze. F2 generic interface did not acknowledge
  before programming; F1 preserved its passed run 1.
- Added a fixed F2 choice to the existing programmer. Same pinned artifacts,
  same shared programming lock, exact two-FPGA topology guard, F2 target 4,
  separate completion marker and exclusive evidence. New narrow approval saved.
- Programmed F2 once; PROGRAM_F2_COMPLETE and running F2 MicroBlaze observed.
- New fixed approved inspection helper reads both mailboxes and all 37 clocks
  sequentially, without selector or request writes. F2 FW/HW = 0x00020303,
  state 0, request/response/run 0, response/summary 0. F1 remains state 0,
  request/response/run 1, response/summary 0x000c0c01.
- Both monitors valid 0x434da501; 100.000 and 325.000 MHz, FireFly-1
  reference (`lf_r0_ad`, r23) 322.260 MHz. All other readings agree to
  approximately 1–2 kHz: notably `rt_r0_l` 200 MHz, `lf_r0_ab` and REFCLK1
  inputs approximately 320.638 MHz, matching the pre-existing configuration.
  These are monitor readings, not optical recovered-clock qualification.
- Post-load MCU F1/F2 temperatures 28.921875/26.828125 C;
  F1/F2 AVTT 1.2001953125/1.203125 V.
- Six programmer unit tests and two read-only inspection tests pass.

## Evidence

All raw logs below are under `build/diagnostic_archive/`:

- `firefly1-v4-dual-preflight-1789577601227615.log`
- `firefly1-v4-F2-program-1789577631934905.log`
- `firefly1-v4-dual-verify-1789577676017284.log`

## Resume and limits

F1 was not programmed/reset/stimulated. F2 has not received a test request.
Do not reload either site automatically. No optical qualification claim.

Approved fixed forms:

```
python3 scripts/board_program.py firefly1_loopback_v4_f2
python3 scripts/board_firefly1_v4_inspect.py verify
```

The programmer choice remains hardware-changing and needs explicit task
authorization for any later use. Inspection verification is pinned to the
present F1 run 1/F2 run 0 state, not arbitrary future sequences.

Next: F2 PMA gate, dual-endpoint start/stop simulation and bounded external
orchestration, then short external baselines, fault tests, and long soak.
Do not reuse the F1-only PMA launcher on F2 or reinterpret PMA as optical.
