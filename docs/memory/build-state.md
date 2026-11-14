# VU13P IBERT Build State

Last updated: 2026-11-14

## Resume and operator documentation — 2026-11-14

Eye-scan v1 static implementation is complete; hardware release remains
closed (`RELEASED=False`). No build or hardware worker remains running.
No new board observation or hardware action accompanied this memory update;
the last observed board state is the October 27 all-links v2 state documented
in [project memory](project.md).

Added [the eye-scan how-to](../eye-scan-howto.md), linked from README, HOWTO
and [the runtime reference](../eye-scan-v1-runtime.md). It covers offline
plotting, runtime packaging, future acquisition after hardware release,
JSON/CSV/log/report outputs, retained-job acknowledgement and failure cleanup.
Documented CLI flags and local links were checked; whitespace checks pass.
These documentation changes postdate the frozen candidate source overlay;
the archive remains unchanged.

The candidate archive's `ARCHIVE_SHA256SUMS` independently verifies all 1699
files. Final read-only corrected preflight passes on the exact frozen
synthesis DCP without writing a checkpoint; log
`build/logs/check_eye_final_synth-20261113T204913Z.log`.
The first standalone invocation stopped at its project-file guard; the
existing checkpoint-only mode resolved that invocation error.

Baseline commit is `a82d50b`; eye implementation and subsequent documentation
remain uncommitted. The dated development entries below retain historical
intermediate states; the static qualification closeout supersedes their
earlier lists of missing integration work. Next hardware work requires a
separate reviewed gate; no additional implementation build is pending.

## Eye-scan v1 statically qualified; hardware unreleased — 2026-11-13

Separate target `0x00020503` includes integrated RTL, command/page firmware,
28 local DRP owners, a 4096-point matrix, guarded operator tools and offline
PNG/PDF plots. V2/v3 source and deployment pins remain unchanged. No MCU,
programming, reset, deployment or hardware scan has occurred; release is closed.

The initial full route failed setup at **-0.264/-58.683 ns over 646 clk_200
endpoints**. Hold passed +0.010 ns, 277907/277907 routable nets are complete,
and routing errors/Error DRCs are zero. No audit or bitstream followed.
Its exact 1525 source/implementation inputs were independently hash-verified
and copied before editing. Project, reports, timing triage, logs and input
copies are frozen under
`build/diagnostic_archive/eye-scan-v1-initial-route-timing-failure/`.
Routed/synth DCP SHA-256:
`68da98b17db1e42ae5e1d09ee6e1c2c4a8ab496a48ed8f26654c480e067ac878` /
`79e87d390a8cd4b7b954d34c3841b95eb14ebc707422d44ff78b29492715b6b8`.

Path-guided eye-only changes queue DRP commands before GT launch, register
normal PRBS replies by one cycle while preserving request passthrough, clear
the sampling timer while idle, register selected read pages, register the
local result-copy active/fault bits, and transport matched bank status,
reason and diagnostic payload through two real return stages. The latter
adds two clocks to ready/fault/idle/acquire/capture publication while keeping
the existing tagged TX-session/configuration handshake latency exact.
No clock, ABI, GT profile, FSM encoding or timing exception was changed.

Updated simulations pass: point 49 cases, arbiter 17 scenarios/14 operations
(including queued stale-RDY and queued timeout), real q121 integration,
all-28 bank dispatch, engine and delayed-ACK regressions, and a 160-cycle
comparison against the preserved v3 reducer proving matched status/diagnostic
latency and identical session/configuration timing. Logs are under `build/logs/`
with stamps `190343Z`, `190528Z`, `190529Z`, `190418Z`, and `190633Z`.
All 21 offline operator/plot tests pass on `/usr/bin/python3`; v3/v2 tests
27/15 and all seven unchanged historical simulation runners previously pass.

A fresh project was created from preserved v3. **Normal routed signoff
passes +0.001/+0.009 ns**, zero failing endpoints, all 281988 routable nets
complete, zero routing/Error DRC failures, all 532 skew groups met. Parent
session `89378` exited PASS; entry point
`scripts/build_eye_scan_v1_routed.tcl`; log
`build/logs/build_eye_scan_v1_routed-20261113T190835Z.log`.
Do not start another build in this project. Initial session `96584` exited
at the preserved timing failure. Matching ELF remains
`c9b85dbce9299d50974b660e40778806a4d86d4354a181035a9848e5d42445e7`.
Fresh synthesis/preflight passes, including 1896 status-return registers
and 28 queued launch bits. The added hierarchy-port fanin query encountered
optimized-away aliases, so that query alone is not proof. A separate check
against real primitive D/R/CE pins passes: 17248 point registers, 51744
inputs, 17768 startpoints, zero direct GT outputs. Log
`build/logs/check_eye_registered_synth-20261113T192316Z.log`; synth DCP SHA
`7f3ca87b62ec7f49d9591b837f9a75a09f805afa25c3206972e389dbb2b834c5`.
The routed audit uses this stronger helper. After audited BIT/BIN and verbatim
input/artifact freezing, the obsolete preflight alias query was replaced by
that same primitive helper, future build manifests include that helper, and
copied build labels were corrected. Original
build inputs remain in the archive; working-tree implementation checksums
intentionally differ for these validation/message-only changes. No RTL,
constraints or artifacts changed. Archive-mode audit verifies copied inputs
and artifacts independently. Both variants of the added
same-instance all112-to-sparse regression pass; log stamp `191736Z`.
First audit stopped on reset fanout ownership; its reports/verifier are
preserved under `build/eye_scan_v1_audit_attempt1_reset_ownership_failure/`.
Focused proof finds exactly one diagnostic-R and one second-stage-D alias,
with equivalent bank release waveforms, preserved target SLR/local quad
fanout, and passing ordinary setup/hold. Candidate DCP is unchanged.
See `docs/eye-scan-v1-runtime.md` for exact proof and evidence.
Full independent audit passes; log
`build/logs/audit_eye_scan_v1_routed-20261113T201846Z.log`.
Compressed BIT/BIN emission and exact payload/header verification pass.
Candidate pins are populated; `RELEASED=False` remains enforced. Exact
artifacts, 1526 copied inputs, reports, runtime bundle and source overlay are
frozen under `build/diagnostic_archive/eye-scan-v1-0x00020503-static-candidate/`.
BIT SHA `e170ead04e42c662e4a711c156a048e22da3c7c280e6820a6e644daec5b2850f`;
routed DCP SHA `af25ba8aa3f5d04437af04f854631b2605b005355bd5f5399f4e7f5157e40873`.
A host-only Gray-sequence/single-byte publication fix prevents torn request
words during thousands of page fetches; five 4200-command tests cover byte
carry boundaries. No hardware action has occurred. See the runtime document
for artifact hashes, narrow timing margin and reset ownership proof.

## Eye-scan point sequencer and topology — 2026-11-13

Added `eye_scan_point`: 23-word snapshot, initialized/idle preflight,
readback-verified configuration, bounded LPM/DFE raw sampling, latched cancel,
stop/WAIT and verified restoration before release. Supports the inspected
80-bit/internal-width-2/RXOUT_DIV=1 profile; other profiles are rejected by
caller-supplied verified eligibility. Raw DFE pairs retain separate counts
and denominators, including prescale 31. Unread results block overwrite.
Fatal transport/restoration failures retain ownership or port quarantine.
The arbiter now holds a timed-out command bundle stable for late completion.

Point+arbiter simulation passes **49 cases**, including all 23 configuration
write cancellation boundaries. The original arbiter regression passes 15
scenarios. Final point OOC synthesis passes (950 LUT/649 FF/zero DSP/BRAM,
no latches, five encoded state bits); updated arbiter synthesis also passes.
OOC timing is diagnostic, not image sign-off. Final logs:
`run_eye_scan_point_sim-20261113T173511Z.log`,
`synth_eye_scan_point-20261113T173512Z.log`,
`run_eye_scan_drp_sim-20261113T173011Z.log`,
`synth_eye_scan_drp-20261113T173513Z.log` under `build/logs/`.

Generated 28 independent `_eye_v1_topology` wrappers exposing EYESCANRESET;
inverse byte comparisons and syntax checks pass. Output is ignored
`build/eye_scan_v1_topology_wrappers/`; vendor originals are unchanged.
Added a new-top-only initialization hook for ES_EYE_SCAN_EN and centered
unified phase, with compression enforcement. Both properties set/read back
and restore in memory on the exact v3 synthesis DCP; the hook rejects that
historical top and the baseline DCP hash remains unchanged. Log:
`build/logs/inspect_eye_scan_baseline-20261113T173456Z.log`.
Existing v3 IP health inspection passes with no locked cores; reports are
under `build/eye_scan_v3_ip_health_20261113T1737Z/`.

There is no integrated eye image/ELF, release, deployment or hardware action.
Remaining: separate top/SLR/quad integration, global BER/config exclusion,
grid/session budgets, firmware/result ABI, host tooling and full build/audit.
See `docs/eye-scan-plan.md` for interfaces, status bits and exact evidence.

## Separate eye-scan image started — 2026-11-13

Committed the complete pre-eye v3 state as `a82d50b` (`Add statically
qualified all-links v3 runtime quad control`); all 27 offline v3 tests pass.
The recovered plan and implementation boundary are in `docs/eye-scan-plan.md`.
Added isolated `eye_scan_drp_arbiter` and its XSim runner/testbench. Initial
simulation passes 15 scenarios / 13 scan operations: normal-client draining,
exclusive per-lane commands, response backpressure, restoration ownership,
conflicts, deadline-edge reply, timeout quarantine and late replies.
Log: `build/logs/run_eye_scan_drp_sim-20261113T154852Z.log`.

Added a hash-pinned read-only v3 synthesis-checkpoint inspection script for
all 112 receiver/eye profiles and in-memory eye-enable property readback.
Checkpoint inspection passes on all 112 channels: 80-bit port, internal-width
encoding 2, constant LPM mode, eye circuitry disabled. Vivado accepts and reads
back the temporary eye-enable property, which is restored before closing the
design; input DCP hash is unchanged. Report:
`build/eye_scan_baseline_1794584950748058/channels.tsv`; log:
`build/logs/inspect_eye_scan_baseline-20261113T154858Z.log`.
Standalone arbiter synthesis passes: no latches, two original state bits,
68 FDREs, zero errors/critical warnings. Log:
`build/logs/synth_eye_scan_drp-20261113T155141Z.log`; reports:
`build/eye_scan_drp_synth_1794585104891920/`. OOC timing is not image sign-off;
small-design parallelism and missing OOC clock-location warnings are retained.
There is no new eye image, ELF, ABI, artifact pin, release or hardware action.
Existing v2/v3 source behavior and
qualified artifacts remain preserved. Next: separate topology/initialization,
point sequencer/restoration, global integration and firmware/host interface.

## V3 bench convenience scripts — 2026-11-10

Added `enable_all_links_v3_inter_fpga.py`: configure TX/RX q221–q234 at
both sites, FireFly masks zero; optional `--test` adds timed bidirectional
external PRBS31 (54 fitted receivers per endpoint).
Added `test_all_links_v3_firefly_loopback.py`: configure/test four external
FireFly optical self-loop quads per site, default q121–q124, independently
selectable with `--f1-quads/--f2-quads`. Requires FireFly acknowledgement;
`--configure-only` skips PRBS/testing. Both replace full masks and default
test duration to 90 seconds. Paired preflight precedes any mask write;
partial application fails without retry/rollback or starting a test.

The common v3 CLI keeps one software lock and one log/report across preset
configuration and testing. All release, identity, predecessor, clock and
cleanup guards remain. Runtime packager/manifest now includes seven files;
new local bundle `build/all_links_v3_runtime_bundle_1794344913552735/` is
hash-verified. 27 offline tests and Python 3.6 grammar checks pass. The
previous qualification archive/runtime bundle remains frozen. No RTL/image,
release-flag, deployment, programming or hardware change accompanied this work.
Usage: `docs/all-links-v3-runtime-control.md#convenience-launchers`.

## All-links v3 static qualification PASS — 2026-11-10

User-approved runtime control is implemented on
`feature/all-links-v3-quad-control`, based on preserved commit `34c73bb`.
Independent 28-bit TX/RX masks per FPGA default to zero and change only
between tests, after controller cleanup, confirmed session stop and snapshot
completion. TX disable asserts electrical idle; RX disable quiesces checking.
Fully disabled quads are isolated from operational health; raw faults remain.
Historical source, v2 deployment pins and four archived v2 hashes are intact.

V3 `0x00020502` has separate RTL, firmware/project/topology derivation,
constraints, independent audit and fail-closed bench tools. Configuration
command 4, F7 status and raw quad pages 80–9B preserve the existing ABI.
Low/high/low rearm, tagged TX session barriers, SLR-local ACK banks and 160
real management return registers cover stopped clocks and cancellation.

Fresh synthesis/preflight, normal implementation and independent routed audit
PASS. Setup/hold **+0.036/+0.009 ns**, zero failing endpoints;
**227,324/227,324** nets routed, zero routing/Error-DRC failures;
**532/532** skew groups. Exact 112/28/12 GT inventory and 6/8/8/6 physical
control/reset residency pass. One RTSTAT-10 warning covers eight optimized
nets without loads. Compressed BIT/BIN emission passes; BIN exactly matches
the complete 69,360,720-byte compressed BIT payload.

Frozen evidence and artifacts:
`build/diagnostic_archive/all-links-v3-runtime-quad-control-static-pass/`.
Its manifest and relative SHA256SUMS cover artifacts, source snapshot,
reports/logs and pinned runtime bundle. Artifact hashes:

- BIT: `60c8311daabf487184672bf987773fbb6fd808bb7e070fde4588854e40d40ed1`
- BIN: `b04bff257ecdd9d3aeb6d1a63a94a1fa0e4bc7cdcb856b7bac66b5e9d54fcf10`
- Routed DCP: `ca56c79ccc90b5cf67e6d85d982238b2c3d03997b79fe45d7eccd100354fb684`
- Synth DCP: `4cdc33364e0e53819f53a9557a4ba333b8158e7b00dd5ac6d53d58d29c1322df`
- ELF: `c8b1e6c53d9649c0fda090384944d1b9165607c58fe95d1c66065a1db9753911`

Four focused simulations, 21 offline v3 tests, seven historical simulation
runners and 15 unchanged v2 operator tests pass. The vendor XPM repeated-
instance assertion reproduction and independent 448-chunk monitors are
recorded in `docs/all-links-v3-runtime-control.md`. The unchanged direct
firmware test's v10/v12 version expectation mismatch is also documented.
Superseded failed synthesis/routes and one-off rebuild helpers remain in
ignored diagnostic archives; no historical build attempt was repeated.

Final local runtime bundle:
`build/all_links_v3_runtime_bundle_1794341646157111/`.
It contains five runtime files plus their manifest and artifact pins;
`RELEASED=False` still blocks writes. No programming, deployment, reset,
MCU access or hardware test occurred. Last observed hardware remains the
October 27 v2 state below, without fresh readback during this work.

## Build output update — 2026-11-09

Golden project creation enables `STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE`, and
the synthesis-continuation flow sets it on the existing implementation run.
Both build entry points require nonempty `top.bin` alongside `top.bit` in
`build/vu13p_ibert_25g.runs/impl_1/`. The standard and timing-hardened
control-boundary all-links v2 checkpoint writers now use
`write_bitstream -bin_file`, reject an existing BIT or BIN, and require a
nonempty sibling BIN. The hardened writer prints both SHA-256 hashes.
Compression and existing checkpoint/audit gates are preserved. No FPGA build,
artifact regeneration, programming, or hardware test accompanied this edit.
Validation: Tcl completeness and `git diff --check` pass. Vivado 2023.2.2
accepted and read back the BIN_FILE run property in a temporary empty project;
its installed `write_bitstream` help confirms `-bin_file` emits BIN in addition
to BIT. Log: `build/logs/verify_vivado_bin_option-20261109T154049Z.log`.

On the user's subsequent request, BIN files were extracted directly from the
existing historical golden BIT, compressed golden BIT, and exact audited
timing-hardened all-links v2 BIT. Outputs are under
`build/configuration_bins_20261109/`, with `manifest.json` recording source
paths, source/output SHA-256 hashes, BIT header metadata and payload offsets,
and `SHA256SUMS` listing the BIN hashes. Each BIN was verified byte for byte
against the complete source configuration payload, and all source BIT hashes
were rechecked unchanged. Only container headers were removed; no byte/bit
swapping or padding was applied. The historical golden remains uncompressed;
the other two retain their original compression. No synthesis, implementation,
checkpoint re-emission, programming, or hardware action was performed.

| BIN under `build/configuration_bins_20261109/` | Bytes | SHA-256 |
| --- | ---: | --- |
| `golden_ibert_historical.bin` | 113,318,376 | `1b3a7c0148cfba2813c29b5a3be4f362a42e3325144c8774795ad34e7f689087` |
| `golden_ibert_compressed.bin` | 70,389,172 | `5563fb5ef3eeac7801bd9161873e992a410102cfdc34da827b441f2db3afbd74` |
| `all_links_v2_timing_hardened.bin` | 70,100,232 | `8dd5ec7d1b0de9508c9ee30aac3efd678e0c2a285393c6b85dbc27a31fb87add` |

All three pass `sha256sum -c SHA256SUMS` from that output directory. README
links the generated files and manifest; they remain ignored by Git. Existing
BIT-based deployment pins are unchanged.

## Resume summary and current limits

The last live observation is the **2026-10-27** post-test status, not a new
hardware read on October 28. Apollo 3010 F1/F2 both run audited all-links v2
`0x00020501`, healthy IDLE/session-off `0x00100000`, sequence/ack **3**, run
**1**, summary `0x00363601`, with required clocks valid. The three-minute
direct test passed 54/54 fitted receivers/site with zero errors/native losses
at about 4.64055e12 bits/lane. No further agent-issued hardware action has been performed
for the script, documentation, presentation or memory updates. Recorded
sequences1--3/run1 remain consumed; do not replay the archived launcher.

**Deployment gap:** the actual remote v1.0.3 bundle is
`/tmp/all-links-v2-status-v103-20261027`. It still contains the runtime used
for the measured, explicitly guarded test. Automatic sequence/run discovery
is implemented and tested **only in the local repository**, not deployed or
hardware-tested. `/home/cms/25G-v1.0.3` in the HOWTO/slides is a proposed
persistent installation path, not a completed deployment. The ordinary
workstation wrappers still pin v1.0.0 and use the old SSH-jump defaults.
Preserve the archived v1.0.3 wrapper; its consumed run command is not a tool
for starting another test. Use direct SSH to the blade when on lnx4189.

The user prefers v1.0.3 (`64260cf23b01c9da987feda1fbf51567240c2c71`), rejects
manual sequence bookkeeping, and correctly identified raw MCU DONE pins as
**active low** (bit0 F1, bit1 F2). Programming is initial setup only when the
correct healthy image is not already loaded, not a prerequisite to every
test. Programming the exact BIT with Hardware Manager includes the embedded
MicroBlaze ELF in BRAM initialization data, just as XSDB programming does.

## Documentation and presentation delivered

`HOWTO.md` now opens with the simplified direct-on-blade 180-second command
and recorded results, then covers deployment, FireFly quad sets, optional
explicit state guards, logs and cleanup. It distinguishes all112 TX enable
from selected RX measurement. The direct CLI still uses fixed 54-receiver
fitted masks/site; arbitrary 2xx or mixed-quad selections are not implemented.

The user requested a talk for LHC physicists and engineers. Current artifacts:

- `docs/presentations/vu13p_25g_project_talk.pptx` / `.pdf`: **28 slides**;
  early how-to on slides2--4, actual results on slide5, editable FPGA
  firmware block diagram on **slide9**, three technical backups at the end.
- `docs/presentations/vu13p_25g_project_talk_speaker_notes.txt` and
  `docs/presentations/assets/`: notes and standalone BER/telemetry plots.
- `docs/presentations/make_project_talk.py` plus its README: reproducible
  generation from the archived hardware log. All slide numbers/notes/shape
  bounds were checked; PDF and diagram were rendered and inspected.
- `docs/fpga-firmware.md` and `docs/fpga-firmware-block-diagram.{svg,png}`:
  standalone diagram. It shows I2C directly accessing the hardware mailbox,
  a 200-MHz MicroBlaze / 32-KiB BRAM subsystem, AXI and IRQ/Wakeup, parallel
  measurement/result logic, 28 quad controllers and 112 GTYs.

The live-test result predates the automatic-counter CLI change; document the
hardware pass and the later offline-tested interface as separate evidence.
No commit was made. The working tree includes these deliverables and source
changes; leave unrelated `.agents/` files alone.

## Operator script update: automatic sequence/run discovery

Following the user's interface review, both timed test CLIs and their
workstation wrappers now allow sequence/run arguments to be omitted. The test
process reads coherent idle snapshots while owning the MCU lock, rejects
pending/busy/faulty/version-mismatched state, logs actual `PREDECESSOR` values,
and retains readiness and sequence checks before submission. All four legacy
arguments remain optional explicit state guards for automation. Reports record
the discovered starting values. A normal unguarded reinvocation is a new test,
not an exactly-once retry. All **15 focused offline tests pass**, including
state-change/busy/fault rejection, CLI forwarding, optional guards and report
starting-state capture. Changed runtime scripts pass Python-3.6 grammar checks;
documented shell examples parse. The source change did not deploy files or start a hardware test;
the last measured state remains sequence/ack3/run1 as recorded below.

## Current hardware update: Apollo 3010 F1 and F2 reprogrammed

On 2026-10-27 the exact audited all-links v2 BIT and matching ELF hashes were
verified, and the fixed `all_links_v2_f1` programmer loaded F1 on Apollo 3010.
Fresh XVC enumeration at `apollo3010-1:2542` showed exactly two `xcvu13p`
targets, and the programmer emitted `PROGRAM_F1_COMPLETE`. The programming log
is `build/diagnostic_archive/firefly1-all-links-v2-F1-program-1793110477206097.log`.
The prior four-device enumeration came from an older `hw_server` session that
had connected to blade 3017-1; it was not used for programming.

Using a clean `cm_interface` v1.0.3 checkout for read-only verification, F1
reported firmware/hardware `0x00020501`, healthy IDLE/session-off at
sequence/ack 0, run 0, and valid clock status `0x434DA501`. Its required
200/100/325-MHz fabric clocks and twelve managed-GTY reference clocks were in
range. At that point F2 was unconfigured: its generic I2C address did not
acknowledge and MCU raw FPGA DONE was `0x02`. These signals are active low.

The user then authorized F2 programming and read-only checks. The fixed
`all_links_v2_f2` programmer selected target 4 after checking exactly two
`xcvu13p` devices and the pinned BIT/ELF hashes. It reported
`PROGRAM_F2_COMPLETE` and a running F2 MicroBlaze, then XSDB aborted during
shutdown with `Tcl_FindHashEntry on deleted table` (exit 134). No programming
retry followed. Evidence is
`build/diagnostic_archive/firefly1-all-links-v2-F2-program-1793111080326955.log`.

Independent read-only verification passed using clean `cm_interface` v1.0.3,
commit `64260cf23b01c9da987feda1fbf51567240c2c71`, over direct SSH from
lnx4189 to `cms@apollo3010-1`. Both sites report firmware/hardware
`0x00020501`, healthy IDLE/session-off `0x00100000`, sequence/ack/run 0/0/0,
valid clock status and all required fabric/managed-GTY reference clocks in
range. MCU runtime DONE `0x00` confirms both configured (active low). Full
telemetry completed: 12-V input 11.960938 V / 15.906250 A / 190.253662 W;
F1/F2 diode temperatures 50.5625/46.09375 C; all 28 LGA80D temperature reads
and six physical FireFly module temperatures were finite. The complete log is
`build/diagnostic_archive/all-links-v2-readonly-v103-after-F2-1793111080326955.log`.
The user then authorized one 180-second inter-FPGA PRBS31 test, expressly
requested `cm_interface` v1.0.3, and confirmed equipment connected to all
outward FireFly outputs can safely receive PRBS31. The unchanged released test engine ran via
a separate wrapper that pins clean v1.0.3/tag/commit, verifies runtime hashes,
and uses direct SSH to the temporary bundle under
`/tmp/all-links-v2-status-v103-20261027` on Apollo. Both sites passed all 54
fitted receivers with zero errors/native lock losses over about 4.64055e12
bits per lane. Both session stops completed; final independent status confirms
healthy IDLE/session-off, sequence/ack 3, run 1, summary `0x00363601`, and valid
required clocks. Sequences 1--3/run 1 are consumed; do not replay them.

All four telemetry snapshots completed: power 189.943/207.787/207.499/208.246 W
(the immediate post-stop ADC sample was not yet settled), peak sampled F1/F2
diodes 52.656/48.031 C, LGA80D 51.375 C, FireFly 45 C. Final settled status
read 189.226 W and F1/F2 diodes 50.406/46.844 C. No retry/reset/reload followed.
The released user-facing launchers retain their v1.0.0 pin; the v1.0.3 override
is scoped to this explicitly authorized run. Evidence:

- `build/diagnostic_archive/all-links-v2-timed-inter-fpga-180s-1793111744850372.log`
- `build/diagnostic_archive/all-links-v2-timed-inter-fpga-180s-1793111744850372.report.md`
- `build/diagnostic_archive/all-links-v2-timed-inter-fpga-180s-1793111744850372.launcher.py`
- `build/diagnostic_archive/all-links-v2-timed-status-1793113074559486.log`

Historical run-5 state below predates these reloads and this new run.

## Current development: all-links v2 timing-clean build candidate

All-links v1's all-28 acquisition/capture AND reductions strand direct-only
requests while unselected FireFly controllers remain IDLE.  V2 assigns the
distinct identity `0x00020501` and derives a 28-bit quad-participation mask
from the accepted lane descriptor.  Its 6/8/8/6 bank slices are registered
with existing controls; only acquisition/capture are neutral for unselected
quads.  Global ready/fault/idle/reset/session barriers remain all-quad.
The image manages all 112 25.78125-Gb/s lanes: globals 0--55 are the 56
FireFly lanes in q121--q134, and globals 56--111 are the 56 direct
FPGA-to-FPGA lanes in q221--q234. It contains no IBERT and excludes the
10-Gb/s AXI C2C lanes.

Integrated direct-only, sparse, all112, settle, barrier and changed-epoch
tests and all requested historical regressions pass.  Fresh clean synthesis
and preflight pass exact 112 channels, 28 commons, 12 managed REFCLKs, 28
controllers, 112 engines, 28 participation regs, CDC/session/descriptor and
bus-skew inventories.  Synth DCP/ELF hashes are `e1a8a3a2...00a71` and
`d947fd47...30f9c`.

The one normal route is physically clean but signoff setup fails
-0.158/-26.399 ns over 580 endpoints in 18 clock groups (`clk_200`: 122;
RXOUTCLK group 4: 366; sixteen other RX groups: 1--39 each).  Hold is +0.010
ns with no failure; 212,076/212,076 nets route cleanly, zero Error DRCs, and
28/28 bus-skew groups pass.  Routed DCP hash is `ec0de1a6...0f9c`.  This broad
failure is not the reviewed narrow route-dominated case, so no extra
post-route physopt, audit or bit followed.  Evidence is frozen under
`build/diagnostic_archive/all-links-v2-0x00020501-normal-route-timing-failure/`.
That failed-route artifact had no final BIT pin or live programming choice and
was never programmed.

One subsequent hash-pinned incremental close attempt reused the exact audited
v1 routed DCP against the frozen v2 synthesis DCP.  Its read-only compatibility
gate reported 98.94% cell reuse and 97.08% net reuse.  Placement passed the
reviewed bank/locality gate at setup WNS/TNS -0.770/-3.982 ns over 11 endpoints
and hold -0.080 ns over 21.  The sole default `phys_opt_design` improved
estimated setup to +0.001 ns, but the following sole `route_design` still
failed signoff setup at -0.119/-5.883 ns over 93 endpoints, all in `clk_200`.
Hold passed at +0.005/0.000 ns with zero endpoints; 212,112/212,112 nets are
fully routed with zero route errors, zero Error DRCs, and 28/28 bus-skew groups
met.  Routed reuse remained 98.94% of cells and 97.08% of nets.  Routed DCP
SHA-256 is `6fd5e2b102f7b2fc79e4868adc66b7fca4cb737c7aa4989ff21ef74c6dc91824`;
evidence is frozen under
`build/diagnostic_archive/all-links-v2-v1-incremental-timing-close-attempt-retry2/`.
No extra post-route physopt, retry, audit, bitstream, or hardware action
followed.

The successful timing-hardening strategy is source-level and v2-only: four
registered result-copy banks replace the central 112-to-1 mux, each 256-bit
snapshot transfer is split into four 64-bit handshakes, and each quad receives
a cycle-matched local reset release. Exactly the existing eight control/reset
boundary registers per SLR are hard-contained. Copy-bank placement stays soft;
the audit records its actual distribution rather than imposing non-functional
residency. Focused v2 plus requested historical regressions pass. Fresh
synthesis/preflight passes exact 112/28/12 topology, 28 controllers, 112
engines, four result banks, 1024 data plus four valid copy-stage registers,
28 per-quad reset registers, and the split-snapshot inventory of 28,672
payload registers and 448 capture enables with fanout 64.

The focused normal implementation is signoff clean: setup WNS/TNS is
+0.046/0.000 ns, hold WHS/THS is +0.009/0.000 ns, and both have zero failing
endpoints. All 220,150 routable nets are fully routed, routing and Error DRC
counts are zero, and 476/476 bus-skew groups meet. A fresh-process independent
audit passes exact topology, GT properties, CDC, descriptor/session/barrier
semantics, strict physical participation 6/8/8/6 and strict physical
per-quad-reset residency 6/8/8/6. The diagnostic result-copy distribution is
SLR0 bank 24/233 in SLR0/SLR1, while the other three banks are fully resident
in SLR1/SLR2/SLR3 respectively; this is reported, not gated.

Compressed BIT/routed-DCP/synth-DCP/ELF SHA-256 values are
`163172d938f5aa87fd606061e75e058f5d7040916d86d4744a206309f970b66f`,
`323ff58252ae66a81e42c84d38b528ce053561804cdc7eeecb99d3066107993a`,
`a914ff24b3a9e9a106ff92a6276ce2c0842df701112c420e65e4c61e1847b8f9`,
and `d947fd47e684a1e0be08296d34b4de1b1e28d7c056ecabffcbfb681786730f9c`.
Evidence is frozen under
`build/diagnostic_archive/all-links-v2-timing-hardened-control-boundary-clean/`.
The concise strategy/failure record is
`docs/all-links-v2-timing-strategy.md`.
The exact audited DCP alone produced the compressed bit; no rebuild or reroute
occurred during bit generation.

Two hash-verified timed test procedures (90-second default) are released for
reviewed use: a simultaneous bidirectional inter-FPGA
external PRBS31 test of the 54 fitted receive lanes at each endpoint, and a
dual-endpoint FireFly external optical-loopback test with q121--q134
single/range receive selection. Both validate and log all 37 FPGA clock
counters before starting,
require the 200/100/325-MHz fabric clocks and all twelve 322.265625-MHz GT
references, and record pre/one-third/two-thirds/post telemetry: 12-V ADC power, both FPGA
diode temperatures, both temperature sensors on both pages of all LGA80Ds,
and all physical FireFly module temperatures. The direct test requires an
explicit acknowledgement that the v2 full-mask TX-session ABI drives all 112
transmitters; the FireFly selector limits measured receivers, not active TXs.
The launchers are now named `board_all_links_v2_inter_fpga.py` and
`board_all_links_v2_firefly_loopback.py`; `_90s` was removed because duration
is configurable and 90 seconds is only the default. Every completed test
process, including a failure, creates an exclusive sibling `*.report.md` with
the outcome, exact command and artifact/library hashes, clock and lane
summaries, telemetry extrema, evidence SHA-256, and failure tail. The raw log
remains authoritative and report generation never retries hardware.
The maintained Apollo bundle is `/home/cms/25G`; its `cm_interface` is pinned
to clean tag v1.0.0/commit `8e56fdf24c038b64f69f26b55f0facb7c77e0537`,
and deployment verifies both tag and commit without overwriting a mismatched
present checkout.
The seven-file remote runtime bundle was copied into `/home/cms/25G` and
independently SHA-256 matched to the local sources on 2026-09-20. The remote
library was clean at the required tag/commit. This sync performed no FPGA
programming, reset, mailbox request, or hardware test.
The first 180-second direct gate failed without retry: F1 passed all 54 fitted
receivers; F2 passed 53/54, while global98/q231 saturated errors at
`0xffffffff` with zero native lock losses. Both sites stopped cleanly and that
gate remains consumed. The user then authorized a board power cycle, exact
image reprogramming, and one fresh 180-second retest. It passed 54/54 fitted
receivers at both endpoints with zero errors and zero native lock losses;
global98 passed with about 4.64e12 tested bits. Both sites are now
IDLE/session-off at seq/ack3, run1, with no retained platform fault and valid
required clocks. The second gate's sequences1--3/run1 are consumed. This
supports a transient board/startup-state explanation but does not determine
the first failure's root cause. See
`docs/all-links-v2-inter-fpga-hardware-gate.md`.
The cold-start programming pass showed that exact `all_links_v2_f2` can be the
second bare FPGA at JTAG target 2 or target 4 after F1 debug children appear;
its programmer accepts only those two positions while retaining the exact
two-FPGA/F1-target-1 chain guard.

FireFly q121--q123 external-loopback run3 failed the zero-error criterion on
F1 lanes 1/3/4/6 (83/391/309/5 errors) and F2 lane4 (3 errors). One explicit
user-authorized 90-second repeat, run4, failed the same four F1 lanes with
104/400/306/15 errors while F2 passed 12/12. All lanes remained selected and
locked with zero native lock losses over about 2.320e12 bits/lane. Cleanup
passed; current F1/F2 are healthy IDLE/session-off at seq/ack12, run4, no
platform fault, valid clocks. The repeat is consumed and no further retry is
authorized. Its raw log and generated report are
`build/diagnostic_archive/all-links-v2-timed-firefly-q121-q123-90s-1789945308268594.{log,report.md}`.
The user confirmed q121--q124 are independently self-looped on both F1 and F2,
so both endpoints are valid same-board optical-loopback measurements; neither
represents an F1-to-F2 direction.
One subsequent authorized 90-second q121--q124 run5 found q124 clean at both
endpoints. F2 passed all 16 lanes; F1 again failed only lanes 1/3/4/6 in
q121/q122, with 56/172/84/10 errors. Q123 and q124 were clean, all lanes stayed
selected+locked, and native losses were zero over about 2.320e12 bits/lane.
Cleanup passed; current F1/F2 are healthy IDLE/session-off at seq/ack15, run5,
no platform fault, valid clocks. The run is consumed. Evidence is
`build/diagnostic_archive/all-links-v2-timed-firefly-q121-q124-90s-1789950159117782.{log,report.md}`.

## Historical development: all-links v1

New symmetric identity `0x00020500` manages all112 25G lanes: FireFly
q121--q134 as globals0--55 and direct q221--q234 as globals56--111. Static,
aggregate/session-ack, fresh all112 and subset engine, generated-IP/topology,
firmware, project-recipe, RTL-elaboration, same-instance changed-mask re-arm,
and clean synthesis/preflight gates pass. Synthesis proves
112 channels, 28 commons, twelve managed-GT physical REFCLK buffers, no
IBERT/C2C, and one matching ELF. Firmware ELF SHA256 is
`96d3ab54...78ae`. Two clean routes completed with zero failed nets/DRC errors
but failed signoff setup: baseline WNS/TNS -1.277/-1517.198 ns and a reviewed
hard 6/8/8/6 whole-wrapper pblock experiment -1.412/-3535.183 ns. Their
clk_200 subsets were -0.978/-1406.601 ns and -1.412/-2888.379 ns respectively;
hold passed in both. The experiment was reverted after evidence was frozen
under `build/diagnostic_archive/all-links-v1-hard-pblock-timing-failure/`.
A third enumerated-leaf locality attempt passed exact synthesis preflight but
failed its mandatory post-placement containment gate: 506 real optimized
leaves in 13 canonicalized hierarchy roots escaped their expected SLR. It
stopped before phys-opt/route at an estimated WNS of -1.240 ns. Placed DCP
SHA256 is `22104945...b140`; evidence is under
`build/diagnostic_archive/all-links-v1-enumerated-leaf-locality-attempt/`.
Its pblocks and the conflicting final-reducer advisory were reverted. A fourth
synthesis-preserved controller-root attempt passed exact fresh
synthesis/preflight/post-opt and improved placed WNS to -1.089 ns, with all 28
bus-skew groups met. Its mandatory containment/exclusion gate nevertheless
failed: 257 real leaves escaped across five mixed roots and the four local
reducers contained ten excluded `tx_session_applied` primitives. It stopped
before standalone phys-opt/route. Placed DCP SHA256 is `9b3844ae...0e9e`;
full evidence is under
`build/diagnostic_archive/all-links-v1-keep-hierarchy-locality-attempt/`.
The experimental synthesis property/XDC and locality pblocks were reverted;
only proven control/descriptor pblocks remain. Fresh post-revert synthesis and
structural checks pass with zero controller `KEEP_HIERARCHY`/`DONT_TOUCH`;
canonical DCP SHA256 is `7a65ce41...d488b`.

The next reviewed lean experiment is now the active all-links source: four
explicit bank roots own 6/8/8/6 quads, each with one seven-output control
pipeline, one initialized-low one-cycle reset-release register, its wrappers,
and one local reducer. Focused reset/session/packing plus all existing all-links
and historical regressions pass. Fresh nonincremental synthesis/preflight
passes exact 112/28/12 GT inventory, 28 controllers, 112 engines, 28 request
and return session chains, 28 bus-skew groups, controls 7/7/7/7 and local
resets 1/1/1/1. Synth DCP SHA256 is `409a7a24...12ace`.

The original handling of its single clean implementation stopped at the
mandatory placement gate.
`controls_out_reg[1]` was optimized away in all four banks, leaving controls
6/6/6/6 plus resets 1/1/1/1, and 47 controller/reducer leaves crossed their
expected SLR. Surviving boundary registers were local and all 28 bus-skew
groups met. Diagnostic placed setup was WNS/TNS -0.511/-3.798 ns over 48
endpoints, hold -0.219/-9.499 ns over 192 endpoints, with no significant
global-POR/reset endpoint. Placed DCP SHA256 is `2ce01589...1f439`; evidence is
under `build/diagnostic_archive/all-links-v1-slr-bank-attempt/`. The old gate
was too strict: bit 1 feeds only constant-disabled wrapper runtime detectors,
the 112 lane engines retain global measurement control, and fanout proves all
47 crossings are publication-only with no controller feedback. The corrected
placed gate passed. One default phys-opt/route from the exact DCP completed:
phys-opt estimated -0.117/-1.677 ns; route has 212,246/212,246 fully routed
nets, zero routing errors/unrouted/partial/overlap, zero Error DRCs, 28/28 skew
met, and hold +0.010/0.000 ns with zero failures. Only clk_200 setup fails at
-0.034/-0.343 ns over 22 endpoints; all other clock groups pass. Routed DCP
SHA is `4631ff396e6b18baf61a312c6beaa7d77b00f6ba267830c40367a163a222a974`;
evidence is in `all-links-v1-slr-bank-closeout-continuation-retry1`. A reviewed
closeout used only that exact routed DCP and invoked one plain
`phys_opt_design`, without reroute/directive/retry. Setup/hold closes at
+0.001/+0.010 ns with zero failing endpoints; 212,249/212,249 routable nets,
zero route errors/Error DRCs, and 28/28 skew pass. A fresh-process independent
audit passes exact topology, GT properties, CDC/descriptor/session, and
bank/reset inventories. Compressed BIT/DCP/ELF hashes are
`5cb71e18...e729d`, `a6862fdd...d4c3`, and `96d3ab54...78ae`; evidence is in
`all-links-v1-postroute-default-physopt-attempt`. This is an audited build
candidate only, with no deployment entry or hardware test. External hardware mode
is blocked pending explicit policy because a session can drive all outward
FireFly TXs. Full record: `docs/all-links-v1-source-milestone.md`.

## Current build/hardware: all-direct v12 scoped gate passed

The symmetric all-direct v12 image, FW/HW `0x00020409`, replaces the stale
Wizard-wide post-capture requalification condition with selected per-lane RX
and PMA reset acknowledgements. Updated simulation, compressed implementation,
focused structure inspection, and independent routed audit pass. Signoff
WNS/WHS is +0.019/+0.006 ns; routing and DRC have zero errors; all 14 bus-skew
constraints pass (worst +1.746 ns); all 56 GT channels match golden; and all
14 dedicated REFCLK routes and 112 QPLL0 connections are exact. BIT/DCP/ELF
hashes are `5bce7351...c5697`, `68d0e053...4260`, and `a2370f4b...c163`.
The exact artifacts and cited evidence are frozen under
`build/diagnostic_archive/direct-all-v12-0x00020409-scoped-pass/`; retained
v12 deployment pins resolve only to its `artifacts/` subtree.

Both endpoints were programmed once and independently passed their all-56-lane
10-second PMA sequence/run 1 gates with zero errors and native lock losses.
The single overlapping bidirectional external sequence-3/run-2 measurement
then passed all 54 fitted lanes per endpoint, about 257.808e9 bits/lane, zero
errors and zero native lock losses. Both sequence-4 stops succeeded. Current
F1 and F2 are healthy IDLE at sequence/ack 4 and run 2, state `0x00100000`,
with no retained fault and stable external publications. All stages are
consumed; no replay/reload/reset/later request. Complete record:
`docs/direct-all-v12-hardware-gate.md`.

V11 / `0x00020408` is historical. It passed both PMA gates and produced clean
external publications on both sites, but F1 later timed out in post-capture
cleanup because its Wizard aggregate stayed low despite healthy per-lane RX/
PMA acknowledgements. Its exact artifacts and evidence are frozen under
`build/diagnostic_archive/direct-all-v11-0x00020408-post-capture-aggregate-timeout/`.

## Historical build: v7 all-direct audited, hardware not started

One symmetric `0x00020404` image manages all56 q221--q234 direct 25.78125-Gb/s
lanes (globals56--111), excluding AXI C2C. Firmware and behavioral/structural
regressions pass. Clean synthesis plus compressed implementation and independent
routed audit pass at WNS/WHS +0.060/+0.010 ns, zero routing/DRC errors, all14
descriptor skews met (worst +1.809 ns), all56 channels matching 2,801 golden
non-metadata properties each, and 14 dedicated common routes plus112 exact
QPLL0 common-to-channel connections. Bit/DCP/ELF SHA256 are d16d6be6...a75f,
ff2fedc9...9cc8,fc3d7179...ffb4. No v7 programming or hardware request occurred.
Topology: docs/direct-all-v7-topology.md. Final audit:
build/logs/audit_direct_all_v7_routed-20260917T151915Z.log.

## Historical hardware resume point: v6 direct-quad gate passed

F1N/q222 `0x00020400` and F2I/q233 `0x00020403` are loaded. Final compressed
builds and independent audits pass. F2 bit/DCP/ELF hashes are5a7e5f3d...cfa9,
067782af...a842,ea7d79ac...52a. Complete golden-q233 primitive match repaired
the preserved `0x00020401` X1Y55 no-lock and `0x00020402` lane105 saturated-
error failures. F1 preserved PMA run1 and fresh F2 PMA run1 passed. Two
overlapping bidirectional10s PRBS31 runs2/3 passed all8records, zeroerrors/
native losses. Final both seq/ack5,run3,healthyIDLE,sessionsoff,requiredclocks
valid,no faults; run3 summary00040401 retained. Sequences1–5/runs1–3 consumed;
no replay/reload/reset/later request without new reviewed gate. This is one-
quad category coverage, not all-channel/long BER qualification. Full hashes,
counters, logs, warnings and limitations: docs/v6-direct-quad-qualification.md.

## Historical FireFly chronology

The status labels below were current when recorded. They do not supersede the
latest observed all-links v2 state at the top of this file.

CURRENT CLOSEOUT PASS: F2seq24/run8 clean10s all12PRBS31,000C0C01,zeroerrors/
native losses. FinalF1seq17/run0 F2seq25/run8 healthyIDLE,sessionsoff,clocks
valid,disablemasks0000. start-closeout consumed,no further test pending.
MCU implementation OUT OF SCOPE; channels already qualified,no requalification
or new soak. Fresh-request reuse shown, not automatic in-run recovery.
docs/firefly1-v5-closeout.md supersedes all earlier hardware states below.

LATEST: alarm observation COMPLETE. Clean all12seq20/run6 baseline PASS,
then seq21/run7 TX02 interruption recorded RX02 moduleCDRLOL004 at1/5/9s;
FPGA native losses0, lane9errors saturated,11 neighbors clean. LOS000 cannot
exclude event under polling. Restoredmask0000, sessions stopped, final
F1seq15/run0 F2seq22/run7 healthyIDLE. No post-second-interruption baseline.
start-alarm consumed, no replay/reset/reload. docs/firefly1-v5-alarm.md.

LATEST after hour: TX02 disturbance completed but heuristic RSSI mapping gate
failed/inconclusive (935.5→532.9uW, not <25%). X0Y13 alone saturated errors;
11 neighbors clean, all native losses0, summary010B0C01/run5. Exact original
module mask restored; both sessions stopped, F1seq13/run0 F2seq18/run5 healthy
IDLE. start-loss consumed; no recovery baseline/retry/reset. Full evidence and
interpretation in docs/firefly1-v5-loss.md. This supersedes states below.

LATEST: hour soak PASSED, all12 zero errors/native losses, ~92.81e12 bits/lane,
F1seq11/run0 F2seq15/run4 healthy IDLE/sessions off. Running notes below are
historical. Next authorized/reviewed single TX02 interruption uses fixed
loss stages in approved launcher; docs/firefly1-v5-loss.md records protocol.

ONE-HOUR SOAK RUNNING (supersedes idle states below). User authorized1hour;
newfixed start-soak1h consumed. Apollo workerPID108549,remote
/tmp/firefly1-v5-soak1h-20260916, ownsMCU andautonomouscleanup. F1session10,
F2session13,RXrequest14 expectedrun4. ConfirmedRUN00120002,ack13,publishedrun3
at epoch1789596622.695; expectedmeasurementend1789600223 pluscleanup.
Both65minleases, no renew/retry. Monitor via approvedlauncher status-soak1h
(log-only); do NOT run concurrentUART accesses or programming. Fullprotocol
and evidence docs/firefly1-v5-soak1h.md. No finalPASS yet.

LATEST ALL12 PASS: two distinct10s F1→F2PRBS31 measurements,maskFFF,
F2seq8/run2 andseq11/run3,normal000C0C01,all12 zeroerrors/native losses.
Includespreviouslyexcludedlane9/X0Y13. FinalF1seq/ack9run0,F2seq/ack12run3,
bothhealthy IDLE,C8=00100000,PRBSsessionsoff,no faults,requiredclocksvalid.
All12 start/repeat consumed,no replay/reload/build/drivechange. See
docs/firefly1-v5-all12.md for counters/logs. Longer soak notstarted; nextplan
is separatelyreviewed longeronewaysoak,notfullqualificationyet.

Historical eleven-lane gate:

CURRENT FOLLOW-UP PASS: both TXsessionseq4, observationalRSSI1/5/10/20s,
then F2receive seq5/run1 maskDFF10s passed000B0B01. Eleven lanes zeroerrors/
nativelosses;lane9unselected. FinalF1seq/ack5run0,F2seq/ack6run1,bothhealthy
IDLE,C8=00100000,PRBSsessionsoff,no faults. All12opticalpowers high by5.246s,
includingRx02; previous1shardgate premature. No rebuild/drivechange.
Evidence firefly1-v5-managed-oneway-start-receive-1789593045630818.log;
fullrecords/limits docs/firefly1-v5-managed-oneway.md. start-receive CONSUMED.
No further request/reload/reset. This is eleven-lane baseline only.

Historical prior pre-gate:

LATEST: new managed-oneway gate stopped at RSSI check before any receive
request. Both TXstarts seq1 succeeded; Rx06/07/08/09/11 remained at off values
after1second. Both TXstops seq3 succeeded. Current both seq/ack3,run0,
C8=00100000,healthy IDLE,no faults; all RSSI returned to off baseline.
New start sentinel consumed. No retry/reload/reset. Module disables0000.
See docs/firefly1-v5-managed-oneway.md for raw evidence and limits (drive
code24 vs golden9; RSSI update/settling uncharacterized, not a BER failure).

User deferred GUI/IBERT capture and authorized restoring our bitstream on
both ends. F1 and F2 each programmed once successfully with audited v5;
FW/HW20304,seq/ack/run0,C8=00100000,platform40,no retained faults. Required
100000/325000/322260-kHz clocks valid. No new session/BER request issued.
Evidence under build/diagnostic_archive: firefly1-v5-F1-program-1789592459984466.log,
firefly1-v5-F2-program-1789592508855029.log,firefly1-v5-status-1789592558754291.log.
F2_1 rawRSSI01ce:01ab018f01db000001600000000001cb0000026401c90126.
Rx00..11 uW:29.4,45.7,61.2,0,45.9,0,0,35.2,0,47.5,39.9,42.7.
This is with F1 TX session OFF; compare during a bounded PRBS31 TX session
before calling the optical path active. Reader: board_diagnostics.py firefly1-rssi.
Old consumed tests must not replay; new two-v5 protocol needs matching script,
not the held launcher that assumes golden F1. No new bitstream needed yet.

## Historical golden hardware / capture investigation

Both FPGAs were manually programmed with golden after the v5 gate. Actual
confirmed optical path is F1_1 TX → F2_1 RX only, not bidirectional.
F1 quads121–123 all pass near-end PMA PRBS31. Golden external PRBS31 works on
eleven F2 lanes at F1 TXDIFFCTRL=01001 (GUI630 mV), zero pre/postcursor.
F2 X0Y13 is NO LINK externally, unaffected by the user's RX reset/drive scan,
but now passes near-end PMA PRBS31. Associated optical Rx02 remains61.2 µW.
This points toward the external path/settings, not a general local GT defect;
the failing component and full managed acquisition cause are not established.

Direct twelve-channel disable/RSSI test completed and restored every mask to
0000. User observed GTs in descending order X0Y15→X0Y4, confirming
test_lane=11-optical_channel and GT_Y=15-optical_channel; Rx02 association is
by ordering/exclusion because it was already failing. User now confirms all
previously working links recovered and no additional errors after clearing
IBERT counters. Last direct Rx11 RSSI was42.7 µW, not subsequently remeasured;
GUI recovery is user evidence, not a new RSSI reading. Last GUI loopback
settings after X0Y13 PMA are unknown; verify before external work.
See docs/firefly1-rx-channel-mapping.md for raw evidence and full table.

Revised reviewed plan (hardware not executed): archive golden settings and a
timed reference, compare golden/managed GT settings, and simulate existing v5
three-quad acquisition with 0x0DFF excluding lane9. User authorizes progression
after prerequisite GO: keep F1 golden, program the exact audited v5 onto F2
only, and run a new fixed one-way launcher with session mask FFF and RX mask
DFF. Scripts are offline-tested but review-held. Verify F2 JTAG numbering
with a golden F1 peer before programming. Defer TX fault-policy redesign/new
bitstream until evidence justifies them. Full twelve-lane qualification remains blocked by
the external X0Y13 path. Do not rerun consumed v5 launchers or assume F1 has
an optical return. Audit report docs/cm-interface-datasheet-audit.md is ready;
no cm_interface fixes have been applied.

Preparation checks: subset simulation PASS in
`build/logs/run_firefly1_v5_subset_sim-20260916T202251Z.log`; routed comparison
completed in `build/logs/compare_firefly1_golden_v5_settings-20260916T202309Z.log`.
V5 TXDIFFCTRL is fixed24 versus user-reported golden9; F2 TX is unconnected
for the proposed receive diagnostic. Golden runtime controls remain dynamic.
All20 new launcher offline tests pass. Read-only capture failed before target
access because lnx4189:3121 was unreachable; log
`build/logs/capture_firefly1_golden_readonly-20260916T202346Z.log`.
Hardware remains held, both images unchanged. User clarified that GUI server
3121 is incidental and must not be a dependency. Use the fixed Apollo XVC
endpoint apollo3010-1:2542 from lnx4189. New board_golden_xvc.py capture owns
a temporary localhost43121 bridge (required by Vivado IBERT), explicitly
opens XVC and cleans up only its own server. XSDB already uses direct XVC.
Do not release the measurement launcher without the live reference.
First independent bridge connected successfully; XVC target open then timed
out before device discovery (capture log20260916T204924Z). Its bridge was
cleaned up; neither FPGA changed. GUI connection contention is only a
hypothesis; do not silently disconnect the user's session.

User subsequently closed GUI XVC and cleared another process. Direct XSDB
enumerated both golden FPGAs (F1target1/hub2,F2target3/hub4). Vivado's
hostname-form XVC still timed out; resolving to192.168.21.162 reaches target
open but reports No devices detected, including the post-clear retry in
capture_firefly1_golden_readonly-20260916T205814Z.log. No baseline captured,
no programming/reset. Private bridge cleanup was repaired (wrapper child
process group, explicit port-release verification, TIME_WAIT-safe preflight)
and XVC_BRIDGE_PORT_RELEASED was observed on the final two captures.

## Historical v5 build and hardware gate

V5 / 0x00020304 firmware, historical/session/reset-wiring simulations,
compressed build and independent routed audit PASS. WNS/WHS +0.372/+0.003 ns,
zero routing/DRC errors. Build used clean top synthesis, completed IP reuse
and the audited v4 incremental routed reference. Build log:
`build/logs/rebuild_firefly1_v5_reset_fanout-20260916T172040Z.log`.
The first implementation was stopped before bit generation to correct the
v5-only quad-to-four-lane reset fan-out; prior synthesis/logs are archived.
Corrected clean synthesis and the actual group-wrapper wiring test pass.
Audit log `build/logs/audit_firefly1_loopback_v5_bitstream-20260916T173437Z.log`.
Both FPGAs were programmed once with bit SHA256
`a1014f7d2451045ae6fbae66f0d2d1faef60d74c4a74190584be20b6a821f28e`.
Both PMA gates passed sequence/run 1. External sequence 3/run 2 FAILED:
F1 0x04080c01, errors on lanes 1/3/4/6; F2 0x0c000c04, retained LOCK_WAIT
timeout with healthy clocks/reset qualifiers. No sequence 4 or retry.
At the end of that gate both TX sessions were OFF: F1 healthy IDLE at request/response 5, run 2,
failed measurement retained; F2 platform fault at request/response 3, run 2,
C8=0x00150000. Those live states were cleared by user's later golden loads.
Gates remain consumed; do not clear sentinels/replay them.
Aggregate RX fault still terminates independent TX; possible contamination
of a peer's result in a bidirectional setup, not a proven cause here: the
later wiring correction means F2 TX was not connected to F1 RX.
Read-only optics controls match; sparse installed tf registry is unsafe for
physical endpoint labels. See `docs/firefly1-v5-tx-session.md` for all hashes,
evidence. V5 is not qualified; the current resume point is above.

Historical v4 state (superseded on both FPGAs by v5):

F2 PMA gate now passed at sequence/run 1: twelve equal 257,808,259,520-bit
records, zero errors/losses, healthy IDLE/no retained first fault. F1 remains
unchanged at passed run 1. Both monitor sets remain valid. The F2 start is
consumed. Actual-engine simulation reproduces an optical-test stop race;
external tests have not started. See `docs/firefly1-v4-f2-bringup.md`.

Historical bring-up before the F2 PMA gate:

F2 bring-up completed with the exact final v4 bit below. PROGRAM_F2_COMPLETE,
matching FW/HW 0x00020303, fresh IDLE/run 0; F1 unchanged at run 1. Both sites
have valid 37-clock monitors, 100.000/325.000 MHz and FF1 REFCLK 322.260 MHz.
No new test request issued. See `docs/firefly1-v4-f2-bringup.md` for evidence
and fixed approved launchers. Next qualification gates remain pending.

## Historical FireFly-1 v4 gate — PASS

F1 runs the clean-synthesized v4 development repair, FW/HW `0x00020303`,
healthy IDLE after its fixed ten-second PMA-loopback sequence/run 1.
Response and summary are `0x000c0c01`; all twelve lanes have zero errors,
zero native lock losses, and nonzero records. Lanes 0–3 recorded
257,808,256,480 bits / 3,222,603,206 cycles; lanes 4–11 recorded
257,808,256,560 bits / 3,222,603,207 cycles. The one-cycle inter-quad difference
is consistent with independent RX clocks. No retained first-fault snapshot.
The collector observed beyond the ten-second cleanup timeout and verified
ready/IDLE afterward. No further request or reload is needed for this gate.

- Bit SHA-256: `cc450c14786a2a00fca7ad844d47be7e5438d160590b463f8f2bd85ffc17443a`.
- ELF SHA-256: `abe06ba6f83ca94b0748076092c9bd3a2763d338987edfa14eb1e73d64956ab2`.
- Full regression: all 13 checks pass; focused delayed/missing reset-ack tests pass.
- Compressed routed build/audit: WNS/WHS +0.206/+0.010 ns, zero routing/DRC errors.
- All 48 descriptor bounds, three actual-driver skew checks (worst +1.212 ns),
  correct 12-channel/three-common ownership and golden RX properties pass.
- All three Wizard and twelve lane reset-ack registers are present; no TIMING-17/26.
- Final MCU F1 temperature 28.765625 C; AVTT 1.2001953125 V.
  Monitor status `0x434da501`, 100.000/325.000-MHz clocks and FF1
  REFCLK 322.260 MHz are healthy.
- Programming completed with `PROGRAM_F1_COMPLETE`; evidence:
  `build/diagnostic_archive/firefly1-v4-program-1789576480591827.log`.
- Results: `build/diagnostic_archive/firefly1-v4-results-1789576567.log`.
- Audit: `build/logs/audit_firefly1_loopback_v4_bitstream-20260916T163340Z.log`.

Source fixes: staged-acquisition forwarding, retained FE diagnostics, complete
PMA loopback decode through states 20/21/26, and bounded low-then-high cleanup
reset acknowledgement. Restored reference-clock constraints prevent incomplete
timing coverage. Automatic incremental synthesis was disabled after a routed
artifact lacked the new acknowledgement logic; clean synthesis and routed
structural checks pass. Do not re-enable reuse without equivalent proof.

Earlier failed/rejected revisions remain archived, not relabeled. Their exact
hashes, raw evidence, simulation reproducers and launch instructions are in
`docs/firefly1-v4-repair.md`. V3's zero FE words and synthetic lane failures
did not prove reset-done/native lock loss or polarity faults. Physical P/N
wiring is unchanged and polarity controls are zero.

This passes the isolated internal-PMA diagnostic gate, not external optical,
fault-injection, soak or full CDC qualification. Existing non-descriptor CDC
and methodology caveats remain, plus 101 inherited implementation critical
warnings for inactive TX pins/unused q124 scope. No optical stimulus was used.

## FireFly-1 functional PMA-loopback image — v2 hardware gate failed

- V1 (`0x00020300`) was conclusively invalid: its routed checkpoint contained
  only legacy q124 channels `GTYE4_CHANNEL_X0Y16`--`X0Y19` and common
  `GTYE4_COMMON_X0Y4`, not FireFly-1 q121--q123.  It must not be programmed.
- V2 is the distinct replacement target `gt_test_firefly1_loopback_v2`, with
  matching firmware/hardware `0x00020301` and the same intended exclusive
  q121--q123/lane-0--11 ownership.  It does not alter v15 or the full image.
- Its first programming
  attempt used an earlier image in which each native wrapper instantiated the
  same q122 reference-clock input buffer; that image accepted sequence 1 but
  failed before RUN.  That result is diagnostic only and must not be used to
  judge the corrected image.
- The reference-buffer correction leaves exactly one `IBUFDS_GTE4` in the FireFly-1 group
  wrapper and distributes its buffered REFCLK to q121--q123.  F1's observed
  q122 reference clock (`lf_r0_ad`) was healthy at 322.260 MHz.  The routed
  audit now resolves physical GT placement correctly.  V2 forwards
  `FIREFLY1_FUNCTIONAL` through `gt_test_milestone25_top`; it also bypasses
  the obsolete isolated monitor buffer for q121 REFCLK0 so the group wrapper
  is its sole `IBUFDS_GTE4`, and imports the three Wizard-owned generated XDC
  files that LOC q121--q123.  The first v2 placement reached the real cores
  and exposed the duplicate-buffer error; these source fixes address it.
- The matching v2 firmware and compressed bitstream now exist.  Their SHA-256
  values are respectively `ff01323bc6f96ea3caaef2c6ce3d94c6371c152a9cb3dead0e695a860f87219e`
  and `098cf83f130fca3e5c084065f9aa3bf47655f399a45bb52d4b3f09a7ee06e4a9`.
  The corrected attached-session Vivado invocation completed implementation
  with all timing constraints met and ran the matching routed audit on
  2026-09-16.  The audit passed exact q121--q123 channel/common ownership,
  routing, timing, and error-severity DRC checks; it reports only the existing
  RPBF-3 I2C-buffering warning.  The v2 audit uses the distinct
  `gt_test_firefly1_loopback_v2_top` checkpoint, not the invalid v1 top.
- Source-controlled v2-specific helpers now exist: `board_program.py
  firefly1_loopback_v2` hash-pins the audited artifacts, while
  `board_firefly1_loopback_v2.py deploy|start|status|results|diagnostics`
  fixes F1, version `0x00020301`, one 10-second sequence-1 PMA-loopback
  request, and non-overwriting evidence names. `diagnostics` is read-only.
  `firefly1_loopback_v1` remains forbidden.
- The one permitted v2 sequence/run-ID-1 PMA-loopback gate completed its normal
  10-second interval but **failed**: response/summary `0x05070C01` means five
  failed, seven passed, twelve selected, normal-duration stop. Lanes 0, 1, 2,
  5, and 6 each saturated their native PRBS error count; lanes 3, 4, and 7--11
  were clean, all twelve had comparable 3,222,59x,xxx valid cycles and zero
  native lock losses. Final `C8=0x00010000` and selector `0xFE` word 0
  `0x00002080` retain a post-result RX-reset-done fault (`0x20`); the group
  wrapper does not preserve a first-fault snapshot. Evidence is in
  `build/diagnostic_archive/firefly1-v2-{start,status,results,diagnostics}-*`.
  Do not reload, reset, or retry this consumed image/run. Static investigation
  found the generated functional Wizards have `rxpolarity_in` and
  `txpolarity_in` disabled/fixed low. A per-lane polarity correction is the
  leading explanation for the exact error-only split, but remains a hypothesis
  until a separately generated, routed-audited replacement is authorized.

## Immediate next actions

- FULL V15 SEQUENCE-3 12-HOUR SOAK PASSED: matching request/response/run ID 3
  and `0x00040401`; all lanes 12–15 recorded equal
  1,113,730,550,445,760-bit / 13,921,631,880,572-cycle records with zero errors
  and lock losses (`BER95 < 2.694e-15`). F1 is healthy IDLE at ID 3. Final MCU
  F1 temperature/AVTT were 54.4375 C / 1.203125 V and clocks were valid. Do
  not retry, reload, reset, or submit a new v15 request without explicit
  direction; evidence is `build/diagnostic_archive/v15-soak3-results.log`.

- FULL V15 INITIAL HARDWARE GATE PASSED AFTER MANUAL LOAD: the user manually
  loaded audited full v15 / `0x0002000F` after the automatic XSDB/XVC helper
  repeatedly failed before completion. The mailbox verified fresh IDLE, then
  fixed unique external sequences/run IDs 1 and 2 each returned `0x00040401`.
  All four lanes were equal and clean: sequence 1 recorded
  1,546,848,140,880 tested bits / 19,335,601,761 cycles per lane; sequence 2
  recorded 1,546,848,008,240 / 19,335,600,103. Both have zero errors and zero
  native lock losses (`BER95 < 1.939e-12`), no retained fault, and final
  healthy IDLE at ID 2. Final MCU F1 temperature was 53.5625 C, AVTT 1.20117
  V, and all monitor clocks were valid. This is an initial external gate, not
  full qualification; do not rerun/reload/retry without explicit direction.
  See `docs/v15-programming-interface-failure.md`.

- FULL V15 PROGRAMMING/GENERIC-INTERFACE FAILURE PRESERVED: full v15 /
  `0x0002000F` completed simulation, compressed implementation, and independent
  routed audit. The fixed test bundle was deployed with SHA-256 verification;
  the exact bitstream/ELF hashes were checked and F1 target 1 was selected via
  XVC. `fpga -file` did not return the required completion marker, and the
  immediate F1 mailbox and clock reads failed with `ADDR_ACK_ERROR`. The
  JTAG-status helper likewise reached the XVC endpoint but did not return its
  target list. No v15 request/run ID was issued. MCU rails, temperatures, and
  regulator status were healthy; both F1 module snapshots retain their
  pre-existing `FF/FF` alarms. Do not retry, reset, reconfigure, or start the
  fixed sequence-1 test without a new explicit decision after interface
  recovery. See `docs/v15-programming-interface-failure.md`.
  One explicitly authorized repeat on 2026-09-15 reproduced the same missing
  programming-completion marker and mailbox `ADDR_ACK_ERROR`; it started no
  v15 request and does not authorize another repeat.
  A final explicitly authorized attempt after a board power cycle likewise
  found two bare JTAG FPGA targets, then reproduced the missing completion
  marker and `ADDR_ACK_ERROR`. No v15 test was issued.

- FULL V14 HARDWARE DIAGNOSTIC PASSED: after the user power-cycled F1, the
  exact audited v14 image was programmed once using XVC
  `TCP:apollo3010-1:2542` (F1 target 1; F2 target 5). The unique fresh
  two unique 60-second external sequences/run IDs 1 and 2 passed with
  response/summary `0x00040401`; each lane recorded 1,546,848,197,680 /
  1,546,848,072,800 tested bits and 19,335,602,471 / 19,335,600,910 valid
  cycles, respectively, with zero errors and zero native lock losses
  (`BER95 < 1.939e-12`). No retained fault is valid, and F1 is v14 healthy IDLE
  at sequence/run ID 2. This supports only the narrow conclusion that v13's
  planned startup full-quad restart caused its repeated pre-RUN failures; v14
  is diagnostic, not qualification. AVTT status was clear after both runs
  (1.20435 V, 24.21875 A, 42.6875 C; then 1.20093 V, 24.34375 A, 43.25 C).
  The serialized MCU ADC path captured F1/F2 at 54.59375/27.71875 C after the
  runs. The hard-coded `lnx4189:3121` FPGA-SysMon helper still fails before
  sensor read and needs XVC conversion only if its distinct SysMon telemetry is
  required. See `docs/v14-no-startup-restart-diagnostic.md`.

- FULL V14 NO-STARTUP-RESTART DIAGNOSTIC BUILT/AUDITED: full v14 / `0x0002000E`
  differs from the reproducibly failing full v13 only by
  `EXTERNAL_STARTUP_QUAD_RESTART=0`. Its matching firmware, compressed routed
  image, and independent audit pass: WNS/WHS `+0.222/+0.009 ns`, zero routing
  and DRC errors, four met bus-skew constraints (worst `+19.464 ns`), all 16
  descriptor paths (worst `+2.155 ns`), 112-owner GT placement, golden managed
  RX properties, direct profile sources, runtime-integrity synchronizers, and
  physical-only heartbeat fan-in. Bitstream SHA-256 is
  `02633d63dce3e75b4e80de537341b89d7e6aa964ee6b710b8e3432e2ad665931`; firmware
  SHA-256 is `d8eecdb9b84c9d0395e6a0a06f5f84d0add22b6622e2dc6566e3f87afa2a41c9`.
  It is diagnostic only, not qualification. See
  `docs/v14-no-startup-restart-diagnostic.md`.

- V275 INITIAL QUALIFICATION-CANDIDATE GATE PASSED: isolated v275 / 2.5.25
  (`0x00020119`) freezes the v272 100-ms runtime-integrity detector and v273
  planned startup restart with the v274 heartbeat hook explicitly disabled.
  Full regression, matching firmware, compressed build, and independent audit
  pass at WNS/WHS +0.009/+0.001 ns, zero routing/DRC errors, physical-only
  heartbeat fan-in, and all structural checks. Existing v273 CDC/methodology
  caveats and absent bus-skew constraints remain. F1 was programmed once and
  passed unique 10-second sequence/run 1 and 2 baselines without retry or
  reload. Both have four clean complete profiles, planned cause 4 plus cleanup
  cause 3, zero lock losses/integrity events, and 125 trace events without
  overflow. The fixed sequence-3 uninterrupted 12-hour external soak then
  passed without reload/retry: matching request/response/run ID 3, normal
  summary `0x00040401`, four equal 1,113,731,693,556,560-bit records, zero
  errors/lock losses/saturation, and `BER95 < 2.694e-15` per lane. F1 remains
  v275 healthy IDLE at run ID 3. See
  `docs/v275-qualification-candidate.md`.

- Completion was first observed at 2026-09-14 04:20:43 EDT. Final FPGA
  temperature was 24.5 C; raw/unvalidated F1 AVTT current was -0.6494140625 A;
  regulator status, 100/325-MHz clocks, and managed 322.262-MHz RXUSRCLK2 were
  healthy. Do not resubmit, reset, or reload. The sequence-3 `start` and
  non-overwriting `results` operations are consumed. The initial launcher
  falsely expected run ID 3 at RUN entry and returned failure after
  successfully starting the run; it was
  corrected to model published-bank semantics, redeployed, and its read-only
  status passed. The request itself was not retried.

- V274 HEARTBEAT-MONITOR BUILD/AUDIT AND HARDWARE GATE PASSED: isolated v274 / 2.5.24
  (`0x00020118`) preserves v273 and adds a controlled, default-off suppression
  of only the divided heartbeat presented to the runtime monitor. Full
  simulation, matching firmware, compressed implementation, and independent
  audit pass at WNS/WHS +0.009/+0.001 ns with zero routing/DRC errors. All
  descriptor/profile/runtime checks and the v274 routed control-to-heartbeat
  fan-in proof pass. Existing caveats remain: no isolated-target bus-skew
  constraints, and the intentional test gate changes one CDC-3 to CDC-10. This
  does not stop physical RXUSRCLK2. The hash-pinned hardware gate also passed:
  clean sequence/run 1 had four zero-error profiles and no integrity event;
  sequence/run 2 retained one clock-only event at stage 27 after about 119 ms.
  The watcher restored its control with the second/final write, the physical
  managed clock remained 322.260 MHz, the quad stayed READY, and only the
  expected two-cycle lane-15 toggle pulse was measured. F1 retains the v274
  sequence/run-ID-2 fault; no retry/later request/reset/reload. See
  `docs/v274-heartbeat-test.md`.

- NEXT: the controlled heartbeat-monitor branch is now validated. Keep v272's
  100-ms policy and v273's planned-startup behavior for a future qualification
  candidate unless a separately justified physical-clock experiment is
  required. Do not call this actual missing RXUSRCLK2, optical LOS, or native
  CDR loss, and do not clear the retained v274 fault implicitly.

- V273 PLANNED-STARTUP DIAGNOSTIC PASSED: isolated v273 / 2.5.23
  (`0x00020117`) preserves v272 runtime integrity and adds one v273-only
  coordinated restart after controls settle. Full regression, compressed
  incremental build, and independent audit pass at WNS/WHS +0.009/+0.001 ns
  with zero routing/DRC errors. Two unique consecutive 10-second F1 baselines
  passed without reload/retry. Each recorded planned cause 4 and cleanup cause
  3, no reactive cause-2 recovery, four clean complete profiles, zero native
  lock losses, and no trace overflow. A sequence-3 launcher race was refused
  before any write and preserved as a clean run. Race-free sequence 4 captured
  exactly two lane-12 error cycles without an integrity event. Sequence 5's
  250.304-ms F1_5 channel-0 disable retained exactly one lane-12 integrity
  event, no shared-clock cause, and fault stage 27. All `RXPRBSLOCKED` inputs
  were high at first fault and later fell when the fault disabled the checker;
  the quad stayed READY and was not reset. The `0x280c`–`0x280f` publications
  are synthetic platform-failure records, not measured lock-loss counters.
  This is conclusive for the startup-policy
  question and passes the lane-data gate, not full qualification. F1 retains
  the v273 sequence/run-ID-5 platform fault; no reset/reload/later request. See
  `docs/v273-planned-startup-restart.md`.

V272 LANE-DATA RUNTIME-INTEGRITY HARDWARE GATE PASSED: F1 was programmed once
with the exact audited `0x00020116` image. Sequences/run IDs 1 and 2 completed
clean 10-second measurements but each used one bounded acquisition recovery,
so neither met the no-recovery baseline criterion. After explicit continuation,
sequence 3's watched two-cycle lane-12 pulse recorded exactly two profile error
cycles and zero integrity events. Sequence 4 disabled only F1_5 channel 0 for
0.250289 s and retained response/summary `0x04000404`, platform fault stage 27,
one integrity event, and lane 12 as the sole data cause. Lanes 13–15, shared-
clock cause, and all native lock-loss counts stayed clear; FireFly byte 86 was
restored. Trace epochs 1–4 retained 145/147/140/91 events without overflow.
This passes sustained lane-data detection, not optical LOS/CDR loss; missing
RXUSRCLK2 remains untested. V272 is not fully qualification-ready because both
clean baselines needed acquisition recovery. A later authorized same-image
reload cleared the retained fault, and one fresh sequence/run-ID-1 startup
request reproduced the recovery. All native lock/reset/clock qualifiers were
healthy; all four lanes were observed error-active and their aggregate had zero
clean cycles for 100 ms. The full-quad restart recovered and the measurement
was clean. No retry followed. F1 was then v272 healthy IDLE at sequence/run ID
1. The explicit v273 experiment above subsequently resolved the narrow
design-policy decision without changing v272. See
`docs/v272-hardware-gate.md` and
`docs/v272-startup-recovery-investigation.md`.

V272 BUILD/AUDIT GATE PASSED: isolated v272 / 2.5.22 (`0x00020116`) enables
the runtime-integrity detector only in this distinct target. Full simulation,
matching firmware, compressed incremental implementation, build checks, and
independent routed audit pass. Timing is WNS +0.018/WHS +0.001 ns with zero
routing or DRC errors. All 16 descriptor bounds pass (worst +1.568 ns), all
ten detector synchronizer registers carry `ASYNC_REG`, and the existing
profile direct-source checks pass. Existing unrelated CDC/methodology caveats
and the lack of isolated-target bus-skew constraints remain. Artifact hashes
are in `docs/v272-build.md`. The subsequent hardware gate is recorded above.

V271 FIREFLY THRESHOLD GATE PASSED: sequence 5 disabled F1_5 channel 0 for a
measured 250.280 ms during a 10-second run. Lane 12 recorded a single
3,133,090,464-cycle (~9.72-s) consecutive error interval; lanes 13–15 remained
clean and all native lock-loss counts stayed zero. Byte 86 was restored to 00,
regulator status remained clear, and clean sequence 6 then passed all four
lanes. F1 was v271 IDLE at request/response/run ID 6 before the authorized v272
programming above. The observed margin
accepts the 100-ms consecutive-error threshold for initial v272. This did not
exercise missing RXUSRCLK2. Evidence/hashes are in
`docs/v271-firefly-threshold-characterization.md`. The separate v272 build and
audit now pass as recorded above; do not relabel v271.
Required clocks were in range, F1_5 was 38 C, and regulator status was clear.
The FPGA SysMon temperature helper did not complete, so no final FPGA
temperature was captured. An attempted parallel preflight caused two read
failures on the single MCU UART but made no writes; the full serialized
preflight passed before sequence 5. Keep future board diagnostics serialized.

RUNTIME-INTEGRITY SOURCE/SIMULATION GATE PASSED: the source adds a
default-off measurement-time detector for sustained PRBS corruption and loss
of the shared RXUSRCLK2 heartbeat. The initial policy is 100-ms consecutive
error assertion, 1-ms clean deassertion, 100-ms clock timeout, and four-edge
clock recovery. It reports data integrity/shared fabric clock only, never
optical LOS or CDR loss. Selector FD capability bit 1 and words 6–7 now carry
the saturating event count and live/retained state when enabled; fault stage 27
uses the existing platform-fault publication path. Standalone, controller and
full engine simulations pass, including the two-cycle non-trip control and
atomic failure publication. Historical targets remain parameter-disabled. The
v271 hardware gate accepts the consecutive-error threshold, and the separate
v272 build/audit and lane-data hardware gates above now pass; the shared-clock
branch still lacks hardware evidence.
See `docs/runtime-integrity-candidate-design.md` and `docs/v272-build.md`.

V271 BUILD/AUDIT AND HARDWARE BASELINE GATE PASSED: isolated v271 / 2.5.21
(`0x00020115`) contains the zero-elapsed-profile repair. Full simulation,
firmware, compressed incremental implementation, build checks, and independent
routed audit pass. Final timing is WNS +0.018/WHS +0.001 ns with zero routing/
DRC errors; all 16 descriptor endpoints retain their 3.000-ns bound (worst
+1.568 ns). The repaired profile measurement paths changed from CDC-10
combinational-source findings to direct registered CDC-11 fan-out paths, and
all eight profile measurement/epoch first stages pass an explicit
no-combinational-fanin audit. Existing unrelated CDC/methodology findings
remain; this isolated target has no bus-skew constraints. Artifacts and hashes
are in `docs/v271-build.md`. F1 was subsequently programmed with the exact
audited v271 image and passed two consecutive unique 10-second external
baselines without reload/retry: four equal nonzero profiles per run, zero
errors/losses, one cleanup each, 93/104 trace events and no overflow. Both
toggle phases passed. Sequence 3 then recorded a two-cycle lane-12-only pulse
with full nonzero elapsed profiles, retained the complete publication unchanged
for about 158 seconds in IDLE, and clean sequence 4 replaced the prior epoch.
At that gate F1 was v271 IDLE at sequence/run ID 4; sequences 5 and 6 above
supersede that state. Power/clocks/temperatures were
healthy; the familiar raw FireFly `FF/FF` persisted. No retry/reload or optical
stimulus occurred. See `docs/v271-hardware-baselines.md` and
`docs/v271-profile-hardware-gate.md`.

## Historical chronological log

The entries below preserve state transitions and evidence. Any embedded
“latest,” “next,” “pending,” or resume instruction is historical and does not
supersede the current all-links v2 resume point above.

HISTORICAL V270 TIMED-ALARM RUN: F1 was v270 IDLE, sequence/run ID 1 after explicit
reload via board_program.py. Repeated F1_5 alarms FF/FF in IDLE -> 00/00 during
RUN -> FF/FF in IDLE, with module controls unchanged. Hardware summary 0x00040401
and ordinary four-lane records clean, but full diagnostic validation FAILED:
lane-12 RX profile valid=1 with elapsed=0; other profiles ~3.22 billion cycles.
Raw capture and standard result dump preserved; no retry/reload. See
`docs/v270-run-idle-alarms.md`. Investigate the profile offline before stimuli.
The earlier golden-loaded and pending-baseline descriptions below are historical.

V270 RELOADED VIA NEW HELPER: `scripts/board_program.py v270` completed,
verified FW/HW 0x00020114 and fresh request/response/run IDs zero. Separate
hash-pinned F1 programming rule is installed at ~/.codex/rules/board-program.rules;
diagnostic permissions unchanged. The interrupted legacy reload had not
established v270 and no batch process remained before this explicit reload.
One authorized timed alarm baseline is now pending/in progress; do not submit
a second request. Output: Apollo /tmp/v270-diagnostic-20260912/after-golden-run1-alarms.json.
JTAG after reload F1=1, MDM=4, MB=5, F2=3; always re-enumerate.

GOLDEN FOLLOW-UP: second module-helper read showed F1_5 LOS/CDR LOL 00/00
with PRBS31 still running; F1_6 0F/0F. No module controls changed. F1/F2 JTAG
temperatures 53.3/24.5 C, supply statuses clear. Golden four-lane baseline
passed as below. The first post-test FF/00 sample was not the final alarm
state. Next proposed comparison: v270 RUN versus IDLE alarm sampling, requiring
an explicit reload and preserved distinct evidence. No v270 reload issued.
Call diagnostic helpers directly: piping into rg introduces another approval.

GOLDEN BASELINE PASS: F1 golden Quad-124 external PRBS31, 10-second observation,
zero errors on all four lanes over about 259.44 billion bits/lane. CDR lock,
TX/RX reset-done asserted, non-idle inputs. F1_5 post-test LOS/CDR LOL FF/00
(previous v270 IDLE FF/FF); F1_6 FF/0F. Controls unchanged, supply status clear.
F1 remains golden with the four links running; no managed mailbox sequence
applies. Evidence and limitations: `docs/golden-comparison-20260912.md`.
Next proposed diagnostic is module-alarm sampling DURING v270 RUN versus IDLE;
the continuous-golden versus idle-v270 distinction confounds firmware inference.

GOLDEN COMPARISON IN PROGRESS: user authorized historical uncompressed golden
top.bit as an explicit exception. Hash verified e6f49cef8ff91381ca2470c9b4860e90d13ea5ed98e48562ff14288365541e83;
F1 programming completed successfully. F1 now has golden IBERT, not v270.
Pre-reload v270 post-cycle run-1 pass remains archived. No FireFly controls
changed. See `docs/golden-comparison-20260912.md`; no golden pass claimed yet.

POST-CYCLE BASELINE PASS: user authorized one diagnostic run despite FF/FF.
V270 10-second external sequence/run ID 1 passed all four lanes with zero
errors/losses, healthy IDLE, one cleanup restart, 102 trace events/no overflow.
RX clock 322262 kHz before/after; FPGA temps F1/F2 25.5/24.0 C, supplies clear.
Module FF/FF persists. Raw JSON copied/hash-verified and offline validated;
see `docs/v270-post-power-cycle.md`. No second run or fallback programming.
Next proposed comparison is golden IBERT, pending explicit choice to reload.
The earlier run-zero/hold descriptions below are historical pre-baseline state.

POST-POWER-CYCLE UPDATE: user power-cycled board; agent explicitly reloaded
hash-verified audited v270 into F1 only. FW/HW 0x00020114, engine IDLE and
request/response/run IDs zero. No new baseline. Managed RX clock now 322262 kHz
(previously 322009–322010); primary references 322260–322261, generated clocks
100/325 MHz. Other r24–r37 references remain about 320638 kHz. FireFly LOS/CDR
LOL still FF/FF. F1/F2 preprogram temperatures 25.0/24.5 C, supply status clear.
See `docs/v270-post-power-cycle.md`. Earlier sequence-4 resume instructions
are obsolete: any next fresh run would be sequence/run ID 1 after 0, if unchanged.
JTAG after reload: F1=1, MDM=3, MicroBlaze=4, F2=2; re-enumerate before use.

CDR COMPARISON UPDATE: user authorized temporary F1_5 RX0 CDR bypass.
Byte 98 FF->FE readback verified, then FF restored and verified in finally.
Managed RXUSRCLK2 stayed 322009–322010 kHz; LOS/CDR LOL stayed FF/FF.
Primary left x4 reference was 322260–322261 kHz, generated clocks 100/325 MHz.
No run request or FPGA reload. Hardware identity verified 0x00020114.
See `docs/firefly4-live-map-check.md` for timed evidence and limitations.

MANUAL RECONCILIATION UPDATE: the user supplied the ECUO 25G/28G x4 manual.
Byte 3 is confirmed LOS; byte 5 is CDR LOL, both one byte. The MCU x4 LOS
entry incorrectly reads bytes 7–8; its CDR LOL entry reads an extra temperature
alarm byte. See `docs/mcu-firefly4-alarm-mapping-bug.md` (not yet fixed).
Fresh module-only reads still give FF/FF on F1_5/F1_6, with nonzero RX optical
power on all eight channels, status byte 2 zero, TX disable zero and CDR enable
FF. See `docs/firefly4-live-map-check.md` for raw evidence and interpretation.
The address/display discrepancy is resolved; persistent alarm behavior is not.
No new run or programming; sequence 4 and optical stimuli remain on hold.
This update supersedes the unresolved-address wording immediately below.

POST-RESET UPDATE: user reports shared F1 FireFly reset completed. All ten
post-reset module endpoints captured successfully in
`build/diagnostic_archive/after-shared-reset-fireflies.{json,log}`. Sampled
controls unchanged; raw bytes 3/5 on F1_5 and F1_6 still FF/FF. User independently
reports CDR_LOL=FF but LOS=00. **Do not label byte-3 FF as confirmed LOS** until
the user's module/address/display is reconciled with our raw reads. Baseline
sequence 4 is on hold; no new run or FPGA reprogramming issued. Post-reset FPGA
capture saved as `after-shared-reset-capture.{json,log}` in the same archive.
FPGA temperatures remain F1/F2 25.5/24.5 C; supply statuses clear. The pre-reset
preparation text below is historical, not a request to reset again.

Shared F1 FireFly reset preparation: user confirms FF-page accesses are fresh
reads, not cached, and reset is common to **all F1 Fireflies**. User will
toggle the line after our pre-reset capture; agent has not reset anything.
Pre-reset v270 capture is saved at
`build/diagnostic_archive/before-shared-reset-capture.{json,log}`; still healthy
IDLE, sequence/run ID 3, unchanged pulse result. All ten physical F1 device
endpoints (MCU indices 0–9) were read without errors into
`before-shared-reset-fireflies.{json,log}` in the same directory. Both x4
modules (indices 8/9, F1_5/F1_6) show bytes 3/5 `FF/FF`, page 0, byte 86=0,
CDR enable=FF and masks 100–102=0. Temps 38/39 C. Raw 12-channel flags/controls
are retained without applying the x4 interpretation. JTAG pre-reset F1/F2
temperatures 25.5/24.5 C. No settings, reset, programming or run request was
issued. Await user's reset confirmation, then repeat module snapshot and
check FPGA state before a new clean baseline (sequence 4 after 3 if unchanged).
Do not reprogram automatically. MCU source is not a prerequisite.

Latest hardware: F1 v270 (`0x00020114`), healthy IDLE after sequence/run ID 3.
The lane-12 external pulse test passed: one write-one-toggle request, two
RXPRBSERR-active cycles on lane 12 only, native longest/span 2, zero lock
losses, one cleanup restart, 103 trace events/no overflow. F1 26.0 C pre/post;
supply statuses clear. Trace error_seen was already `0xF` at measurement start;
only the RX-local profile characterizes the pulse. No fourth run or optical
disable. See `docs/v270-pulse-characterization.md` for evidence and hashes.
Optical tests are paused until FireFly `FF/FF` is explained: individual and
block reads agree on page 0 with plausible identity/telemetry. Need authoritative
installed-module map / MCU FireFly read-path review, not an assumed clear state.
Next sequence would be 4 after 3 / expected run ID 4 if unchanged.
Pulse evidence bundle `build/diagnostic_archive/v270-run3-pulse-evidence.tar.gz`:
SHA-256 `66c79c6139e950e0f7755c61b92084af4dbdcded79b5e241c1a984cdd5a383ad`.
Remote/local JSON/log hashes match. The nearby MCU v0.99.23 archive contains
binaries/address tables, not the FireFly read-handler source.

### Previous two-baseline gate

F1 now runs isolated **v270 / 2.5.20 (`0x00020114`)**, healthy IDLE after
request/response/run ID 2. Both 10-second external four-lane baselines passed
without reload: zero errors/losses, all lanes selected, one cleanup restart
each, 103/108 trace events without overflow. Both handshake phases exercised.
F1 25.5 C and F2 24.0 C before/after; supply statuses clear. FireFly bytes 3/5
still `FF/FF`, byte 86 zero. No fault stimulus or third request issued.
See `docs/v270-hardware-baselines.md` for hashes, telemetry and run evidence.
Combined evidence bundle `build/diagnostic_archive/v270-hardware-baselines.tar.gz`:
SHA-256 `16b1b3e721a0cada0fb94d7f76b1a53fb09a4ee1f09fb28e3b971175ef9d8e5f`.
Both copied raw captures also passed offline validation; Apollo/local hashes match.

Source/simulation update: request capture now has two extra RX stages versus
descriptor data, accepted PRBS mode is retained through recovery, and atomic
publication selection is checked against the request. Per-bit skew regression,
integrated mismatch case, existing unit/core suites and Python tests pass.
The new isolated **v270 / 2.5.20 (`0x00020114`) build and independent routed
audit pass**. A target-specific constraint replaces the quad's blanket clock
group with directional exceptions excluding the 16 descriptor data pins;
all 16 have effective 3.000-ns bounds, worst slack +1.568 ns. This is a bounded
settling budget, not arbitrary-skew immunity or global CDC signoff.
See `docs/descriptor-transfer-repair.md` and `docs/v270-build.md`.

The prior v269/run-1 failure is preserved; the v270 baseline gate now passes.
Do not automatically retry or reload. Retain the per-bit selection/PRBS-mode
skew, both-phase, RX-clock-pause and recovery regressions during physical CDC
review. Publication now checks requested-versus-accepted selection; a
three-lane success is not a valid four-lane run. The focused reproducer
demonstrates the prior RTL hazard, not the
exact hardware capture timing. The source-stage changes are summarized above;
they are now implemented/routed as v270 and passed the two baseline runs above.

The subsequent lane-12 pulse passed as recorded above. At this historical gate,
FireFly alarm bytes `FF/FF`, integrity-detector thresholds, and clean
qualification remained deferred. V271 has since accepted the 100-ms
consecutive-error threshold; later sections remain historical.

## Incremental diagnostic v270 (build/audit and two hardware baselines passed)

Build session 14:24:16–14:35:30 EDT, 11m14s; nine cached IP synthesis runs,
90.74% final cell reuse / 76.42% net reuse from hash-verified v269 DCP.
Compressed bitstream 32,322,504 bytes; matching ELF embedded. Independent
audit: WNS +0.325, WHS +0.001, WPWS +0.454 ns, zero routing/DRC errors,
four expected GT sites/golden properties, 100/325-MHz monitor clocks. All
11 IPs current. Descriptor paths pass individually from the saved DCP.
Routed CDC counts match v269; existing methodology caveats remain, plus
XDCB-1 runtime cost for the endpoint exclusion list. No bus-skew constraints.
Full warning disposition, commands and SHA-256 hashes: `docs/v270-build.md`.
Frozen source/products: `build/diagnostic_archive/v270-source-preimplementation.tar.gz`
and `v270-products.tar.gz`. No hardware access occurred during the build;
subsequent programming/baseline evidence is linked above. V270 is diagnostic,
not qualification. The v269 record below is historical.

## Incremental diagnostic v269 (build/audit passed; first hardware baseline failed)

User authorized checkpoint reuse. The v269 (`0x00020113`) build clones v268's
completed IP runs/cache and uses its hash-verified routed DCP for incremental
implementation; top RTL and firmware are rebuilt. Corrected setup took 11 seconds
with no IP synthesis launched. Build elapsed 10m57s versus v268 clean 14m41s
(25.4% less; different RTL, not a controlled benchmark). Final reuse was 82.08%
of cells and 65.44% of nets. Tests for the enlarged 256-entry banked trace pass.
The stopped first attempt truncated mode 2 through a one-bit parameter; it is
preserved under `build/gt_test_milestone269-trace-disabled/`, never programmed.
Integer parameters and a synthesized-netlist recorder gate fix/check this.
Independent routed audit passed: WNS +0.122, WHS +0.001, WPWS +0.454 ns,
compressed, zero routing/DRC errors, four expected GT sites/properties and
100/325-MHz monitor clocks. All 11 IPs are up-to-date; CDC counts match v268.
Bus-skew has no constraints. Existing CDC/methodology caveats remain; incremental
clock-guidance warning is dispositioned against the complete routed result.
See `docs/incremental-diagnostic-builds.md` for provenance, limitations, and
the separate clean-build path. F1 was programmed with v269 and is now IDLE
after sequence/run ID 1. The 10-second baseline returned `0x00030301`: lane 12
unselected despite MCU and AXI descriptor masks `0xF000`; lanes 13–15 clean.
The trace retained all 127 events, no overflow, and exposed one acquisition
restart plus cleanup. A focused one-cycle descriptor-synchronizer-skew
simulation reproduces acknowledgement with stale selection. No second run,
injection or reprogramming followed; later source repair is summarized above.
F1 temperature was 26.0 C
before / 25.5 C after; supply statuses clear. FireFly alarm bytes remained
`FF/FF` on clear/read and require separate investigation. See
`docs/v269-hardware-baseline.md` for evidence, limitations and next gate.
The preserved run, standard failure dump, FPGA-temperature logs, programming
script and skew reproducer are bundled in
`build/diagnostic_archive/v269-run1-evidence.tar.gz`, SHA-256
`85d00f407a571e7341621a2ce6c03e63228eb0afa5b8d37ea92347237754b60c`.

## Recovery plan items 5–6 (historical v268 attempt; resumed gate above)

Isolated v268 (`0x00020112`) adds a 64-entry transition trace and four native-RX
error profiles, with no new detection policy. The matching firmware/bitstream
and independent routed audit passed (WNS +0.325, WHS +0.010 ns, compressed,
zero routing/DRC errors, correct four GT sites and 100/325-MHz clocks).
The bus-skew report has no constraints; CDC/methodology limitations are
documented, not globally waived. Nine unit/integrated and
two core HDL tests plus fourteen Python decoder/operator tests passed. Source/ELF hashes,
new selector ABI, and the gated characterization procedure are in
`docs/recovery-items5-6.md`. F1 was programmed via XSDB on lnx4189; both mailbox
version words verified `0x00020112` with initial request/run ID zero. Clean
baseline sequence 1/run ID 1 completed cleanly on all lanes, but diagnostic
validation failed: 107 transitions overflowed the 64-entry buffer. Raw JSON
and log are archived; no second request or fault stimulus was applied.
JTAG SysMon immediately before programming was 25.5 C for the first FPGA.
The MCU firmware does not implement the new MCU telemetry API.

## Recovery plan items 1–4

The pre-change v2.5.17 source/products are archived under
`build/diagnostic_archive/` with hashes in `docs/recovery-items1-4.md`.
It is an unqualified diagnostic artifact. Current development separates lane
protocol reset from GT recovery and adds retained restart diagnostics at selector
0xFD. That step produced no new bitstream, qualification candidate, or hardware
test; v268 above is the subsequent diagnostic build. See that document for the
simulation matrix and its results.
Validation completed: eight unit/integrated HDL testbenches, two existing engine
testbenches and five offline diagnostic-decoder tests passed. Raw simulation
logs/trees are preserved in `build/diagnostic_archive/items1-4-validation.tar.gz`.
Integrity-detector capability remains unavailable pending characterization.

## Isolated signal-loss diagnostic 0x00020104 (2.5.4)

Milestone 2.5.4 is an isolated four-lane characterization image, not full-M3
v13. In this target only, lane error fields count RXPRBSERR-active cycles and
r38 monitors managed RXUSRCLK2. Its clean build and independent routed audit
pass with WNS `+0.490 ns`, WHS `+0.010 ns`, zero routing/DRC errors, golden RX
properties, and compression. The bitstream SHA-256 is
`c8f67ccee1e13cf534ff9ebe9612df48dee8e9434f158862d11393edc3a38772`;
the firmware SHA-256 is
`e28caefebc11651fb8dcd83266f405a8c6558bd007dce8cd7a3f2df57754b34d`.

Golden-IBERT fault control proved an isolated FireFly-5 channel-0 outage
produces sustained lane-12 PRBS corruption while FPGA RXCDRLOCK,
RXELECIDLE, RXRESETDONE, and RXUSRCLK remain healthy. The first freshly
programmed 2.5.4 external request failed acquisition before the FireFly
stimulus: only lane 15 ever locked and sequence 1/run ID 1 published
`0x04000404`. No output was disabled. Its result and post-fault platform,
clock, power, and module evidence were preserved; do not treat it as an outage
measurement or silently retry it. Full evidence is in
`docs/milestone254-signal-loss-characterization.md`.
After evidence capture, the golden image was restored and all four Quad-124
external PRBS31 links immediately ran with CDR lock, non-idle inputs, stable
RX clocks, and zero errors. The optical loopback is therefore healthy; the
2.5.4 blocker is managed external acquisition/startup. F1 was left on golden.

## Full Milestone 3 candidate 0x0002000C (v12)

V12 preserves the accepted v11 acquisition and measurement behavior and adds
native per-lane `RXCDRLOCK` to runtime lock qualification. Acquisition still
uses `RXPRBSLOCKED`; during measurement a lane is valid only while both PRBS
lock and CDR lock are asserted, and a falling edge of either increments the
existing ABI lock-loss counter. No register or result-record layout changed.

The clean Vivado 2023.2.2 build and independent routed audit passed on
2026-09-11. Both simulation suites pass, including the regression that holds
PRBS lock high while dropping only synthetic CDR lock. The routed image has
WNS `+0.141 ns`, TNS `0`, WHS `+0.009 ns`, THS `0`, and pulse-width slack
`+0.246 ns`; all 785,247 routable nets are fully routed with zero errors. All
four bus-skew constraints pass with worst slack `+19.437 ns`. DRC has zero
errors, five reviewed warnings (`PDCN-1569` x3, generic-I2C `RPBF-3` x1, and
`RTSTAT-10` x1), and 648 advisories. All 13 IP instances are current. The
audit confirms the 52+4+56 ownership split, managed sites X0Y16-X0Y19, golden
RX properties, compression, and four routed CDR-lock synchronizer pairs.

The main and versioned 69,787,395-byte bitstreams are identical, SHA-256
`35e8ba4ec565c9972e72e3ebf61ee842fd446d2b51d35650f1d9ec2b76ca180f`.
The 1,376-byte firmware ELF SHA-256 is
`637e1ee5fd20c3c6c9a4c384e3edde7ce55d51067870c4b4a94b0bf9210f41d1`.

F1 hardware identities read `0x0002000C`. The first fresh external sequence
1 failed in `LOCK_WAIT`: all four lanes remained unlocked for ten seconds,
while the quad was READY with power, QPLL, clocks, and all reset-done bits
healthy. Its run-ID-1 `0x04000404` result was preserved. After an explicit
reload, a ten-second near-end-PMA sequence 1 passed and the following
60-second external sequence 2/run ID 2 passed with zero errors and lock losses
over approximately 1.546848e12 bits per lane. A new sequence 3 intended for
the FireFly lock-loss stimulus again failed before RUN with all four lanes
unlocked; its run-ID-3 result was preserved and no stimulus occurred. After a
second explicit reload, even the first near-end-PMA sequence failed: lane 15
briefly locked, all lanes were unlocked at timeout, and the run-ID-1 result
was preserved. Power and the 37-clock monitor remained healthy during the
earlier failure capture. Hardware retries stopped at that point. V12 was
build- and routed-audit-accepted but not hardware-qualified; at that point,
intermittent managed-lane acquisition blocked the native CDR-loss test. The
later explicitly authorized attempt follows.

The user authorized a new hardware attempt on 2026-09-11. After an explicit
reload of the audited v12 image, ten-second near-end-PMA sequence 1/run ID 1
and 60-second external sequence 2/run ID 2 both passed with zero errors and
zero lock losses on all four lanes. Sequence 3/run ID 3 then performed the
intended 30-second external test while disabling only FireFly-5 channel 0 for
ten seconds. Byte 86 verified `0x00 -> 0x01 -> 0x00`; while disabled, module
LOS byte 3 was `0x11` (RX0/TX0) and CDR-LOL byte 5 was `0x01` (RX0). The
published result was `0x01030401`: lane 12 alone saturated its error counter,
while lanes 13-15 remained clean. However, lane 12 retained full-cycle
accounting, its lock-loss flag remained clear, and its lock-loss count was
zero. Native FPGA `RXCDRLOCK` therefore remained asserted through the
module-confirmed optical CDR loss, so v12 does not solve the required physical
lock-loss indication and is not hardware-qualified. The result was preserved
without a retry. Post-test AVTT/CC pages were healthy at 24.1875 A/1.20264 V
and 11.46875 A/0.90381 V, the managed reference measured 322.260 MHz, the
100/325-MHz clocks were exact, and the FireFly was restored at 41 C/3.3040 V.

## Full Milestone 3 candidate 0x0002000B (v11)

This candidate promotes the hardware-accepted Milestone 2.5.3 acquisition
behavior into the full 112-channel image: 52 left-IBERT lanes, four native
managed lanes at `GTYE4_CHANNEL_X0Y16`-`X0Y19`, and 56 right-IBERT lanes. It
uses staged TX-before-RX startup, a fixed 200,000-cycle (1-ms) acquisition
observation, a native-counter reset after the observation, and retains the
observation diagnostics throughout IDLE until the next stable running mask is
accepted.

The clean Vivado 2023.2.2 build and independent routed audit passed on
2026-09-02:

- Timing passes with WNS `+0.250 ns`, TNS `0`, WHS `+0.009 ns`, THS `0`, and
  pulse-width slack `+0.242 ns`.
- All 785,310 routable nets are fully routed with zero routing errors.
- All four bus-skew constraints pass; the worst slack is `+19.573 ns`.
- Routed DRC has zero errors, five reviewed warnings (`PDCN-1569` x3,
  established generic-I2C `RPBF-3` x1, and `RTSTAT-10` x1), and 648
  advisories.
- The audit confirmed the exact 112-channel ownership split, managed sites
  `X0Y16`-`X0Y19`, golden managed-GT RX properties, compressed-bitstream
  generation, and implemented 100.000/325.000-MHz clocks.
- All 13 IP instances are up-to-date. The routed CDC report retains the
  reviewed generated-IP and intentional-crossing findings; it is not described
  as globally CDC-clean.
- The controller, quad-controller, synthetic 112-lane engine, and full
  Milestone 3 mask/platform simulations pass, including acquisition error and
  unlock injection, retained diagnostic evidence, and clearing on the next
  accepted run.
- Synthesis took `9:45`; implementation took `1:40:50`. The full build then
  completed final reports, audit checks, and compressed bitstream generation.
- The main and versioned bitstreams are each 70,546,199 bytes and byte-for-byte
  identical. Their SHA-256 is
  `396e891f1df5ed079d892b0d59b5dbd35fef86bbda3877d05eb692c33da42449`:
  `build/gt_test_milestone3/gt_test_milestone3.runs/impl_1/gt_test_milestone3_top.bit`
  and
  `build/gt_test_milestone3/gt_test_milestone3.runs/impl_1/gt_test_milestone3_v11.bit`.
- The embedded 1,376-byte firmware ELF has SHA-256
  `c7917a3f56cfd9838d6fc66858e30db3897bfc9f08d407cbbf2d8e31bf9f5e84`.

The F1 short hardware gate passed on 2026-09-02. A ten-second lane-12 external
job entered RUN and completed normally with response/summary `0x00010101`,
zero errors, zero lock losses, 257,808,088,000 tested bits, and
`BER95 < 1.164e-11`. The retained acquisition observation recorded sampled
error mask `0x1`, sampled-unlock mask `0`, and maximum clean streak zero. The
actual measurement remained clean because the accepted 2.5.3 behavior resets
the native counter after the fixed acquisition observation. This is direct
evidence that the promoted startup-transient isolation is operating in the
full image.

The following four-lane 60-second external smoke also passed. Firmware and
hardware versions were both `0x0002000B`; request/response sequence was `3`,
the run ID advanced once to `2`, final state was IDLE, and response/summary was
`0x00040401`. Lanes 12-15 each recorded zero errors, zero lock losses,
1,546,847,993,200 tested bits, 19,335,599,915 valid cycles, and
`BER95 < 1.939e-12`. The retained acquisition observation recorded sampled
error mask `0xF` and sampled-unlock mask `0`; those startup observations were
excluded by the post-observation native-counter reset, and no first-fault
snapshot was present. Candidate v11 is therefore build-, audit-, and
short-smoke-accepted.

The 12-hour four-lane external soak passed on F1 and completed at
`2026-09-03T06:24:05+00:00`. It was launched after the successful 60-second
run as request sequence `4` following sequence `3`. Lanes 12-15 each reported
status `0x0000180c` through `0x0000180f`, zero errors, zero lock losses,
1,113,730,526,168,800 tested bits, 13,921,631,577,110 valid cycles, and
`BER95 < 2.694e-15`. The operator script reported
`12-HOUR EXTERNAL SOAK PASSED`. The final mailbox was healthy IDLE with
matching request/response sequence `4`, response/summary `0x00040401`, and
stable hardware run ID `3`, exactly one beyond the pre-run ID `2`. The complete
operator log is
`docs/evidence/legacy/milestone3_12hour_soak_20260902_182351.log`. Final F1 AVTT current
and FPGA temperature are not present in the log and remain to be appended to
the test record.

Candidate v11 is therefore build-, routed-audit-, short-smoke-, 12-hour-soak-,
and 24-hour-qualification-accepted. The final 24-hour results captured in
`docs/evidence/legacy/24hour.txt` on 2026-09-10 show firmware/hardware `0x0002000B`, matching
request/response sequence `5`, stable hardware run ID `4`, response/summary
`0x00040401`, and healthy IDLE. Lanes 12-13 each recorded
2,227,461,058,375,760 tested bits and 27,843,263,229,697 valid cycles; lanes
14-15 each recorded 2,227,461,058,375,680 tested bits and
27,843,263,229,696 valid cycles. All four lanes had zero errors, zero lock
losses, exact 80-bit-per-cycle accounting, and `BER95 < 1.347e-15`. No
first-fault snapshot was valid. Retained acquisition diagnostics recorded
sampled-error mask `0xF`, sampled-unlock mask `0`, and maximum clean streak
zero; the post-observation native-counter reset excluded those startup samples
from measurement. The SSH connection died during the run, so the half-hour
watcher output was not retained and this evidence is limited to the final
snapshot. The exact completion timestamp, final F1 AVTT current, and FPGA
temperature remain to be appended. At that point, targeted measurement-time
error injection, forced single-lane lock-loss, abort/timeout, and
CPU-halted-completion regressions remained required; their current outcomes
follow.

The first three short v11 fault-path regressions ran on F1 on 2026-09-11,
continuing directly from the accepted sequence-5/run-ID-4 soak result:

- Sequence 6/run ID 5 was a five-minute, four-lane near-end-PMA PRBS31 job.
  Exactly one AXI injection toggle was issued on global lane 12 while the
  engine was in `ST_RUN`. Lane 12 recorded exactly one error; lanes 13-15
  recorded zero. Every lane had zero lock losses, no saturation, and exact
  80-bit-per-cycle accounting. Matching response/summary `0x01030401` and
  healthy IDLE prove measurement-time error visibility and lane isolation.
- Sequence 7/run ID 6 was a five-minute near-end-PMA job aborted through AXI
  control offset `0x00C` bit 1 after approximately 36.6 seconds. Matching
  response/summary `0x00040402` reported stop reason 2. All four atomic partial
  records had zero errors and lock losses, no saturation, and exact
  80-bit-per-cycle accounting.
- Sequence 8/run ID 7 requested five minutes of near-end-PMA PRBS31 with a
  60,000-ms timeout. Matching response/summary `0x00040403` reported stop
  reason 3. All four atomic partial records had zero errors and lock losses,
  no saturation, and exact 80-bit-per-cycle accounting.

The next sequence-9 CPU-halted-test launch did not reach `ST_RUN` and was not
retried. It published run ID 8, matching response/summary `0x04000404`, and a
platform-fault result. The retained first-fault record is PRBS state 8
(`LOCK_WAIT`) at 1,999,999,999 sequencer cycles (10 seconds): selected/running
mask `0xF`, locked/ever-locked mask `0xB`, and no acquisition-ready assertion.
Thus lane 14 alone failed to acquire PRBS lock. Quad state remained READY with
power mask `0xF`, QPLL and TX/RX user clocks asserted, and TX/RX reset-done
mask `0xF`; no external link partner participates in this near-end-PMA mode.
Post-fault clock monitoring was valid: `lf_r0_af=322.260 MHz`,
`clk_100=100.000 MHz`, and `clk_325=325.000 MHz`. F1 AVTT/CC PMBus page 0
read 11.9219-V input, 1.2078-V output, 24.5-A output current, 42.7-C regulator
temperature, and no status fault; page 1 was also fault-free. The deployed MCU
does not implement its telemetry page, so FPGA die temperature remains
unavailable. This record was preserved before an explicit reconfiguration.

F1 was then reloaded with the same audited v11 bitstream (70,546,199 bytes,
SHA-256 `396e891f1df5ed079d892b0d59b5dbd35fef86bbda3877d05eb692c33da42449`).
The fresh post-reload CPU-halted regression passed as sequence 1/run ID 1.
After the request reached `ST_RUN`, XSDB verified AXI state `0x00000002` and
halted MicroBlaze at PC `0x220`. Hardware completed the five-minute job while
the processor remained stopped, published summary `0x00040401`, advanced run
ID exactly once, and held interrupt-pending state `0x00004000`; CPU-owned
response sequence/code remained zero. Lanes 12-15 reported zero errors and
lock losses, no saturation, and exact 80-bit-per-cycle accounting over
7,734,240,175,840-7,734,240,176,000 tested bits. After `con`, firmware
acknowledged sequence 1 and the existing summary, retained run ID 1, and
returned to healthy IDLE without launching another job. Forced single-lane
lock-loss isolation remained required.

The final physical fault stimulus used the installed F1 FireFly-5 x4 module,
part `B0425040011201`, at fixed MCU FireFly index 8. The mutable `it_dtc`
registry preset incorrectly packed F1_5 onto index 0, which identifies a
12-channel `ECUOT12...` device; a first attempted write read back unchanged
and caused no disturbance. Post-reload sequences 2 and 3 therefore completed
as clean no-disturbance controls. The corrected
`scripts/milestone3_firefly_lock_loss.py` constructs F1_5 at physical index 8,
uses lower-page byte 86 (`0x56`) as the four-bit TX-disable mask, preserves the
complete original byte, verifies the disabled value, and restores the exact
original value in a `finally` path.

Post-reload sequence 4/run ID 4 held only byte-86 bit 0 high for one second;
sequence 5/run ID 5 repeated the same operation for ten seconds. Readback
verified `0x00 -> 0x01 -> 0x00` in both runs, mapping FireFly-5 channel 0 to
global lane 12. Both five-minute external jobs completed normally with
matching summary `0x01030401`: lane 12 alone saturated its exact error counter
at `4,294,967,295`, while lanes 13-15 reported zero errors and every lane was
locked at stop. Neither outage caused `RXPRBSLOCKED` to deassert; lane 12 kept
counting valid cycles throughout and reported zero lock losses. The ten-second
run recorded 7,734,239,933,120 tested bits per lane, with no adjacent-lane
corruption. F1_5 was restored to byte 86 `0x00`, status/fault/LOS latch bytes
were all zero, CDR-enable was `0xFF`, module temperature was 41 C, and supply
was 3.3040 V. All 37 monitor clocks remained valid, including
`lf_r0_af=322.259 MHz`, `clk_100=100.000 MHz`, and `clk_325=325.000 MHz`.
F1AVTT/CC PMBus pages were fault-free; page 0 reported 24.25 A and 42.6875 C.
The physical single-lane disturbance and adjacent-lane isolation passed, but
the required v11 lock-loss indication did not. Candidate v11 is therefore not
fully hardware-qualified. Post-reload sequence 6/run ID 6 repeated the
ten-second channel-0 disable while sampling incorrect candidate alarm
addresses `0x07` and `0x15`; those zero reads are not interpreted as module
status. Post-reload sequence 7/run ID 7 repeated the same controlled outage
using the correct read-to-clear interrupt bytes. The baseline read intentionally
cleared prior history. While byte 86 bit 0 was asserted, LOS byte 3 read
`0x11`, identifying RX0 and TX0, and CDR-LOL byte 5 read `0x01`, identifying
RX0. This proves that the physical module detected isolated channel-0 signal
and CDR loss. After restoration the flags reasserted during recovery as LOS
`0x11` and CDR LOL `0x11`. The final FPGA result remained `0x01030401`:
lane 12 alone saturated its error counter, lanes 13-15 stayed clean, all lanes
were locked at stop, and every FPGA lock-loss count was zero. V11's runtime
lock-loss detector therefore failed to reflect a module-confirmed loss event.

## Isolated Milestone 2.5.5/2.5.6 characterization

Isolated 2.5.5 (`0x00020105`) added a single external RX-datapath recovery
reset. Its signal-loss measurement completed, but teardown exposed a latched
RX-done platform fault after publication. Isolated 2.5.6 (`0x00020106`) added
an opt-in post-capture requalification state and passed its clean unit suite,
build, and routed audit. Timing is WNS `+0.592 ns`, WHS `+0.009 ns`, and WPWS
`+0.454 ns`; all 23,684 routable nets are fully routed and DRC has no errors.

Fresh 2.5.6 sequence 1/run ID 1 passed the ten-second FireFly-5 channel-0
outage inside a 30-second run. Lane 12 alone recorded 8,870,131,729
RXPRBSERR-active cycles out of 9,667,809,834 valid cycles (`0.917491`), with
zero adjacent-lane errors and zero lock-loss counts. RXUSRCLK2 remained
322.260-322.261 MHz. Sequence 2/run ID 2 then failed in `LOCK_WAIT` before the
planned single-error injection; only lane 15 ever locked after the one
recovery reset. Its `0x04000404` result and healthy power/module telemetry
were preserved without retry. A golden reload immediately returned all four
links to zero-error operation, so the managed recovery is not repeatable.
See `docs/milestone256-signal-loss-characterization.md`. F1 is on golden.

## Isolated Milestone 2.5.3 candidate 0x00020103

This candidate changes only the lifetime of the fixed-window diagnostics
accepted in 2.5.2. Completed error/unlock masks and maximum clean streak remain
readable throughout IDLE; they clear when the controller accepts the next
stable running mask. The acquisition sequence, fixed 1-ms observation,
post-observation native-counter reset, and measurement behavior are unchanged.

The clean Vivado 2023.2.2 build and independent routed audit passed on
2026-09-02:

- Timing passes with WNS `+0.497 ns`, TNS `0`, WHS `+0.009 ns`, THS `0`, and
  pulse-width slack `+0.454 ns`.
- All 23,828 routable nets are fully routed with zero routing errors.
- DRC has zero errors and the single established generic-I2C `RPBF-3` warning.
- The audit confirmed exactly `GTYE4_CHANNEL_X0Y16`-`X0Y19`, golden managed-GT
  RX properties, compression, and implemented 100.000/325.000-MHz clocks.
- All 11 IP instances are up-to-date. CDC/methodology findings retain the same
  reviewed qualifications as 2.5.2 and are not described as globally clean.
- All three RTL simulations pass. The fixed-window test injects an acquisition
  error and unlock, completes result capture, verifies evidence persists in
  IDLE, and verifies it clears when the following run is accepted.
- Synthesis took `1:35`; implementation took `5:48`, including placement
  `2:35`, routing `0:44`, and bit generation `0:59`.
- The 31,258,584-byte bitstream is
  `build/gt_test_milestone253/gt_test_milestone253.runs/impl_1/gt_test_milestone253.bit`,
  SHA-256
  `ccbf43e3b3c5e7456681a48f904e62ff38102b1fa958053349b35a357d6a15eb`.
  Its embedded 1,380-byte ELF SHA-256 is
  `98bd47628cff44a295ad3fdc09f6f41649f84873c393ced8aeae8cc5e522d34d`.

The focused F1 check passed on 2026-09-02. The ten-second lane-12 external job
completed normally with zero errors, zero lock losses, and 257,808,252,880
tested bits (`BER95 < 1.164e-11`). The retained fixed-window observation was
also exactly as expected: sampled-error mask `0`, sampled-unlock mask `0`, and
maximum clean streak 200,000 cycles (1.000 ms). This confirms both the 2.5.2
acquisition behavior and the 2.5.3 diagnostic-lifetime correction in hardware.
Use 2.5.3 as the accepted baseline for the next full-M3 candidate.

## Isolated Milestone 2.5.2 candidate 0x00020102

This quad-124-only follow-up implements fixed-window staged acquisition. It
preserves the 2.5.1 TX-before-RX sequence, observes checker behavior for a
fixed 200,000 management-clock cycles (1 ms), records error/unlock causes and
the maximum clean streak, resets native counters, and proceeds to measurement.
The existing continuously clean qualification remains the default for every
other target; 2.5.2 selects the new behavior explicitly with
`REQUIRE_ERROR_FREE_QUALIFICATION=0`.

The clean Vivado 2023.2.2 build and independent routed-checkpoint audit passed
on 2026-09-02:

- Timing passes with WNS `+0.641 ns`, TNS `0`, WHS `+0.010 ns`, THS `0`, and
  pulse-width slack `+0.454 ns`.
- All 23,880 routable nets are fully routed with zero routing errors; the
  isolated target has no bus-skew constraints.
- The audit found exactly `GTYE4_CHANNEL_X0Y16`-`X0Y19`, confirmed the golden
  managed-GT RX properties, compressed-bitstream generation, and implemented
  100.000-MHz and 325.000-MHz clocks.
- Routed DRC has zero errors and the single established generic-I2C `RPBF-3`
  warning. CDC/methodology findings retain the same reviewed generated-IP and
  intentional-crossing qualifications; the image is not described as
  globally CDC-clean.
- The fixed-window controller simulation injected both an error and an unlock,
  verified their retained masks and maximum-clean counter, and confirmed that
  measurement begins after the post-observation counter reset. The original
  staged clean-gate and quad-controller simulations also pass.
- The clean run took about 9 minutes 47 seconds overall: synthesis `3:02`,
  implementation `5:50` (placement `2:35`, routing `0:48`), and bit generation
  `0:57` within those run phases.
- The 31,370,180-byte bitstream is
  `build/gt_test_milestone252/gt_test_milestone252.runs/impl_1/gt_test_milestone252.bit`,
  SHA-256
  `fa11864232fec030c071cc9b5e91a3520afbfbc5a3530c8bcb51d7d59ddef213`.
  Its embedded 1,380-byte ELF SHA-256 is
  `8568671533e4034ae55d0576163adc8e74838af737182888f36ea8f918138451`.

F1 hardware acceptance passed on 2026-09-02. All five jobs entered RUN,
completed normally, and published the expected response/summary values:

- lane-12 external first run: zero errors and zero lock losses;
- lane-12 external repeat: zero errors and zero lock losses;
- four-lane external: all four lanes passed with zero errors/lock losses;
- four-lane near-end PMA: all four lanes passed with zero errors/lock losses;
- lane-12 external after PMA: zero errors and zero lock losses.

Each ten-second lane accumulated approximately 257.8 billion tested bits,
giving a zero-error 95% BER upper bound of `1.164e-11`. This establishes that
fixed-duration acquisition followed by the post-acquisition native-counter
reset resolves the first/repeat managed-PRBS failures seen in v2.5 and v10.

The printed 2.5.2 acquisition-observation masks and maximum-clean-streak value
were all zero after completion. They are not valid evidence that acquisition
was clean: the current RTL clears those retained fields in IDLE after the run.
If those diagnostics are needed in a later image, preserve them until the next
request is accepted rather than clearing them on return to IDLE.

## Isolated Milestone 2.5.1 candidate 0x00020101

This diagnostic image was created to test the TX/RX PRBS-control ordering
hypothesis quickly on quad 124 while leaving preserved v2.5 and full Milestone
3 unchanged. In the staged mode, TXPRBSSEL is established first, RXPRBSSEL is
held at zero until TX-control settling completes, and the controller then
requires one millisecond of continuously locked and sampled-error-free
operation before a post-acquisition counter reset and measurement. Existing
state values 0 through 19 remain unchanged; the new checker-settle and
error-free-qualification states are 20 and 21.

The clean Vivado 2023.2.2 build and independent routed-checkpoint audit passed
on 2026-09-02:

- Timing passes with WNS `+0.290 ns`, TNS `0`, WHS `+0.010 ns`, THS `0`, and
  pulse-width slack `+0.454 ns`.
- All 23,911 routable nets are fully routed with zero routing errors. The
  isolated target has no bus-skew constraints.
- The audit found exactly four managed channels at
  `GTYE4_CHANNEL_X0Y16`-`X0Y19`, confirmed the golden managed-GT RX
  properties, and confirmed compressed-bitstream generation.
- Implemented clocks include 100.000 MHz and 325.000 MHz; GT and reference
  clocks use the expected rounded 322.269-MHz timing constraints.
- Routed DRC has zero errors and the single established `RPBF-3` warning for
  incomplete bidirectional buffering on generic-I2C SCL. CDC/methodology
  findings remain review items and are not described as globally clean.
- Synthesis took `1:26`, placement `2:54`, routing `0:47`, bit generation
  `0:54`, and the implementation run took `6:10` elapsed.
- The 31,660,764-byte bitstream is
  `build/gt_test_milestone251/gt_test_milestone251.runs/impl_1/gt_test_milestone251.bit`,
  SHA-256
  `633f8724842c808f395abca4ee96dbab952221e7003e36aabf04026d191cd89f`.
  Its embedded 1,380-byte ELF SHA-256 is
  `3057bdc16aa1c0f74d8c27192768b544dcce3bd940b037752c64a5faab33f098`.

RTL unit simulations for both the quad controller and staged PRBS controller
pass. The staged test verifies that RX checking stays disabled during TX
settling, an acquisition error restarts the clean qualifier, counters are
reset after qualification, and measurement begins afterward. The image is
implementation-qualified but not hardware-accepted. Program it only for the
separate `scripts/milestone251_acceptance.py` matrix.
Platform faults are decoded automatically by that script and can be reread
non-destructively with `scripts/milestone251_platform_diagnostics.py`.

The first F1 hardware run rejected the staged-acquisition candidate before
measurement. Lane 12 reached `ST_ERROR_FREE_QUALIFY` (state 21), acquired PRBS
lock, but never completed a continuously clean 1-ms interval during the full
1,999,999,999-cycle / 10.000-s timeout. The first-fault snapshot was
`fault_prbs=0x80111115`, with lane 12 selected, running, and locked at the
terminal sample; all Wizard, RXRESETDONE, RXPMARESETDONE, QPLL, TX-clock, and
RX-clock qualifiers were healthy. The engine published platform-fault summary
`0x01000104`. Therefore TX-before-RX staging alone is insufficient. The
current snapshot does not distinguish intervening RXPRBSERR samples from
brief unlocks because neither cause nor maximum clean streak is retained.
Before another candidate, add qualification error/unlock cause bits and a
maximum-clean-streak diagnostic, or deliberately bypass the clean gate to
measure the staged path's exact native error count.

## Full Milestone 3 candidate 0x0002000A

The first v9 lane-12 external launch accepted request sequence 2 but remained
in engine ARM state `C8=0x00000001` for more than 15 seconds. Selector `0xFE`
showed a healthy READY quad, PRBS controller IDLE, synchronized running and
locked masks `0x1`, selected mask zero, no fault snapshot, and the ARM-time RX
qualification asserted. This proves the failure occurred before physical
acquisition and is not a lane or optical-link result.

The v9 stable-running-mask filter loaded its settle counter with one when the
first synchronized mask arrived, but omitted the assignment that increments
the counter while the mask remains unchanged. It could therefore never reach
the required stable count or leave controller IDLE. Candidate `0x0002000A`
adds that missing increment. The PRBS-controller testbench now also has a
bounded watchdog so any future no-progress regression fails explicitly rather
than hanging a wait-based simulation. Hardware and firmware identities are
both `0x0002000A`; firmware rebuild, RTL compilation, and elaboration pass.
This host's known XSim runtime exception still prevents executing the snapshot.

The clean Vivado 2023.2.2 build and independent routed-checkpoint audit
completed successfully on 2026-09-02:

- Routed timing passes with WNS `+0.238 ns`, TNS `0`, WHS `+0.009 ns`, THS
  `0`, pulse-width slack `+0.247 ns`, and no failing endpoints.
- All 785,339 routable nets are fully routed with zero routing errors. All
  four 20-ns bus-skew constraints pass; the smallest slack is `+19.578 ns`.
- Implemented clocks include `clk_100_raw` at 100.000 MHz and `clk_325_raw`
  at 325.000 MHz. The rounded 3.103-ns GT reference-clock constraints appear
  as 322.269 MHz in the timing report.
- Routed DRC has zero errors. Its five warnings are the established three
  generated debug-hub `PDCN-1569` findings, one generic-I2C `RPBF-3` finding,
  and one generated debug/IBERT `RTSTAT-10` finding. The remaining 648
  advisories are generated-IP DSP power recommendations. All 13 project IP
  instances are up-to-date with no changes required.
- The detailed routed CDC report is not globally clean: `CDC-1=1`,
  `CDC-3=17342`, `CDC-6=240`, `CDC-9=327`, `CDC-10=22`, `CDC-11=44`,
  `CDC-13=4`, and `CDC-15=17835`. The four `CDC-13` paths are the deliberate
  selected-lane pulse into the GT primitive `RXPRBSCNTRESET` pins. The
  remaining findings are the already reviewed generated GT/IBERT/debug
  structures, Gray counters, stable engine control/toggle crossings, and
  generic-I2C readback paths; do not describe the image as CDC-clean.
- Compression, 112-channel ownership, the managed sites
  `GTYE4_CHANNEL_X0Y16`-`X0Y19`, and all audited golden managed-GT RX
  properties pass. The router reports the same legal north/south GT
  reference-clock pin swaps seen in prior candidates.
- The 70,098,947-byte bitstream is
  `build/gt_test_milestone3/gt_test_milestone3.runs/impl_1/gt_test_milestone3_top.bit`,
  SHA-256
  `fa4042fd1def68935e34e5c4d282d5db7416cc1182518b3a46c4e2f5fb40d268`.
  The embedded 1,376-byte firmware ELF has SHA-256
  `55ad0f21fa0b9b47c17460d4f73ccaa7a7d58b22231777077e875064f309ad3d`.
- Synthesis ran from 22:13:43 through 22:23:30 EDT (`9:47`). Implementation
  ran from 22:45:18 through 00:24:21 (`1:39:04`), final build checks completed
  at 00:33:20, and the independent routed audit passed at 06:48:34.

Candidate v10 is implementation-qualified but not yet hardware-accepted. Its
first lane-12 external-path diagnostic accepted request sequence 2, entered
and completed the ten-second measurement, and returned to healthy IDLE. This
proves the v10 stable-mask progress fix resolves the v9 ARM hang. The run was
nevertheless a coherent one-error failure: aggregate `0x01000101`, lane status
`0x0000180C`, exactly one native PRBS error, zero lane lock losses, no counter
saturation, 257,808,079,360 tested bits, and 3,222,600,992 valid cycles. The
bit count is exactly 80 times the valid-cycle count. Platform state remained
healthy and no first-fault snapshot was valid. Repeat the identical lane-12
test without reprogramming before attempting the all-four-lane smoke; a
repeatable exact one count would implicate the post-lock counter-reset to
measurement boundary.

## Superseded full Milestone 3 candidate 0x00020009

The `0x00020008` external smoke entered and completed its 60-second interval
with a healthy quad and normal stop, but lanes 12 and 15 failed while lanes 13
and 14 passed. Ten-second single-lane repetitions proved both failing lanes
were correctly selected, locked without an in-test lock loss, and saturated
their native PRBS error counters. The all-lane run also exposed an independent
CDC issue: the PRBS controller captured partial running mask `0x7` before the
fourth independently synchronized bit arrived.

An exhaustive synthesized-property comparison between the passing isolated
Milestone 2.5 managed GT and the full-M3 managed GT found no primitive-setting
differences; the only reported differences were generated source-file paths.
Package pins are also identical. The passing M2.5 external test left the live
receiver running, whereas later full-M3 candidates introduced an external
`GTRXRESET` to suppress an ARM-time supervisor fault.

Candidate `0x00020009` restores the proven live-RX external acquisition while
asserting a management-domain ARM qualifier from the engine doorbell through
lock, so expected temporary RX-status changes cannot trigger the old platform
fault. PMA loopback retains its complete RX/PMA reset sequence. Both modes
retain the post-lock native-counter reset. The controller now requires the
independently synchronized running vector to remain stable before capture and
records lock history only through acquisition/measurement, avoiding normal
cleanup being labeled as a lock loss. Hardware and firmware identities are
both `0x00020009`.

The clean Vivado 2023.2.2 build and independent routed-checkpoint audit
completed successfully on 2026-09-01:

- Routed timing passes with WNS `+0.146 ns`, TNS `0`, WHS `+0.009 ns`, THS
  `0`, pulse-width slack `+0.243 ns`, and no failing endpoints.
- All 784,597 routable nets are fully routed, with zero routing errors. All
  four 20-ns bus-skew constraints pass; the smallest slack is `+19.601 ns`.
- Implemented clocks include `clk_100_raw` at 100.000 MHz and `clk_325_raw`
  at 325.000 MHz. The rounded 3.103-ns GT reference-clock constraints appear
  as 322.269 MHz in the timing report.
- Routed DRC has zero errors. Its five warnings are the established three
  generated debug-hub `PDCN-1569` findings, one generic-I2C `RPBF-3` finding,
  and one generated debug/IBERT `RTSTAT-10` finding. The remaining 648
  advisories are generated-IP DSP power recommendations. All 13 project IP
  instances are up-to-date with no changes required.
- The detailed routed CDC report is not globally clean, but improves over v8:
  `CDC-1=1`, `CDC-3=17342`, `CDC-6=240`, `CDC-9=327`, `CDC-10=10`,
  `CDC-11=44`, and `CDC-15=17835`. The removed `CDC-13` findings and twelve
  fewer `CDC-10` findings follow from the v9 control changes. The remaining
  findings are the already reviewed generated GT/IBERT/debug structures,
  Gray counters, stable engine control/toggle crossings, and generic-I2C
  readback paths; do not describe the image as CDC-clean.
- The synthesized methodology report remains noisy for generated dynamic GT
  clocks and IBERT/debug structures. Its capped `TIMING-7` and `TIMING-17`
  findings are unchanged in character from prior accepted implementations;
  authoritative routed timing nevertheless passes. Synthesis confirms all
  four externally decoded engine/quad/PRBS state registers retain
  `fsm_encoding="none"` and were not recoded.
- The router reports the same north/south GT reference-clock pin swaps onto
  the physically equivalent dedicated resources seen in prior candidates.
  Managed quad 124 remains exactly at `GTYE4_CHANNEL_X0Y16`-`X0Y19`; its
  audited placement and golden RX properties are unaffected.
- Compression is enabled. Bit generation completed with zero errors and zero
  critical warnings. The 70,686,055-byte bitstream is
  `build/gt_test_milestone3/gt_test_milestone3.runs/impl_1/gt_test_milestone3_top.bit`,
  SHA-256
  `ded0954bf9c7bfadfac5d2ad3305bb9b38ffe5dc340aad4d29ccf9027cb1742d`.
  The embedded 1,376-byte firmware ELF has SHA-256
  `4089877ad6583f2beee2e9df1c5d027c28ec2b3f9ddb9159c3b2ed836ebe7bba`.
- Synthesis was launched at 19:31:50 EDT, implementation ran from 20:03:27
  through 21:41:46 (`1:38:19`), final build reports completed at 21:50:51,
  and the independent routed audit passed at 22:02:19.

This candidate was implementation-qualified but failed its first hardware
launch because the stable-mask counter never advanced. Do not program it for
further testing; v10 contains the deterministic progress fix.

## Full Milestone 3 candidate 0x00020008

The first `0x00020007` external smoke accepted request 1 but did not enter
`ST_RUN`. It published platform-fault summary `0x04000404` and AXI status
`0xE08080C4`: the quad remained READY with healthy reset qualifiers, while the
PRBS controller retained `ST_LOCK_WAIT` after its one-second bound expired.

Candidate `0x00020008` extends the bounded acquisition wait to ten seconds and
adds seven diagnostic words. Three report live PRBS/RX/quad context; four
retain the first fault's PRBS, RX, quad, and elapsed-cycle context until FPGA
reset. Lock context includes selected, running, current, ever-locked, and
lost-after-lock masks. Reserved result selector `0xFE` mirrors platform status
and all seven words through the existing I2C `0xD0`-`0xEC` window. The Python
3.6 smoke/soak utilities decode this page automatically on launch failure.
Firmware version and hardware identity are both `0x00020008`. The firmware
build passes; controller testbenches compile and elaborate, while this host's
known missing XSim runtime kernel still prevents execution. The first licensed
synthesis pass was intentionally stopped after Vivado attempted to exchange
the externally visible quad `ST_FAULT=5` and `ST_RX_REQUAL=6` encodings. The
engine, quad, and PRBS state registers now carry `fsm_encoding="none"`; the
accepted synthesis reports four instances of FSM extraction being disabled
and no attempted recoding of these registers.

The clean Vivado 2023.2.2 build completed successfully on 2026-09-01:

- Routed timing passes with WNS `+0.139 ns`, TNS `0`, WHS `+0.009 ns`, THS
  `0`, pulse-width slack `+0.241 ns`, and zero failing endpoints.
- All 784,712 routable nets are fully routed, with zero routing errors. All
  four bus-skew constraints pass; the smallest slack is `+19.358 ns`.
- Implemented clocks include `clk_100_raw` at 100.000 MHz and `clk_325_raw`
  at 325.000 MHz.
- Routed DRC has zero errors. Its warnings are three generated debug-hub
  `PDCN-1569` findings, one generic-I2C `RPBF-3` finding, and one generated
  debug/IBERT `RTSTAT-10` finding; 648 generated-IBERT DSP power advisories
  remain. All 13 project IP instances are up-to-date with no changes required.
- The detailed CDC and methodology reports remain globally noisy for the
  generated IBERT, GT Wizard, debug hub, asynchronous clock monitors, and
  intentionally stable control crossings. The routed CDC summary is
  `CDC-1=1`, `CDC-3=17342`, `CDC-6=240`, `CDC-9=327`, `CDC-10=22`,
  `CDC-11=44`, `CDC-13=4`, and `CDC-15=17835`; retain these findings for
  explicit review rather than describing the image as CDC-clean.
- Compression is enabled and bit generation completed with zero errors and
  zero critical warnings. The bitstream is 70,608,035 bytes at
  `build/gt_test_milestone3/gt_test_milestone3.runs/impl_1/gt_test_milestone3_top.bit`,
  SHA-256
  `85ef03f28d60b93b1b5bb45546d4745572c9f937638e664d560e81877c067ce0`.
- The Vivado session ran from 15:13:10 to 17:31:25 EDT (`2:18:15`). The
  implementation run itself took `1:35:38`.

This candidate is implementation-qualified but not hardware accepted. The
next gate is the 60-second external-path smoke using the v8 Python script;
if launch fails, capture the automatically decoded selector-`0xFE` diagnostic
page before reprogramming.

## Superseded full Milestone 3 candidate 0x00020007

The `0x00020006` external-path test entered and completed its 60-second HDL
interval normally, but lanes 12, 14, and 15 published saturated native PRBS
error counts while lane 13 passed. All four lanes were locked at stop, none
reported a lock loss, and all had the same tested-bit and valid-cycle counts.
The PRBS controller cleared native error counters before waiting for checker
lock, so errors accumulated during acquisition remained in the timed result.

Candidate `0x00020007` adds a second bounded selected-lane counter-reset pulse
after every selected lane is locked and before `acquisition_ready` starts the
measurement. The controller testbench now checks this ordering for both PMA
loopback and external-path acquisition. `xvlog` compilation and `xelab`
elaboration pass; this host's XSim runtime cannot execute because the Vivado
installation lacks `librdi_simulator_kernel.so`, so the new assertions still
require execution on a complete XSim installation.

The matching MicroBlaze firmware built successfully and was embedded in the
bitstream. The clean Vivado 2023.2.2 implementation and dedicated routed audit
passed on 2026-09-01:

- Routed timing: WNS `+0.119 ns`, TNS `0`, WHS `+0.009 ns`, THS `0`, and
  pulse-width slack `+0.251 ns`, with zero failing endpoints.
- Routing: 784,885 of 784,885 routable nets fully routed and zero routing
  errors.
- All four bus-skew constraints pass; worst slack is `+19.600 ns` against the
  20-ns requirement.
- Routed DRC has zero errors, with three `PDCN-1569`, one `RPBF-3`, and one
  `RTSTAT-10` generated debug/IP warning. The pre-bitstream DRC reports four
  warnings and 648 advisories.
- Implemented clock periods are 10.000 ns for `clk_100_raw` and 3.077 ns for
  `clk_325_raw`, corresponding to 100.000 MHz and approximately 325.000 MHz.
- Compression is enabled. The routed audit confirms 112 GT channels, 28 GT
  commons, 52 reduced-left IBERT lanes, 56 right-IBERT lanes, and managed
  quad-124 sites `GTYE4_CHANNEL_X0Y16` through `X0Y19`; audited managed-GT RX
  properties match the golden values.
- Implementation ran from 12:06 to 13:47 EDT (`1:41:22`). The full outer
  build and audit finished at 13:56 EDT.
- Bitstream:
  `build/gt_test_milestone3/gt_test_milestone3.runs/impl_1/gt_test_milestone3_top.bit`
  (70,619,719 bytes), SHA-256
  `3ce07b01b3e7b3c14483897dbd5c00ecc71a1ecdf38779276c266497ed131ce7`.

This candidate is implementation-qualified but not hardware accepted. The
next gate is the 60-second external-path smoke; do not restart the 12-hour
soak until that run returns `0x00040401` with zero errors and lock losses on
lanes 12-15.

## Last validated implementation

The clean documented batch flow was revalidated on 2026-08-25 and wrote a
valid bitstream. That previously generated artifact is uncompressed; source
policy now requires compression for its next build. Routing had 800,029 fully routed nets and no
failed, unrouted, partially routed, or overlapping nets.

- Overall setup: WNS `+0.258 ns`, TNS `0`, no failing endpoints.
- Overall hold: WHS `+0.009 ns`, THS `0`.
- Pulse width: WPWS `+0.251 ns`, TPWS `0`.
- Routed clock report: `clk_200` 200.000 MHz, `clk_100_raw` 100.000 MHz,
  `clk_325_raw` 325.000 MHz, and `ibert_debug_clk_50` 50.000 MHz.
- The overall worst setup path is an IBERT RX/TX user-clock relationship, not the 200-MHz or debug network.
- Bitstream: `build/vu13p_ibert_25g.runs/impl_1/top.bit`.
- Bitstream SHA-256: `e6f49cef8ff91381ca2470c9b4860e90d13ea5ed98e48562ff14288365541e83`.
- Timing report: `build/vu13p_ibert_25g.runs/impl_1/top_timing_summary_routed.rpt`.
- All four reported bus-skew constraints pass; the smallest slack is
  `+19.250 ns`.

## HDL-first synthetic test-engine state

The first opt-in HDL-first migration target is implemented separately from the
golden `top` target. The golden project, generated IBERT wrappers, and 112-lane
IBERT ownership are unchanged.

- `gt_test_engine_core` accepts one AXI descriptor and controls 112 concurrent
  lane engines through toggle/acknowledge CDC handshakes.
- Per-lane snapshots contain status, 64-bit error and tested-bit counters,
  lock-loss count, and 64-bit valid-cycle time.
- Two 112-by-256-bit result banks infer as eight `RAMB36E2`; publication is an
  atomic bank swap followed by one completion interrupt.
- The generic-I2C mailbox occupies `0xA0`-`0xFF` at slave address `0x2B` and
  does not reassign the deployed `0x00`-`0x9F` monitor ABI. Those lower
  addresses read zero in the standalone synthetic top; the golden image still
  provides the operational clock-monitor registers.
- Synthetic simulation passes all-112-lane completion with the AXI master idle
  after the doorbell, immutable published results, isolated error/lock-loss
  injection, abort, timeout, bad-command rejection, and one interrupt.
- Out-of-context synthesis completes with zero errors, critical warnings, or
  warnings and infers eight `RAMB36E2` blocks.
- The separate Milestone 2 target now includes a Tcl-generated 200-MHz
  MicroBlaze, 32 KiB local BRAM, MDM/JTAG, 564-byte freestanding firmware, AXI
  test engine, direct level interrupt, and I2C mailbox. Version `0x00010002`
  has no AXI interrupt controller and drives the engine level into both
  `Interrupt` and the discrete `Wakeup[0]`; MDM `Dbg_Wakeup` drives
  `Wakeup[1]`.
- MicroBlaze uses no caches/MMU and sleeps after one descriptor/doorbell write;
  the ISR publishes the already-snapshotted hardware result without polling
  engine status during acquisition. Its interrupt-masked check/`sleep`
  sequence relies on the independent level-sensitive `Wakeup` input and closes
  the lost-wakeup race for jobs that finish at the sleep boundary.
- Both active-high RGB triplets are implemented and pin-checked. They show a
  blue heartbeat before the firmware-version AXI write, solid blue while a
  job is active, green for healthy idle, and red for an idle fault. The F1
  blue/green/red pins are `A30`/`A29`/`A28`; F2 uses
  `BL27`/`BL28`/`BL30`.
- The version `0x00010002` clean Milestone 2 implementation completed with WNS
  `+0.579 ns`, TNS `0`, WHS `+0.009 ns`, THS `0`, and 200.000-MHz `clk_200`.
- Milestone 2 route status has 84,087 fully routed nets and zero routing
  errors. Routed DRC has zero violations. CDC contains only eleven informational
  `CDC-3` entries for properly synchronized MDM/JTAG crossings; there are no
  CDC warnings or critical warnings. There are no bus-skew constraints in the
  synthetic target.
- Vivado reports all ten generated subsystem IP instances up-to-date with no
  changes required.
- Integrated synthesis uses 36,303 CLB LUTs, 52,655 CLB registers, and 16
  `RAMB36E2` blocks: eight result-bank blocks plus eight MicroBlaze local-memory
  blocks. Vectorless power estimates 3.503 W with medium confidence.
- Milestone 2 bitstream:
  `build/gt_test_milestone2/gt_test_milestone2.runs/impl_1/gt_test_milestone2_top.bit`.
- Milestone 2 bitstream SHA-256:
  `41e559b11fe2e058dc61addef32da321d24c4bb0d95d657bddaedf0d211f6f6a`.
- Supervisor ELF SHA-256:
  `23e2d3f5b286050c7170e80cae4b61ea4e472cc320105717260968e6eb9d02be`.
  The stable load-image SHA-256 is
  `c6067effe3753d9c52660c2b73e906a6e887c0baa1c46d8f5500df53b6b264d2`;
  those are the bytes initialized into processor BRAM. The firmware build uses
  explicitly named object files so random compiler temporary names cannot
  perturb the ELF symbol-table hash.
- The first board smoke test of the superseded bitstream
  `44ceb1cb5d1592305ad70f265e69a2776bc97a3ace02efee641a12ecee2c9197`
  read the hardware-owned version at `0xC4` correctly as `0x00010000`, but
  left the CPU-owned firmware version at `0xC0` as zero. Inspection of the
  implemented MMI showed a little-endian MicroBlaze while the embedded ELF was
  big-endian. The firmware now builds with `-mlittle-endian`, and the build
  rejects any ELF whose header does not match. The first little-endian
  replacement, SHA-256
  `e76121b45c71763efed0bc1265b00650a92a73cc4d21cdea81219a53eb3b9607`,
  passed a clean implementation. Its board smoke-test rerun passed on
  2026-08-25: both the CPU-owned firmware version at `0xC0` and the
  hardware-owned version at `0xC4` read `0x00010000`, and the RGB status
  settled immediately to healthy-idle green. The pre-firmware blue interval
  was shorter than was visually apparent, which is expected when firmware
  starts normally.
- The current Milestone 2 bitstream above is compressed, is 32,079,859 bytes,
  and passed the build-script check for
  `BITSTREAM.GENERAL.COMPRESS=TRUE`. Repository policy requires every new
  bitstream to be compressed; both target-specific XDC files set the property,
  and every bitstream-producing script checks it. The next clean golden IBERT
  run will also produce a compressed image.
- The RTL simulation proves completion with no AXI traffic after the doorbell,
  and basic board I2C/MicroBlaze startup now passes. The first mailbox-launched
  board job completed fully in HDL (`0xF8=0x00000001`,
  `0xFC=0x00707001`) but the CPU response remained zero at `0xF0`/`0xF4`.
  Inspection found Vivado automation had selected low-latency vectored mode
  while the freestanding firmware supplied a standard fixed `0x10` vector.
  Reading `0xC8=0x00004000` confirmed the engine interrupt remained pending
  and the ISR had not entered. A subsequent standard-mode AXI-controller board
  image still left the interrupt pending. Version `0x00010001` removed the
  controller, drove the single level interrupt directly into MicroBlaze in
  standard fixed-vector mode, and removed firmware controller initialization
  and acknowledgement. Its clean build passed timing, routing, DRC, CDC, and
  compression checks, and board reads of `0xC0=0xC4=0x00010001` proved the
  intended firmware and hardware were loaded. Nevertheless, `0xC8` remained
  `0x00004000`: MicroBlaze `sleep` waits for the separate `Wakeup` input, not
  `Interrupt` alone, and discrete ports had been disabled. Version
  `0x00010002` enables those ports and connects the engine interrupt to both
  inputs so the event wakes the pipeline before the fixed-vector ISR runs. The
  descriptor readback from that test also showed `B4=0x0000000F` and
  `BC=0x0000FFFF`, exactly explaining the atomic 84-lane summary
  (32 + 4 + 32 + 16); mask readback is now required before committing `A0`.
  The corrected version `0x00010002` board rerun passed on 2026-08-25:
  request/response sequence `0xF0=0x00000001`, CPU response
  `0xF4=0x00707001`, hardware run ID `0xF8=0x00000001`, and atomic hardware
  summary `0xFC=0x00707001`; the final state read was
  `0xC8=0x00000000`. This proves that MicroBlaze woke, serviced and cleared the
  completion interrupt, returned the engine to fault-free idle, and published
  the already-completed 112-lane result.
- The MDM halt-after-launch acceptance test passed on 2026-08-25. While
  MicroBlaze was halted during request sequence 2, the CPU-owned response
  remained `0xF0=0x00000001`, while hardware independently advanced to
  `0xF8=0x00000002`, published `0xFC=0x00707001`, and held the completion
  interrupt at `0xC8=0x00004000`. After `con`, firmware serviced that pending
  interrupt and produced `0xF0=0x00000002`, `0xF4=0x00707001`, with the
  hardware result unchanged and `0xC8=0x00000000`. This proves acquisition,
  timing, atomic publication, and result retention do not depend on CPU
  execution after launch. Milestone 2 hardware acceptance is complete; no
  physical GT is controlled by the test engine yet.

## Milestone 3 managed-quad build state

The current clean Milestone 3 implementation passed on 2026-08-27. This target
removes only FireFly 5 / physical quad 124 from the left IBERT core, leaves the
other 108 channels under the two reduced IBERT cores, and assigns managed
global lanes 12-15 to `GTYE4_CHANNEL_X0Y16`-`X0Y19`.

- The first routed attempt was rejected because WNS was `-0.195 ns` on a
  native `RXPRBSERR`-to-64-bit-counter path. The lane engine now registers the
  16-bit GT error bus before accumulator arithmetic and defers stop snapshot
  capture by one RX clock so the final pre-stop sample remains included.
- The clean rebuild passed authoritative routed timing with WNS `+0.138 ns`,
  TNS `0`, WHS `+0.008 ns`, THS `0`, WPWS `+0.248 ns`, and no failing
  endpoints.
- Route status has 864,171 fully routed nets and zero routing errors, failed
  nets, unrouted nets, partially routed nets, or node overlaps.
- All four bus-skew constraints pass; the smallest slack is `+19.515 ns`.
  Implemented primary clock periods report 200.000 MHz, 100.000 MHz,
  325.000 MHz, and the 50.000-MHz IBERT debug clock. The managed RX and TX
  user clocks report a 3.103-ns period.
- Utilization is 355,795 CLB LUTs, 606,588 CLB registers, 556 `RAMB36E2`, all
  112 `GTYE4_CHANNEL` sites, and 28 `GTYE4_COMMON` sites. The 112 channels are
  52 left-IBERT, 56 right-IBERT, and four managed quad-124 channels.
- Routed DRC contains no errors. Its five warnings are three generated
  debug-hub `PDCN-1569` findings, one generic-I2C `RPBF-3` bidirectional-port
  finding, and one generated debug/IBERT `RTSTAT-10` no-routable-load finding;
  the remaining 648 entries are generated-IBERT DSP power advisories.
- The detailed CDC report is not globally clean. It contains `CDC-3=17342`,
  `CDC-6=240`, `CDC-9=327`, `CDC-10=22`, `CDC-11=44`, `CDC-13=4`, and
  `CDC-15=17830`.
  The four 256-bit result transfers appear as XPM handshake synchronizers and
  the payload is no longer reported as a direct crossing. The critical
  findings are generated GT Wizard reset/status structures plus repeated
  two-flop start/stop and stable-descriptor controls; retain them for explicit
  review instead of describing this image as CDC-clean.
- Vectorless power is 76.864 W with medium confidence, including 70.496 W
  dynamic and 6.368 W static, at an estimated 60.1 C junction. Vivado warns
  that reset activity makes this estimate less accurate; board power and
  thermal monitoring are required during soak testing.
- The compressed bitstream is 71,214,671 bytes at
  `build/gt_test_milestone3/gt_test_milestone3.runs/impl_1/gt_test_milestone3_top.bit`.
  SHA-256 is
  `2adde4672dc227ad62c90f46b0c3b3e4013c1fb768eea7fb05f1260305582f5a`.
  Its matching 1,613-byte probes file is `gt_test_milestone3_top.ltx`.
- The embedded 1,376-byte supervisor ELF SHA-256 is
  `214010627452480da52f4352ceea545fd4678db57c343b56502b39b0149cf23f`.
  Consolidated reports are in `build/gt_test_milestone3_reports`.
- This clean image is eligible for the staged board smoke tests and soak plan;
  its shortened Milestone 3 hardware integration smoke test passed on
  2026-08-27. The managed quad returned aggregate `0x00040401`, matching
  response/run sequence 1, and final `C8=0`; lane 12 had zero errors and lock
  losses over about 25.78 billion bits. The other 108 IBERT-owned channels
  operated as before. The golden IBERT image remains the comparison and
  recovery image, and the longer soak/fault campaign remains deferred.
- After that hardware gate, the deferred comment-only SystemVerilog pass added
  architectural documentation to the handwritten AXI adapter, lane/core
  controllers, quad/PRBS controllers, managed wrapper, IBERT integration, and
  Milestone 3 top. No generated GT/IBERT structure or executable HDL statement
  was intentionally changed. Both engine simulations and both Milestone 3
  controller unit simulations passed, and `xvlog` parsed all commented modules.
- A one-hour, all-four-lane near-end PMA-loopback PRBS31 run passed on
  2026-08-27. Request/response and hardware run ID were 2, firmware/hardware
  summaries were `0x00040401`, and final `C8=0`. Every lane had zero errors,
  zero lock losses, no saturation, 92,810,902,916,320 tested bits, and
  1,160,136,286,454 valid RX cycles. The per-lane zero-error 95% BER upper
  bound is approximately `3.23e-14`; F1 AVTT current and FPGA temperatures
  remained normal.
- A subsequent five-minute PMA-loopback isolation test injected exactly one
  TX PRBS error request into global lane 12 through AXI offset `0x060` bit 12.
  Lane 12 captured exactly one error; lanes 13-15 remained at zero errors.
  Every lane had zero lock losses, no saturation, and matching bit/cycle
  counts. Request/run sequence 3 completed with aggregate `0x01030401` and
  final `C8=0`; the other 108 IBERT-owned channels operated as before. This
  proves targeted detection and full-image lane isolation.
- The following explicit-abort test also passed. Sequence 4 stopped through
  AXI doorbell bit 1 after about 62.06 seconds of a requested five-minute PMA
  run. Aggregate `0x00040402` correctly reported four selected/passed lanes and
  stop reason 2; final `C8=0`. All lanes published identical internally
  consistent partial counters with zero errors, lock losses, or saturation.
- The automatic-timeout path passed with request/run sequence 5. A five-minute
  PMA-loopback descriptor with `AC=60000 ms` stopped automatically after
  60.000 seconds and published aggregate `0x00040403`; final `C8=0`. All four
  lanes had zero errors, zero lock losses, no saturation, and exact bit/cycle
  accounting. One lane differed by one RX cycle and the corresponding 80 bits,
  an expected asynchronous stop-boundary variation.
- The Milestone 3 CPU-halted completion path passed on 2026-08-31. After an
  FPGA reload, request sequence 6 entered `ST_RUN` and MicroBlaze was halted
  in its sleep/wait loop. Hardware completed and atomically published first
  post-reload run `F8=1`, summary `FC=0x00040401`, and pending interrupt
  `C8=0x00004000` while CPU-owned `F0=F4=0` remained unchanged. All four lanes
  had identical, consistent five-minute records with 7,734,239,847,600 tested
  bits, 96,677,998,095 valid cycles, zero errors or lock losses, and no
  saturation. After `con`, firmware published `F0=6`, `F4=0x00040401`, and
  cleared `C8` without changing the hardware run ID or summary.

## Milestone 3 external-path reset candidate

Full-M3 candidate `0x00020005` was started on 2026-08-31 after two external
path jobs on `0x00020004` failed before reaching `ST_RUN` following FPGA
configuration. The 12-hour attempt published sequence 7, hardware run ID 2,
summary `0x04000404`, `C8=0x00010000`, and XSDB platform status
`0xE1208085`; a 60-second reproduction failed the same way.

- The PRBS controller now always performs a bounded RX datapath reset after
  changing PRBS controls. External mode keeps `LOOPBACK=000` and proceeds
  from RX-reset qualification directly to counter reset and lock wait. PMA
  mode retains its additional loopback-settle and `RXPMARESET` sequence.
- `ST_FAULT` explicitly holds the first captured diagnostic stage instead of
  replacing it with the generic fault-state encoding on later cycles.
- Hardware and MicroBlaze firmware versions are both bumped to `0x00020005`.
  The little-endian firmware build and fixed interrupt-vector checks pass.
- Quad-controller and PRBS-controller unit simulations pass, including the
  external reset sequence, PMA reset ordering, lock/DRP capture, cleanup, RX
  requalification, and fault-stage retention.
- The clean full-M3 Vivado 2023.2 implementation completed routing and wrote a
  compressed bitstream, but failed setup timing: WNS `-0.687 ns`, TNS
  `-942.105 ns`, and 3,745 failing `clk_200` endpoints. Hold and pulse-width
  timing passed, routing had zero errors, all four bus-skew constraints passed,
  and routed DRC had zero errors. The bitstream must not be programmed.
- The failures were dominated by routing on the power-on-reset network feeding
  counters in the 108 complete synthetic lane engines for IBERT-owned lanes.
  Vivado reported level-6 routing congestion with hotspots above 92%. Those
  lanes are compile-time unselectable in Milestone 3, but their unreachable
  counters and reset loads were still implemented.
- Candidate `0x00020006` retains the external RX-reset fix and conditionally
  elaborates a full lane engine only for each set bit in `MANAGED_LANE_MASK`.
  Unmanaged lanes retain the 112-lane ABI through constant unselected records
  and start/stop protocol stubs. Expanding the mask in later milestones
  automatically elaborates more full engines; an all-ones mask still builds
  all 112 engines.
- Both the existing all-112-managed simulation and the four-managed-lane
  simulation pass. The latter explicitly checks unmanaged request rejection,
  stub acknowledgement, and a published lane-ID record with zero status and
  counters. The matching little-endian `0x00020006` firmware also passes its
  fixed-vector build checks.
- The clean `0x00020006` full-M3 Vivado 2023.2.2 build passed on 2026-09-01.
  The first attempt stopped in the right IBERT out-of-context synthesis run
  because Vivado itself terminated with signal 11 (`TclStackFree: incorrect
  freePtr`); an unchanged clean retry passed that phase and the complete flow.
- Authoritative routed timing passes with WNS `+0.145 ns`, TNS `0`, WHS
  `+0.009 ns`, THS `0`, and pulse-width slack `+0.250 ns`, with no failing
  endpoints. Routing has 784,829 of 784,829 routable nets fully routed and
  zero routing errors. All four bus-skew constraints pass, with worst reported
  slack `+19.499 ns` against a 20-ns requirement.
- Routed DRC has zero errors and four generated debug-hub/IBERT warnings;
  all 13 IP are up-to-date. The implemented clock table contains `clk_100_raw`
  at 100.000 MHz and `clk_325_raw` at 325.000 MHz. Bitstream compression was
  verified enabled, and the 70,196,679-byte compressed bitstream is at
  `build/gt_test_milestone3/gt_test_milestone3.runs/impl_1/gt_test_milestone3_top.bit`.
  Its SHA-256 is
  `6a2a5e6985fb643bdc8860ca9846565cf13b27947c94ee1cd77993569ee1dca0`.
  Implementation took 1:41:11; the full outer build, including synthesis and
  report generation, ran from about 07:16 to 09:40 EDT. This candidate is
  implementation-qualified but still requires the 60-second external-path
  hardware smoke test before a 12-hour soak.
- `scripts/milestone3_60second_external_smoke.py` is the mandatory hardware
  gate before retrying `scripts/milestone3_12hour_external_soak.py`.
  `scripts/read_fpga_frequencies.py` provides Python 3.6-compatible readout of
  the deployed 37-clock direct-kHz ABI through `cm_interface`.

## Isolated Milestone 2.5 smoke build

The corrected, uniquely versioned isolated build completed on 2026-08-26.
This is now the next hardware smoke candidate, ahead of another full
Milestone 3 implementation.

- `gt_test_milestone25_top` instantiates only the managed quad-124 GT Wizard;
  there are no IBERT cores and no other GT transmitter outputs. Implemented
  utilization confirms four `GTYE4_CHANNEL` cells at `X0Y16`-`X0Y19`, one
  `GTYE4_COMMON` at `X0Y4`, and only six ordinary output buffers for the LEDs.
- Hardware and firmware versions are `0x00020004`. The controller implements
  the high-rate near-end PMA loopback reset sequence, waits for PRBS lock, and
  reads exact 32-bit native `RX_PRBS_ERR_CNT` values through DRP `0x25E` and
  `0x25F`. Unit simulation covers reset ordering, external-loopback bypass,
  lock acquisition, DRP word assembly, and cleanup.
- The isolated target keeps all deployed clock-monitor and I2C/SysMon ABI
  ports. Its target XDC explicitly declares all twelve 322.265625-MHz REFCLK0
  inputs because the full IBERT timing XDCs are intentionally absent.
- The authoritative routed timing report has WNS `+0.434 ns`, TNS `0`, WHS
  `+0.010 ns`, THS `0`, WPWS `+0.454 ns`, and no failing endpoints. It reports
  200.000, 100.000, and 325.000 MHz plus the managed RX/TX and REFCLK clocks at
  322.269 MHz after Vivado's 1-ps period rounding.
- Route status contains 103,160 fully routed nets and zero routing errors.
  There are no bus-skew constraints in this isolated target. Routed DRC has no
  errors and one existing `RPBF-3` warning on incomplete bidirectional
  buffering for `i2c_scl_f_generic`.
- Methodology and CDC are not globally clean. The methodology report retains
  one related-RX/TX-clock `TIMING-7` finding and 1,000 `TIMING-17` findings on
  monitor counters driven by clock-monitor inputs that have no timing clock.
  CDC critical entries are predominantly generated GT Wizard reset/status
  structures; the explicit application synchronizers and four XPM result
  handshakes remain visible. These findings were reviewed, not silently called
  clean.
- Vectorless power is 6.868 W at medium confidence (3.790 W dynamic, 3.079 W
  static, estimated 28.1 C). Actual board supply and temperature readings are
  required because vectorless reset activity is not representative.
- Synthesis took 3:04 elapsed; placement 4:29; routing 2:26; bit generation
  1:36. The complete implementation run took 11:11 elapsed and the full clean
  script took 18:12. Synthesis had no errors or critical warnings; placement
  and routing each completed with no errors or critical warnings.
- The compressed bitstream is 33,383,572 bytes at
  `build/gt_test_milestone25/gt_test_milestone25.runs/impl_1/gt_test_milestone25_top.bit`.
  SHA-256 is
  `49c8a71111d00bb30bd65892e09dc26995d79d7186702b724d7eeab3896e7d8a`.
  The embedded 1,376-byte ELF SHA-256 is
  `214010627452480da52f4352ceea545fd4678db57c343b56502b39b0149cf23f`.
- The first board attempt used the superseded `0x00020001` candidate. Its
  completion words were `F0=1`, `F4=0x04000404`, `F8=1`, and
  `FC=0x04000404`; `C8=0x00010000` reported a latched platform fault. Lane 12
  returned the engine's deterministic platform-failure record
  (`D0=0x0000280c`, all measurement fields zero, `E4=1`). That `E4` value is
  synthetic and is not evidence of observed PRBS lock loss.
- Candidate `0x00020002` extended the PRBS reset qualifier through loopback
  application, PMA reset, counter reset, and lock wait, but failed identically.
  XSDB read AXI platform status `0x44A00070` as `0x00000085`, proving the quad
  supervisor entered state 5 / FAULT. The remaining cause was a synchronizer
  race: PRBS lock could arrive before RX user-clock-active/reset-done reached
  the supervisor. Version `0x00020003` adds bounded intentional RX
  requalification while preserving `quad_ready`, and exposes an eight-bit
  latched fault reason at AXI `0x070[15:8]`. Unit simulation covers delayed RX
  readiness, successful requalification, unexpected RX loss, and QPLL loss.
  Neither superseded bitstream may be programmed again: `0x00020001` hash
  `85cefe9aad58bf3040444ebabc91ce36e0073dcf7b2a634bbbcdb33de772553e`;
  `0x00020002` hash
  `ff79a4e01be52dafb77eb93966433ac56c788ac4a8a8349c58e1084e64bffca0`.
- Hardware smoke acceptance passed on F1 for both a four-lane external
  optical-loopback PRBS31 run and a near-end PMA-loopback PRBS31 run. Both
  returned aggregate `0x00040401`, zero errors and lock losses in all four
  lane records, and healthy final `C8=0`. The earlier external-path failure
  was resolved by correcting the optical setup (about 3 dB of path loss), not
  by an HDL change. The planned comment-only SystemVerilog pass remains
  deferred until the full Milestone 3 smoke gate passes.
- A new same-setup golden-IBERT control was captured on 2026-09-02 in local
  `docs/evidence/legacy/Table.xlsx`. Quad 124 `MGT_X0Y16`-`X0Y19` used PRBS31 with no internal
  loopback; all four PLL pairs were locked and each lane accumulated about
  `1.072e12` bits with zero errors. The spreadsheet's displayed BER is `1/N`,
  not a measured nonzero BER; the zero-error 95% upper bound is approximately
  `3/N`, or `2.8e-12` per lane.
- Immediately afterward, a fresh preserved v2.5 `0x00020004` first-run
  external smoke entered RUN and completed normally but returned summary
  `0x04000401`: all four selected lanes saturated their native error counters
  within one second, with no reported lock losses. This disproves the working
  hypothesis that the failure was introduced only between v2.5 and v10 and,
  together with the golden control, focuses the investigation on managed
  external-path PRBS acquisition/control rather than the physical optical
  path. Do not build a post-lock-reset-only successor until that difference is
  resolved.
- The fresh v2.5 six-job restart/recovery matrix then failed every job. Lane
  12's first ten-second external run counted 1,425 error indications; its
  repeat and the subsequent lane-13 run saturated. A four-lane near-end PMA
  run produced exactly one error indication per valid cycle on lanes 12 and
  14 while lanes 13 and 15 were clean. Both post-PMA lane-12 external runs
  saturated. All jobs entered RUN, ended normally, and reported no lock-loss
  transition. A PMA/RX datapath reset is therefore not sufficient to recover
  the managed checker.
- RTL inspection identified an untested ordering difference consistent with
  these observations: `gt_lane_engine` asserts TXPRBSSEL and RXPRBSSEL
  together in RXUSRCLK2, but the wrapper sends TXPRBSSEL through two
  TXUSRCLK2 synchronizer stages while RXPRBSSEL is applied directly. The RX
  checker consequently starts before the requested TX pattern is established.
  The next candidate should stage TX enable before RX-checker enable, then
  require a bounded locked/error-free qualification interval and reset the
  counter before measurement. This is the leading hypothesis, not yet a
  hardware-proven root cause.

## External MCU support state

- The repository-local external-MCU protocol header, `cm_mcu` adapter draft,
  dedicated C tests, and MCU test stubs were retired on 2026-09-23. The draft
  was never integrated into `apollo-lhc/cm_mcu`, was never exercised on the
  board, and hard-coded the obsolete Milestone-3 lanes 12--15 rather than the
  current all-links interface.
- Current host-side board access uses the pinned authoritative `cm_interface`
  checkout. The stable `0x2B` mailbox ABI and the I2C5 semaphore/mux ownership
  requirements remain documented in the README and `docs/gt-test-engine.md`.
- The FireFly sticky-alarm requirement remains relevant but belongs in the
  external MCU project; its FPGA-side motivation is retained in the FireFly
  alarm documentation rather than as a local MCU implementation.

## Root cause and resolution

The original timing failure was not caused by ordinary 200-MHz monitor/I2C logic. The generated IBERT debug/DRP network had been attached to the board's 200-MHz fabric clock even though vendor constraints expected 50 MHz. Its worst path crossed SLRs from the debug hub to IBERT XSDB logic with roughly 2,045 fanout and about 5.8 ns of routing against a 5-ns period.

The fix was to retain 200 MHz for application logic and create a physical 50-MHz `BUFGCE_DIV` clock for `dbg_hub` and IBERT XSDB/DRP. Correct application of all 28 vendor quad pblocks was also required.

## Remaining review items before hardware use

- Routed DRC has no errors. It reports three generated debug-hub PDCN-1569
  violations, one RPBF-3 violation on bidirectional `i2c_scl_f_generic`, one
  RTSTAT-10 violation for generated debug/IBERT nets with no routable loads,
  and 672 generated-IP power advisories.
- Methodology reports contain many generated-IBERT warnings, notably TIMING-7 for related dynamically generated clocks, TIMING-17 for non-clocked sequential cells, and TIMING-54 scoped false paths. Timing passes, but these warnings should be dispositioned before programming hardware.
- GT routing reports north/south reference-clock pin swaps onto physically equivalent resources. Keep this in the hardware-review checklist.

## Working tree

The source changes associated with this build were not committed when this
file was last updated. Do not discard unrelated work or commit generated
products. The modifications cover pin/lane corrections, local IP generation,
synthesized-design validation, hierarchical floorplan hooks, the 50-MHz debug
clock, the 100/325-MHz MMCM, the generic-I2C register remap and direct-kHz
scaling, SysMon addressing, build timing checks, and documentation.
