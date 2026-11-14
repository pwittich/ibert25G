# Separate eye-scan image

Recovered from the November 10, 2026 planning session and started November 13.
The pre-eye implementation is preserved by commit `a82d50b` (`Add statically
qualified all-links v3 runtime quad control`). The eye work now includes the
integrated RTL, firmware ABI, guarded operator tools and offline plotting.
Synthesis, normal routed timing, independent audit and compressed BIT/BIN
verification pass. It remains **unreleased for hardware** pending a separate
reviewed hardware gate.
See [eye-scan-v1-runtime.md](eye-scan-v1-runtime.md)
for the current ABI, tools and build status. The historical milestones below
record what was complete at each earlier step.

## Accepted plan

Create a separate image based on v3, preserving working v2/v3 sources,
artifacts and launchers. Eye scanning runs between BER tests, with the
required transmitter running and the normal measurement engine idle.

1. Add independently versioned RTL, firmware, Tcl build and artifact pins.
   Enable GTY eye circuitry at initialization through supported Vivado
   configuration. Expose eye-scan reset where required while preserving
   normal receiver reset behavior.
2. Arbitrate between the existing PRBS counter controller and eye scanning.
   Scan one receive lane at a time per FPGA. Reject overlapping measurements,
   configuration changes and competing DRP requests.
3. Configure sampler offsets, start each measurement, wait with a bounded
   timeout, and capture raw error/sample counters. Derive masks, scaling and
   offset interpretation from actual GT configuration and AMD UG578. Support
   the configured equalizer mode, including both UT measurements for DFE.
4. Add versioned firmware scan-start, progress, cancel and paged-result
   operations. Preserve mailbox commands, lane records, clocks and diagnostic
   selectors. Buffer results without overwriting unread data.
5. Save modified scan registers and restore them on completion, cancellation
   or failure. Preserve normal receive settings. Require sufficient bounded
   TX-session duration before starting; never renew sessions or retry
   automatically.
6. Add `board_eye_scan.py` with `scan` and offline `plot` commands. Select FPGA,
   quad and lane explicitly. Require an enabled, locked receiver and existing
   clock, identity, MCU semaphore and FireFly acknowledgement checks.
7. Save raw counters, offsets, prescale, equalizer mode, lock status,
   configuration and artifact hashes in JSON/CSV. Produce PNG/PDF BER
   heatmaps and horizontal/vertical slices. Show measurement limits for
   zero-error points; use voltage codes until calibration is supported.
8. Simulate arbitration, sequencing, scaling, result backpressure, timeout,
   cancellation and restoration. Run existing BER/runtime-enable regressions.
   Require fresh synthesis, timing/CDC/constraint checks, independent routed
   audit and compressed BIT/BIN. Freeze candidate/software hashes.
9. Deployment and hardware execution require a separate reviewed gate:
   one receiver first, comparison with IBERT under matching conditions, then
   a clean ordinary BER test afterward.

## Baseline findings and configuration decisions

The existing `gt_prbs_test_controller` uses each channel's management-clock
DRP port to read native error counts at `0x25E/0x25F`. Its interface pulses
DRPEN without a ready input. The new arbiter must therefore preserve normal
requests and drain their replies before lending the port to a scanner.

The generated q121 baseline channel wrapper has `RX_DATA_WIDTH=80`,
`RX_INT_DATAWIDTH=2`, `ES_EYE_SCAN_EN=FALSE`, `ES_HORZ_OFFSET=0`, and
`USE_PCS_CLK_PHASE_SEL=0`. Its topology wrapper ties RXLPMEN high and
EYESCANRESET low. The independent checkpoint check below confirms the
width/internal width, disabled eye circuitry and constant LPM mode on all
112 channels. These are image properties, not live hardware readback.

AMD states that re-enabling powered-down eye circuitry requires PMA reset;
initialization in the separate image avoids adding that reset to a normal
scan. Sample scaling depends on internal datapath width and prescale, rather
than the fabric port width alone. DFE requires both UT accumulations. The
current guide reserves phase-selection attributes for Wizard recommendations;
do not copy phase settings from an older manual recipe without reconciling
the installed Wizard and actual configuration. Reference: [AMD UG578 v1.4,
RX Margin Analysis and DRP map](https://docs.amd.com/v/u/en-US/ug578-ultrascale-gty-transceivers).

The planned eye target may use `0x00020503` (unused at baseline); this is a
reserved development identity only. Matching firmware now exists; artifact
pins and hardware release remain closed.

## First implementation slice

`src/eye_scan_drp_arbiter.sv` implements a single-quad lease in the management
clock domain. It is now integrated in the separate image; the following
records its first slice and current ownership contract.

- Normal PRBS DRP requests pass through without backpressure. The current
  timing correction registers replies by one cycle; the first slice below
  originally used a combinational reply path.
  Outstanding requests are tracked independently for all four channels.
  Acquisition waits for idle eligibility, no request, no pending reply and
  low DRPRDY. Normal traffic has priority on the acquisition edge.
- The lease captures one physical channel. Subsequent selector changes
  cannot retarget it. One ready/valid scan command can be outstanding;
  DRPEN pulses once and address/data/write stay stable until completion.
- Scan replies are private to the scanner and held until acknowledged.
  Release waits for both outstanding transport and unread response to drain.
  The upper sequencer must restore saved registers before requesting release.
- Loss of eligibility or unexpected PRBS access sets a sticky fault and
  blocks the competing access. Scan transport remains available for cleanup.
  Release after such a violation quarantines the port.
- A scan DRP timeout publishes one error response and quarantines immediately.
  Late replies cannot satisfy a later scan or a normal counter read. No retry
  or automatic reset exists. Clearing quarantine requires a reset coordinated
  with the physical GT DRP state; a fabric-only reset is insufficient.

The arbiter is a transport mechanism, not the global exclusivity policy.
Integration must atomically block BER/configuration before acquisition,
enforce one scanner per FPGA, verify RX lock and remote/local TX coverage,
enforce the session budget, and retain eligibility through restoration.
The scan sequencer must stop and restore on policy faults; the arbiter cannot
prove register restoration or receiver health. A hung physical DRP port may
make restoration impossible; retain failure evidence and quarantine instead
of reporting successful cleanup.

Run focused simulation:

```sh
bash skills/vivado-build-project/scripts/run-vivado.sh scripts/run_eye_scan_drp_sim.tcl
```

Initial XSim 2023.2.2 result: **PASS, 15 scenarios / 13 scan operations**.
Coverage includes four lane selections, reads/writes, two pending PRBS lanes,
delayed/incorrect-lane replies, selector changes, unread-response backpressure,
deferred release, conflicts with restoration access, lost eligibility,
deadline-edge completion, timeout/late completion and reset output gating.
Log: `build/logs/run_eye_scan_drp_sim-20261113T154852Z.log`.

Inspect the qualified v3 synthesis checkpoint without saving changes:

```sh
bash skills/vivado-build-project/scripts/run-vivado.sh scripts/inspect_eye_scan_baseline.tcl
```

This script requires the exact recorded v3 synth hash, checks all 112 physical
channels, records receiver/eye properties and proves constant LPM drivers. It
temporarily sets and restores ES_EYE_SCAN_EN in memory to check Vivado's
primitive-property interface. It writes only a new report directory, never a
checkpoint or image, and rechecks the baseline hash afterward. This probe does
not qualify a future project's initialization flow or its routed design.

Inspection **PASS** on all 112 channels, including the in-memory property
set/readback/restoration and unchanged input DCP hash. Report:
`build/eye_scan_baseline_1794584950748058/channels.tsv`.
Log: `build/logs/inspect_eye_scan_baseline-20261113T154858Z.log`.

Standalone synthesis smoke gate (separate from full image sign-off):

```sh
bash skills/vivado-build-project/scripts/run-vivado.sh scripts/synth_eye_scan_drp.tcl
```

Standalone synthesis **PASS**: zero errors/critical warnings, no latches,
68 FDREs and both original state bits retained; synthesis explicitly reports
FSM extraction disabled. The small-design parallel-synthesis warning and
missing OOC clock-buffer location warning are retained. The OOC timing report
has no top-level I/O timing contracts and is not sign-off evidence. Reports:
`build/eye_scan_drp_synth_1794585104891920/`; log:
`build/logs/synth_eye_scan_drp-20261113T155141Z.log`.

## Remaining implementation

Next, integrate these blocks into the separately versioned top, SLR-bank and
managed-quad hierarchy, with global exclusion of BER/configuration and one
active scanner per FPGA. Add the scan/grid coordinator, bounded session-budget
checks, firmware/result ABI and host acquisition/plotting. The initialization
hook must run on fresh synthesis of that target; full image checks, timing,
CDC/placement constraints, independent routed audit and compressed BIT/BIN
generation remain outstanding. No deployment is authorized by these source
development steps.

No existing RTL, firmware, build entry point or launcher is changed by this
first slice. No deployment, programming, board read, reset or hardware scan
has been performed.

## Point sequencing and topology — 2026-11-13

`src/eye_scan_point.sv` now performs a complete point operation through
`eye_scan_drp_arbiter`. It accepts the actual LPM/DFE mode, lane, signed
horizontal and vertical offset, prescale, and finite per-UT sample deadline.
The supported profile is explicitly limited to the inspected 80-bit,
internal-width-2, RXOUT_DIV=1 configuration. The caller must verify that
profile and initialization, synchronize health inputs, establish a bounded
TX source, and block competing BER/configuration before start.

The sequencer acquires the lease, snapshots every register it can modify,
requires initialized eye circuitry and idle eye controls/state, and verifies
every configuration write. It starts RUN, accepts completion only in END
(status low nibble `5`), and captures raw counters. WAIT also asserts DONE
(status `1`) and is explicitly excluded as a completed measurement.

| Saved register group | DRP addresses |
|---|---|
| Control, prescale, eye/error-detector enable | `03C` |
| Horizontal offset and shared low bits | `04F` |
| Vertical sign, magnitude, UT, range and shared high bits | `097` |
| Qualifier masks 0–4 / 5–9 | `044`–`048` / `0EC`–`0F0` |
| Sample masks 0–4 / 5–9 | `049`–`04D` / `0F1`–`0F5` |

All 23 words are captured before the first write. Unmodified qualifier
patterns need no backup because all qualifier masks are set. Horizontal
phase-unification is asserted with signed 11-bit offset; the full-rate range
is restricted to −32…+32. Vertical magnitude is restricted to 0…127 with a
separate sign; the original range and unrelated fields are preserved.
Reserved phase-selection attributes and receiver equalization remain unchanged.
Map and sequencing reference: [AMD UG578 v1.4, Tables 4-20/21 and Appendix C](https://docs.amd.com/v/u/en-US/ug578-ultrascale-gty-transceivers).

LPM captures one pair; DFE captures separate +UT/−UT pairs. Each raw sample
count scales to `samples × 80 × 2^(prescale+1)` tested bits for this profile.
Each DFE pair retains its own denominator; the later plotting layer must use
the average of the two per-UT ratios. A six-bit shift count preserves prescale
31 correctly. Zero samples mark the result invalid. Status and raw-valid bits
distinguish a partial DFE result from a completed point.

Normal completion, cancellation, lost health/policy and sample timeout stop
RUN, verify WAIT, restore all saved masks/offsets, and restore the original
control word last. Every restored word is read back before release. Cancel
is latched through cleanup, including the gap between DFE passes. Unread
results block another start and remain immutable. Transport timeout, failed
stop/restore verification or failed release retain a fatal state and prevent
automatic reuse. A missing DRP reply can make restoration impossible; the
result records this rather than claiming cleanup succeeded.

Result status bits 0–7 are respectively bad descriptor/profile, cancelled,
lost health/policy, sample deadline, DRP/policy fault, bad readback/zero samples,
preexisting non-idle scan, and restoration/release failure. `cleanup_verified`
is independent of measurement success. `result_measurements[1:0]` identifies
captured raw UT pairs; the status must also be checked. Fatal jobs require
review and a reset coordinated with GT state, never a fabric-only retry.

The first lost-reply model run exposed changing DRP address/data after
quarantine. The arbiter now holds the accepted bundle through late completion
while keeping DRPEN low; its original focused tests still pass.

```sh
bash skills/vivado-build-project/scripts/run-vivado.sh scripts/run_eye_scan_point_sim.tcl
bash skills/vivado-build-project/scripts/run-vivado.sh scripts/synth_eye_scan_point.tcl
```

Final point simulation: **49 cases pass**, including cancellation at each of
the 23 configuration-write boundaries, negative/extreme offsets, prescale 31,
LPM/DFE, two jobs in the same instance, unread-result backpressure, fast END,
stale WAIT/DONE, zero samples, invalid/profile/busy preflight, lease withdrawal
races, second-UT cancellation with retained first result, loss of RX health,
sample/stop/transport timeouts, bad configuration/restoration readback and
late physical completion. The independently enumerated DRP model checks that
no other address/lane/shared field is modified and all original words return
after clean cleanup. It is a digital model; analog sampling and real GT timing
remain hardware qualification work.

Final standalone synthesis: **950 LUTs, 649 FFs, zero DSP/BRAM, no latches**,
and all five original state bits retained with FSM extraction disabled.
Zero errors/critical warnings. Constant unused DRP address bit, small-design
parallelism, flat OOC hierarchy and missing OOC clock-location warnings are
retained. OOC timing is diagnostic only; image timing is unqualified.

Final evidence:

- Point simulation: `build/logs/run_eye_scan_point_sim-20261113T173511Z.log`.
- Point synthesis: `build/logs/synth_eye_scan_point-20261113T173512Z.log`;
  reports `build/eye_scan_point_synth_1794591316129739/`.
- Arbiter regression: `build/logs/run_eye_scan_drp_sim-20261113T173011Z.log`
  (15 scenarios / 13 scan operations).
- Updated arbiter synthesis: `build/logs/synth_eye_scan_drp-20261113T173513Z.log`;
  reports `build/eye_scan_drp_synth_1794591317333764/`.

`derive_eye_scan_topology.tcl` generates 28 independent `_eye_v1_topology`
copies from the proven v3 wrappers, exposing only EYESCANRESET and renaming
the outer module. Exact inverse transformation reproduces each input byte for
byte. It records input/output hashes, refuses existing output directories and
syntax-checks every derived wrapper. No vendor XCI or original wrapper is
edited. Generation and syntax checks **pass 28/28**; log:
`build/logs/derive_eye_scan_topology-20261113T173403Z.log`.
Generated output: `build/eye_scan_v1_topology_wrappers/`.

`apply_eye_scan_initialization.tcl` is the intended new-image pre-opt hook.
It refuses every top except `gt_test_eye_scan_v1_top`, checks exact part,
112/28 channel/common inventory, physical ownership and baseline receiver
profile before changing anything. The only GT parameter changes are
`ES_EYE_SCAN_EN=TRUE` and `ES_HORZ_OFFSET=12'h800` (center, unified phase).
It enforces bitstream compression. It is not yet attached to a complete
project, and its successful production path awaits that integration.

The baseline inspector now verifies both property assignments/readback and
restores them in memory on all 112 channels, checks that the initialization
hook rejects the historical v3 top, and rechecks the input DCP hash. **PASS**;
log `build/logs/inspect_eye_scan_baseline-20261113T173456Z.log`; report
`build/eye_scan_baseline_1794591299818105/channels.tsv`.

The existing v3 project's IP health report also passes with no locked cores:
`build/eye_scan_v3_ip_health_20261113T1737Z/`; log
`build/logs/report-ip-health-20261113T173711Z.log`.


## Integrated closeout — 2026-11-13

The integrated target now passes focused/historical regressions, fresh
synthesis, normal routed setup/hold (+0.001/+0.009 ns), and independent audit.
Compressed BIT/BIN and the matching ELF/DCP are verified and frozen. The
operator supports guarded acquisition, cancellation, immutable page
retrieval and offline JSON/CSV/PNG/PDF, with atomic single-byte Gray-sequence
publication across large matrices. See
[the runtime and qualification record](eye-scan-v1-runtime.md).
Hardware qualification is the remaining separate reviewed gate;
`RELEASED=False` and no board action has occurred.
