# VU13P 25.78125-Gb/s IBERT

Reproducible Vivado 2023.2 project for exercising the FireFly and direct
FPGA-to-FPGA GTY links on the Apollo Cornell rev3 dual-VU13P board. The same
bitstream is intended for either FPGA site because the relevant pinout and
clocking are identical at this level.

## Current status — 2026-11-13

The [separate eye-scan image](docs/eye-scan-plan.md) is implemented.
The [integrated eye-scan v1 target](docs/eye-scan-v1-runtime.md) now passes
focused integration tests, fresh synthesis/preflight and normal routed
setup/hold signoff at +0.001/+0.009 ns. The first failed route is preserved.
Independent routed audit passes and verified compressed BIT/BIN artifacts are
frozen. Operator tools include JSON/CSV/PNG/PDF output and remain unreleased
pending a separate reviewed hardware gate. No eye-scan image is running on hardware.

See the [eye-scan how-to](docs/eye-scan-howto.md) for offline plotting,
runtime preparation, acquisition commands after release, and result cleanup.

Runtime per-quad TX/RX control is implemented and statically qualified in a
separate, unreleased all-links v3 target (`0x00020502`) from baseline `34c73bb`. The working v2
image and deployment pins remain intact. See the
[v3 design, ABI and validation record](docs/all-links-v3-runtime-control.md).

For operator steps, quad selection, deployment, logging, and recorded results,
see [HOWTO.md](HOWTO.md). The guide starts with the three-minute inter-FPGA
command sequence. The [project talk](docs/presentations/vu13p_25g_project_talk.pptx)
also opens with practical commands and results before the design discussion;
a [PDF copy](docs/presentations/vu13p_25g_project_talk.pdf) is available.
The [FPGA firmware block diagram](docs/fpga-firmware.md) shows the hardware
I2C path, MicroBlaze subsystem, measurement engine and GTY lanes.

The timed scripts now discover sequence/run state while holding the MCU lock;
operators can run tests without copying those counters into the command.
Optional explicit guards remain available for automation. Source changes must
be redeployed before using the simplified CLI on an existing blade bundle.

On 2026-10-27, F1 on Apollo 3010 was programmed with the exact audited
all-links v2 bitstream listed below. The fixed programmer verified the BIT and
ELF hashes, saw exactly two `xcvu13p` targets on `apollo3010-1:2542`, and
reported `PROGRAM_F1_COMPLETE`; evidence is
`build/diagnostic_archive/firefly1-all-links-v2-F1-program-1793110477206097.log`.
F2 was subsequently programmed with the same pinned image, with
`PROGRAM_F2_COMPLETE` and its MicroBlaze running. XSDB then aborted during
shutdown with `Tcl_FindHashEntry on deleted table` (exit 134); programming was
not repeated. Evidence is
`build/diagnostic_archive/firefly1-all-links-v2-F2-program-1793111080326955.log`.
Independent read-only checks with clean `cm_interface` v1.0.3 passed on both
sites: firmware/hardware `0x00020501`, healthy IDLE/session-off at sequence/ack
0, run 0, valid clock status `0x434DA501`, and required 200/100/325-MHz fabric
and twelve managed-GTY reference clocks in range. MCU raw FPGA DONE `0x00`
confirms both configured because the pins are active low. Full power,
FPGA-diode, LGA80D, and FireFly temperature reads completed (190.254 W;
F1/F2 diode 50.563/46.094 C). Readback evidence is
`build/diagnostic_archive/all-links-v2-readonly-v103-after-F2-1793111080326955.log`.
One subsequently authorized 180-second bidirectional inter-FPGA PRBS31 test
with `cm_interface` v1.0.3 passed all 54 fitted receivers per endpoint with zero
errors and zero native lock losses, about 4.64055e12 tested bits per lane.
The user explicitly acknowledged that equipment connected to the outward
FireFly TXs can safely receive PRBS31. Both endpoints stopped cleanly and final readback confirms
healthy IDLE/session-off at sequence/ack 3, run 1, summary `0x00363601`, with
required clocks valid. These sequences and run are consumed. The old run-5
state below is historical. The immutable report is
`build/diagnostic_archive/all-links-v2-timed-inter-fpga-180s-1793111744850372.report.md`.
The released launchers still pin v1.0.0; this expressly authorized v1.0.3 run
used a separately archived wrapper with exact library commit/tag and runtime
hash verification. See `docs/all-links-v2-inter-fpga-hardware-gate.md`.

**All-links v2 (`0x00020501`) now has a timing-clean, independently audited,
compressed build candidate.** V1's reducers required acquisition/capture from
all 28 controllers, so a direct-only globals56--111 request could not leave
`ST_ARM_WAIT` while
the fourteen unselected FireFly controllers remained IDLE.  V2 derives a
28-bit quad-participation mask from the engine's accepted lane mask, registers
its 6/8/8/6 slices with the bank controls, and neutralizes unselected quads
only for acquisition-ready and capture-done.  All global fault, idle, ready,
reset and TX-session barriers remain intact.  Integrated direct-only, sparse,
all112, early-RUN, barrier and changed-epoch tests plus the full historical
serial regression pass.  Fresh synthesis/preflight pass exact 112/28/12 GT,
CDC, session, descriptor and participation inventories.  The sole normal
route is physically clean (212,076/212,076 routed nets, zero routing/Error-DRC
failures, 28/28 skew, hold +0.010 ns) but setup fails at WNS/TNS
-0.158/-26.399 ns over 580 endpoints across `clk_200` and 17 RX clock groups.
That broad failure did not qualify for the optional post-route closeout; no
audit or bit was produced.  Synth/routed-DCP/ELF SHA-256 values are
`e1a8a3a20d177e6828b4378230dfb74d55bc624481f54fce86dcee8c2cd00a71` /
`ec0de1a6268e76c3666f3d2984333e89e6c1b3ca05b2b3c1809f0faf4aa50f9c` /
`d947fd47e684a1e0be08296d34b4de1b1e28d7c056ecabffcbfb681786730f9c`.
Evidence is frozen under
`build/diagnostic_archive/all-links-v2-0x00020501-normal-route-timing-failure/`.
That failed-route artifact was never released or programmed.

The v2 image manages all 112 25.78125-Gb/s lanes: globals 0--55 are the 56
FireFly lanes in q121--q134, and globals 56--111 are the 56 direct
FPGA-to-FPGA lanes in q221--q234. It contains no IBERT and excludes the
10-Gb/s AXI C2C lanes. The detailed connector mapping is recorded in the
[source milestone](docs/all-links-v1-source-milestone.md#v1-historical-record).
One later hash-pinned incremental attempt reused the exact audited v1 routed
DCP at 98.94% of cells and 97.08% of nets.  Its sole default physical
optimization reached estimated WNS +0.001 ns, but the sole route still failed
signoff setup at -0.119/-5.883 ns over 93 `clk_200` endpoints.  Hold passed at
+0.005 ns; 212,112/212,112 nets routed with zero errors, zero Error DRCs, and
28/28 skew groups met.  Routed DCP SHA-256 is
`6fd5e2b102f7b2fc79e4868adc66b7fca4cb737c7aa4989ff21ef74c6dc91824`;
evidence is under
`build/diagnostic_archive/all-links-v2-v1-incremental-timing-close-attempt-retry2/`.
It stopped without another physopt, retry, audit, bitstream, or hardware action.

The successful source-level closeout replaces the central 112-to-1 result
copy mux with four registered banks, splits each 256-bit snapshot transfer
into four 64-bit handshakes, and gives every quad a cycle-matched local reset
release. Only the existing eight control/reset boundary registers per SLR are
hard-contained; result-copy bank placement remains soft and is reported, not
treated as a functional invariant. Focused v2 and historical regressions pass,
and fresh synthesis/preflight preserves exact 112-channel/28-common/12-REFCLK
topology, ABI, FSM encodings, sessions, barriers and 25.78125-Gb/s behavior.

The focused implementation passes setup/hold at WNS/WHS +0.046/+0.009 ns
with zero failing endpoints. All 220,150 routable nets are fully routed, zero
routing errors and zero Error DRCs remain, and all 476 bus-skew groups pass.
The fresh-process audit passes the full topology and GT-property checks plus
strict physical 6/8/8/6 participation and per-quad-reset residency. The
compressed BIT/DCP/synthesis-DCP/ELF SHA-256 values are
`163172d938f5aa87fd606061e75e058f5d7040916d86d4744a206309f970b66f` /
`323ff58252ae66a81e42c84d38b528ce053561804cdc7eeecb99d3066107993a` /
`a914ff24b3a9e9a106ff92a6276ce2c0842df701112c420e65e4c61e1847b8f9` /
`d947fd47e684a1e0be08296d34b4de1b1e28d7c056ecabffcbfb681786730f9c`.
Exact artifacts and evidence are frozen under
`build/diagnostic_archive/all-links-v2-timing-hardened-control-boundary-clean/`.
The successful architecture and the rejected timing/locality strategies are
summarized in the
[all-links v2 timing-closure decision record](docs/all-links-v2-timing-strategy.md).
The hash-pinned image is released only through the fixed F1/F2 programming
choices and the guarded timed-test launchers. Hardware results are recorded
below as they are obtained.

The present TX-session interface has one board-wide enable, not a lane or
link-class mask. Starting any external test therefore selects PRBS31 on all
112 managed transmitters: all 56 FireFly TX lanes and all 56 direct
FPGA-to-FPGA TX lanes. The receive descriptor still limits which lanes are
measured. Thus an inter-FPGA-only receive test also emits PRBS31 on every
FireFly transmitter for the bounded session lease. A future ABI should add a
two-bit TX-class selector (`FireFly`, `inter-FPGA`), allowing FireFly-only,
inter-FPGA-only, or both; it must retain all-quad application acknowledgement
for whichever class or classes are selected.

Prepared timed inter-FPGA and selectable FireFly-quad
external-loopback launchers (90-second default) are documented in
[`docs/all-links-v2-timed-tests.md`](docs/all-links-v2-timed-tests.md). They gate
on FPGA clock counters before starting and log 12-V power, both FPGA diode
temperatures, every LGA80D temperature, and every physical FireFly module
temperature before, during, and after the run. Each completed test also creates
an immutable Markdown report beside its authoritative raw log, including
frozen hashes, clock and lane summaries, telemetry extrema, and failure
details when applicable. The user-facing launchers are
`board_all_links_v2_inter_fpga.py` and
`board_all_links_v2_firefly_loopback.py`; 90 seconds is only their default.
They deploy the required remote-side bundle under `/home/cms/25G` and require
its clean `cm_interface` checkout to be exactly tag `v1.0.0`.

The first 180-second all-links-v2 direct-link gate failed on one F2 receiver:
F1 passed all 54 fitted lanes, while F2 global lane 98 (q231) saturated its
error counter at `0xffffffff` with zero native lock losses. That run stopped
cleanly and remains preserved as a consumed failure. After a separately
authorized board power cycle, both sites were reprogrammed with the same exact
audited bitstream and a fresh, otherwise identical 180-second gate passed all
54 fitted receivers in both directions with zero errors and zero native lock
losses. Lane 98 passed with about 4.64e12 tested bits. Final F1/F2 are healthy
IDLE/session-off at sequence/ack 3, run 1, with no retained platform fault.
The successful retest's sequences 1--3 and run 1 are consumed. This supports a
transient board/startup-state explanation for the first result, but one failure
and one pass do not establish its root cause. See the
[hardware-gate record](docs/all-links-v2-inter-fpga-hardware-gate.md).

The first q121--q123 FireFly external-loopback run failed with errors on F1
lanes 1/3/4/6 and F2 lane 4. One explicitly authorized 90-second repeat
reproduced the same four F1 failing lanes with 104/400/306/15 errors,
respectively, while F2 passed all twelve lanes. Every lane remained selected
and locked with zero native lock losses and about 2.320e12 tested bits. Both
sites stopped cleanly and are now healthy IDLE/session-off at sequence/ack 12,
run 4. The repeat is consumed; this reproducible F1 pattern is a link-quality
failure, not a launcher failure.
Bench wiring is confirmed as independent same-endpoint self-loopback on both
F1 and F2 for q121--q124, so both sites' measurements above are valid optical
loopback results rather than inter-FPGA directions.
One subsequent authorized 90-second q121--q124 run confirmed q124 clean on all
four lanes at both endpoints. F2 passed all 16 lanes; F1 again failed only
lanes 1/3/4/6 in q121/q122, with 56/172/84/10 errors. Q123 and q124 were clean,
all lanes remained locked, and native lock losses were zero. Both endpoints
stopped cleanly and are healthy IDLE/session-off at sequence/ack15, run5. This
run is consumed.

**Historical all-links v1 has an audited, timing-clean but functionally
superseded build candidate.** Symmetric identity
`0x00020500` manages all 112 25G lanes: 56 FireFly lanes in q121--q134 and 56
direct lanes in q221--q234. Focused static, aggregate, full-mask/subset engine,
IP/topology generation, firmware, Vivado RTL-elaboration, deterministic
same-instance changed-mask re-arm, and clean synthesis/preflight gates pass.
Two clean routes completed with zero failed nets and zero DRC errors but failed
signoff setup timing: the baseline at WNS -1.277 ns and a reviewed whole-wrapper
hard-pblock experiment at WNS -1.412 ns. A third enumerated-leaf constraint
attempt passed exact preflight but stopped after placement: canonicalization
left 506 real optimized leaves in 13 roots outside their expected SLR (placed
DCP SHA `22104945...b140`; archived under
`build/diagnostic_archive/all-links-v1-enumerated-leaf-locality-attempt/`).
A fourth synthesis-preserved controller-root attempt passed exact synthesis and
post-opt gates and improved placed WNS to -1.089 ns, but its mandatory gate
found 257 escaped leaves in five mixed roots plus ten excluded session-support
primitives. It stopped before phys-opt/route; placed DCP SHA is
`9b3844ae...0e9e`, with evidence under
`build/diagnostic_archive/all-links-v1-keep-hierarchy-locality-attempt/`.
The revised all-links source has four explicit 6/8/8/6 SLR banks with one
local reset-release register each. Focused/historical regressions and fresh
synthesis/preflight pass. The original placement evidence and SHA
`2ce01589...1f439` remain frozen unchanged. A corrected gate proves that
post-opt control bit 1 is legitimately absent because all wrapper runtime
detectors are constant-disabled, while all 112 lane engines retain global
measurement control; all 47 cross-SLR leaves are publication-only with no
controller feedback. That route missed `clk_200` setup by 0.034 ns. A reviewed
hash-pinned continuation then ran exactly one plain `phys_opt_design`, with no
reroute or retry. Signoff now passes at setup/hold WNS +0.001/+0.010 ns with
zero failing endpoints; all clock groups, 28 bus-skew groups, routing, and
Error DRCs pass. An independent routed audit passes the full topology, GT
properties, CDC/descriptor/bank/reset inventories, 28 dedicated REFCLK routes,
and 224 QPLL sinks. Compressed BIT/DCP/ELF SHA-256 values are
`5cb71e186edf73ce42adc33eeaa9e1d9ef090468d2f4e297fc83cecc6c2e729d` /
`a6862fdd15945b9532257d55dbfcb5e48dbde8c4ff9fb11637e7ed28d085d4c3` /
`96d3ab54308b894d34f2add001c16d1aa52029bc1474aba506c3017ca6a978ae`.
Evidence is under
`build/diagnostic_archive/all-links-v1-postroute-default-physopt-attempt/`.
This is a build candidate only: no deployment entry or hardware qualification
exists. Any external session may
drive outward FireFly TXs, so external hardware testing is blocked pending
explicit policy approval. See the [source milestone and next gate](docs/all-links-v1-source-milestone.md).
The current revised-source synthesis DCP SHA-256 is
`409a7a24819c0da515d5443688df038649584c0b4e5820e583e909890b812ace`.

**All-direct v12 passed its scoped hardware gate on both FPGAs.** The symmetric
`0x00020409` image manages all 56 q221--q234 direct-link lanes while excluding
AXI C2C. Simulation, compressed implementation, and independent audit pass at
signoff WNS/WHS +0.019/+0.006 ns with zero routing/DRC errors, all fourteen
bus-skew checks, all 56 golden-matched channels, 14 dedicated REFCLK routes,
and 112 exact QPLL0 connections. Bit/DCP/ELF SHA-256 values are
`5bce735128e22f3be029972e0290bf8a552dc196e08258a071b7ef31b30c5697` /
`68d0e0535f4eb8f4b17169545a0f171415222da342a2bd1170a8942523454260` /
`a2370f4b0b6132bffef5323aca834b5a4c174dfedeb4b0c113df6a0bc6a3c163`.
Those exact artifacts and the cited evidence are frozen under
`build/diagnostic_archive/direct-all-v12-0x00020409-scoped-pass/`; the
retained v12 deployment pins use only that archive.

F1 and F2 each passed an all-56-lane 10-second PMA PRBS31 gate. The overlapping
bidirectional external gate then passed all 54 fitted receive lanes per site at
about 257.808 billion bits/lane, with zero errors and zero native lock losses.
Both bounded sessions stopped cleanly; both sites are healthy IDLE at
sequence/ack 4, run 2, with no retained fault. All fixed stages are consumed.
This is fitted-link functional coverage, not long-BER qualification. See the
[v12 build and hardware record](docs/direct-all-v12-hardware-gate.md) and
[topology manifest](docs/direct-all-v7-topology.md).

The following direct-link and FireFly results are historical milestones, not
the current hardware state.

**V6 one-direct-quad bidirectional gate passed.** F1 N/q222 and F2 I/q233
used separate audited images; schematic mapping reverses physical lane
0↔3 and 1↔2 without P/N inversion. Both near-end PMA gates and two separate
overlapping ten-second bidirectional PRBS31 windows passed all four lanes each
way with zero errors and native lock losses. Both endpoints are healthy IDLE
at sequence 5/run 3 with TX sessions off and required clocks valid. This is
one-quad category coverage, not an all-channel qualification or long BER soak.
See [the complete build, repair, and hardware record](docs/v6-direct-quad-qualification.md).

**Scoped v5 closeout passed:** one fresh10s all12 recovery smoke returned
zeroerrors/native losses. Both FPGAs healthy IDLE, sessions stopped;
F1seq17/run0,F2seq25/run8. No external reset/reload. This establishes clean
reuse after acquisition, not automatic in-run recovery. Channels were already
qualified; no requalification or MCU implementation is in scope. No further
test pending. [Closeout](docs/firefly1-v5-closeout.md).

Latest alarm observation completed: clean all12 recovery baseline passed,
then TX02 interruption repeatedly asserted **F2 RX02 module CDR LOL** while
FPGA native loss counters remained zero. X0Y13 alone recorded saturated errors;
11 neighbors clean. Controls restored, both sessions stopped, final
F1seq15/run0 F2seq22/run7 healthy IDLE. LOS zero samples are inconclusive
under competing polling. [Details](docs/firefly1-v5-alarm.md).

Single TX02 interruption completed with **inconclusive RSSI mapping gate**:
only X0Y13 recorded errors (saturated), all11 neighbors clean; no native lock
losses. TX control restored, sessions stopped, F1seq13/run0 F2seq18/run5.
No recovery baseline or retry. See [interruption evidence](docs/firefly1-v5-loss.md).

**One-hour all-twelve-lane F1→F2 PRBS31 soak passed**, zero errors/native
lock losses, approximately92.81 trillion bits/lane. Both sessions stopped;
F1seq11/run0, F2seq15/run4 healthy IDLE. Next reviewed gate is one controlled
TX02 interruption, not an automatic sweep or reload.
See [soak status and launch details](docs/firefly1-v5-soak1h.md).

**All twelve lanes passed two separate ten-second F1→F2 PRBS31 tests**, each
with zero errors and native lock losses—including X0Y13. Existing audited v5
and TX settings were unchanged. Both PRBS sessions stopped; F1 healthy IDLE
at sequence9/run0, F2 at sequence12/run3. No long soak started yet.
See [all-twelve-lane results](docs/firefly1-v5-all12.md).

Historical reduced-mask baseline:

**Eleven-lane F1→F2 PRBS31 diagnostic passed:** ten seconds, zero errors and
native lock losses, using the existing audited v5 on both ends. RSSI rose on
all twelve channels by the five-second sample; the earlier one-second gate
was premature. X0Y13 remained excluded from BER. Both PRBS sessions stopped;
F1 healthy IDLE at sequence5/run0, F2 at sequence6/run1. No new build needed.
See [results and evidence](docs/firefly1-v5-managed-oneway.md).

Historical preceding pre-gate:

Latest two-v5 diagnostic stopped at its RSSI pre-gate: five optical channels
did not rise in the one-second sample. No receive measurement was submitted.
Both TX sessions stopped cleanly; both devices are healthy IDLE at sequence3,
run0. See [results and limitations](docs/firefly1-v5-managed-oneway.md).

User deferred the golden-capture tooling and requested managed v5 on both
ends. Both FPGAs are now restored to the exact audited v5, FW/HW `0x00020304`,
fresh healthy IDLE at sequence/run0, TX sessions off; required clocks valid.
No new test request. Direct F2 RSSI is low with F1 TX off; next optical check
is comparison during a new bounded TX session, not replay of consumed gates.

Historical golden comparison (before this restoration):

User has since loaded golden IBERT on both FPGAs. Confirmed test wiring is
**F1_1 TX → F2_1 RX only**. All twelve F1 lanes pass PMA PRBS31; eleven F2
external receivers work with TX swing 630 mV (`01001`), zero pre/postcursor.
F2 X0Y13 fails externally but passes local PMA; corresponding optical Rx02
reports 61.2 µW. Channel-disable mapping is complete: GT Y = 15 − optical
channel. All disable masks were restored, and user confirms working links
recovered with no new errors after clearing IBERT counters. This is not a
timed twelve-lane qualification. See [mapping and golden results](docs/firefly1-rx-channel-mapping.md)
and [cm_interface datasheet audit](docs/cm-interface-datasheet-audit.md).

The existing-v5 eleven-lane subset simulation passes with lane9 unlocked;
the new [F2-only diagnostic launcher](docs/firefly1-v5-oneway-plan.md) passes
20 offline tests. Hardware execution remains review-held pending live golden
settings and a timed reference. Capture uses `board_golden_xvc.py capture`
and XVC `apollo3010-1:2542` from lnx4189, with its own temporary bridge;
it must not depend on the user's GUI server. That capture prerequisite was
subsequently deferred by the user in favor of restoring v5 on both ends.
No new bitstream is yet justified by the subset test.

Historical v5 gate (live state superseded by manual golden programming):

FireFly-1 v5 (`0x00020304`) simulation, checkpoint-assisted compressed build,
independent audit, and twelve-lane PMA gates on both FPGAs pass. The first
dual external gate failed: F2 timed out acquiring PRBS lock, while F1 measured
errors on four lanes. Both TX sessions were stopped; failure evidence is archived with
no second baseline/retry. V5 is not qualified. See
[v5 results and investigation](docs/firefly1-v5-tx-session.md).

Historical v4 results (superseded by v5 on hardware):

The same final v4 image now passes the twelve-lane PMA gate on F2 as well:
both sites are healthy IDLE/run 1 with zero measured errors or native lock
losses and valid matching clock monitors. F1's passed run is unchanged.
Optical qualification remains pending: dual-engine simulation reproduces
a peer-transmitter shutdown race with staggered acquisition. See
[F2 bring-up and timing investigation](docs/firefly1-v4-f2-bringup.md).

FireFly-1 development update (2026-09-16): the separate v4 (`0x00020303`)
candidate fixes omitted staged-acquisition parameter forwarding in the native
q121--q123 wrappers and adds first-fault diagnostics. It preserves physical
lane wiring and uses compressed bitstreams. The final clean-synthesized repair
passes simulation, routed audit (+0.206/+0.010 ns), and the twelve-lane
ten-second PMA hardware gate: zero errors/losses, `0x000c0c01`, healthy IDLE
at sequence/run 1 with no retained fault. Fixes cover missing clock constraints,
loopback-control continuity and cleanup reset acknowledgement. Automatic
incremental synthesis was disabled after failing the new structural checks.
This is an isolated PMA gate, not external/full qualification. V3's zeroed
diagnostic page did not prove a reset-done or polarity fault. See the
[v4 repair record](docs/firefly1-v4-repair.md) and
[build state](docs/memory/build-state.md) for exact artifact/evidence status.

Full Milestone 3 v15 (`0x0002000F`) completed simulation, compressed build,
and independent routed audit. The designated deploy helper hash-verified the
fixed test bundle. The automated XSDB programmer still fails to reach its
completion marker over XVC, but the user manually loaded the exact audited
image and the F1 mailbox then verified v15 healthy IDLE. Two unique fixed
60-second four-lane external PRBS31 requests passed at sequence/run IDs 1 and
2 (`0x00040401`), with equal nonzero lane records, zero errors, zero lock
losses, final F1 MCU temperature 53.5625 C, and valid clocks. This is an
initial hardware gate, not full qualification. See the
[v15 hardware record](docs/v15-programming-interface-failure.md).

Historical full Milestone 3 v14 (`0x0002000E`) was an audited diagnostic
candidate. It is a one-variable comparison to full v13: it disables only the planned
external-startup full-quad restart, while retaining v13 ownership, GT
configuration, staged acquisition, one bounded quad recovery, post-capture
restart, and runtime-integrity policy. V13 produced two independently
programmed, fresh pre-`RUN` `0x04000404` failures, so those requests are
preserved and are not retries. The v14 matching firmware, compressed build,
and independent routed audit pass: WNS/WHS `+0.222/+0.009 ns`, zero routing or
DRC errors, four met bus-skew constraints, all descriptor/profile/runtime
checks, 112-channel ownership, golden managed GT properties, and physical-only
heartbeat fan-in. Existing generated-IP/intentional CDC-methodology caveats
remain. Following a power cycle, F1 was programmed once through XVC
`TCP:apollo3010-1:2542` and two unique 60-second external sequences/run IDs 1
and 2 passed (`0x00040401`): all four lanes logged 1,546,848,197,680 and
1,546,848,072,800 tested bits, respectively, with zero errors and zero native
lock losses. This supports the narrow startup-restart hypothesis only; v14
remains diagnostic, not qualification. See [the v14 diagnostic record](docs/v14-no-startup-restart-diagnostic.md).

Isolated v275 / 2.5.25 (`0x00020119`) freezes v272's 100-ms runtime-integrity
policy and v273's planned startup restart as an initial qualification
candidate; the v274 heartbeat test hook is explicitly disabled. Full
simulation, matching firmware, compressed implementation, and independent
routed audit pass at WNS/WHS +0.009/+0.001 ns with zero routing or DRC errors.
The physical-only heartbeat fan-in, all descriptor/profile/runtime structural
checks, golden GT placement/properties, current IP, and implemented clocks
pass. Existing v273 CDC/methodology findings and the absence of isolated-target
bus-skew constraints remain. F1 was programmed once with the exact audited
image and passed two unique consecutive 10-second four-lane external baselines
without reload or retry. Both had planned startup plus cleanup, four complete
zero-error profiles, zero native lock losses or integrity events, and 125 trace
events without overflow. The unique sequence-3 uninterrupted 12-hour external
soak then passed without reload or retry: request/response/run ID 3, normal
summary `0x00040401`, and four equal records of 1,113,731,693,556,560 tested
bits with zero errors, lock losses, or saturation (`BER95 < 2.694e-15` per
lane). F1 remains v275 healthy IDLE at sequence/run ID 3. Final FPGA
temperature was 24.5 C, raw/unvalidated F1 AVTT current was -0.6494140625 A,
and required 100/325-MHz plus managed 322.262-MHz clocks were healthy. Do not
resubmit sequence 3 or rerun its consumed `results` operation. This passes the
clean-baseline and 12-hour-soak gates, not full qualification. See the
[v275 qualification-candidate record](docs/v275-qualification-candidate.md).

Isolated v274 / 2.5.24 (`0x00020118`) is built, independently audited, and has
passed its controlled heartbeat-monitor hardware gate. One unique 10-second
sequence/run-1 baseline was clean on all four lanes, with planned startup plus
cleanup, zero integrity events, and no retry. The fixed sequence/run-2 watcher
then asserted only the monitor suppression, observed a retained clock-only
stage-27 integrity fault after about 119 ms, and restored the control with its
second and final write. Physical managed RX clock stayed 322.260 MHz, the quad
remained READY without reset/fault, data-cause lanes stayed clear, and lane 15
recorded only the expected two-cycle toggle-edge pulse. F1 now retains the v274
sequence/run-ID-2 platform fault; no later request, reset, or reload occurred.
V274 is a controlled heartbeat-monitor diagnostic. It preserves v273 behavior
and adds a default-off hook that suppresses only the divided heartbeat presented to the
runtime-integrity monitor; the physical GT and RXUSRCLK2 clocks remain live.
Full simulation, matching firmware, compressed incremental implementation, and
routed audit pass at WNS/WHS +0.009/+0.001 ns with zero routing or DRC errors.
All descriptor/profile/runtime structural checks pass, and a v274-specific
routed fan-in check proves the control reaches `heartbeat_meta_reg`. Existing
CDC/methodology caveats remain; the intentional pre-synchronizer hook accounts
for one CDC-3 becoming CDC-10, and this isolated target has no bus-skew
constraints. This validates the injected monitor branch, not actual missing
physical RXUSRCLK2 or optical/native lock loss. See the
[v274 build and test plan](docs/v274-heartbeat-test.md).

Isolated v273 / 2.5.23 (`0x00020117`) tested one planned coordinated full-quad
restart after external controls settle while preserving v272 runtime integrity.
Full simulation, matching firmware, compressed incremental build, and
independent audit pass (WNS/WHS +0.009/+0.001 ns, zero routing/DRC errors).
Two consecutive unique 10-second F1 baselines passed without reload or retry.
Each recorded planned restart cause 4 plus normal cleanup cause 3, no reactive
cause-2 recovery, four complete zero-error profiles, zero native lock losses,
and no trace overflow. This conclusively resolves the narrow startup question
in favor of the planned restart. A sequence-3 launcher race was safely refused
by the watcher before any stimulus write; the resulting clean run was preserved
and not reused. Race-free sequence 4 then captured exactly two lane-12 error
cycles without tripping integrity. Sequence 5's 250.304-ms F1_5 channel-0
disable retained one lane-12 integrity event, no shared-clock cause, and fault
stage 27. `RXPRBSLOCKED` was asserted on all lanes at first fault and later
fell when the retained fault disabled the checker; the physical quad remained
READY and was not reset. The final `0x280c`–`0x280f` records are synthetic
platform-failure records, not measured lock-loss counters. This passes the
lane-data gate but is not full qualification and does not
exercise optical LOS/CDR loss or missing RXUSRCLK2. At the end of the v273
gate F1 was in the sequence/run-ID-5 retained platform fault; the later v274
gate summarized above supersedes that state.
See the
[v273 build and hardware record](docs/v273-planned-startup-restart.md).

Before v273, the v272 lane-data runtime-integrity hardware gate passed on F1.
After two
10-second clean measurements that each required one bounded acquisition
recovery, sequence 3 proved that a watched two-cycle lane-12 pulse does not
trip the detector. Sequence 4 disabled only F1_5 channel 0 for 0.250289 s and
correctly published retained platform fault `0x04000404`, fault stage 27, one
integrity event, and lane 12 as the sole retained cause; adjacent lanes stayed
clean and no shared-clock cause or native lock loss was recorded. Byte 86 was
restored and post-test health passed. This validates the tested data-integrity
branch, not optical LOS/CDR loss or missing RXUSRCLK2. V272 is not fully
qualification-ready because both clean baselines needed acquisition recovery.
An explicitly authorized same-image reload later cleared the retained fault.
One fresh sequence/run-ID-1 startup request reproduced the bounded recovery:
all lock/reset/clock qualifiers were healthy, all four lanes were observed
error-active, and the aggregate had zero clean cycles for 100 ms before the
full-quad restart recovered it. The following 10-second measurement was clean;
no retry followed. F1 was then v272 healthy IDLE at sequence/run ID 1. See the
[v272 hardware gate](docs/v272-hardware-gate.md) and
[startup-recovery investigation](docs/v272-startup-recovery-investigation.md).

Isolated v272 / 2.5.22 (`0x00020116`) is now frozen, built, and independently
audited with the runtime-integrity detector enabled only in that target. The
complete simulation regression, matching firmware build, compressed
incremental implementation, and routed structural checks pass. During the
registered measurement window the detector
qualifies sustained lane-local PRBS corruption (100-ms consecutive
threshold) and loss of the shared RXUSRCLK2 heartbeat as separate observations;
it does not claim optical LOS or CDR loss. A qualified event follows the
existing platform-fault publication path, retains fault stage 27, and activates
the previously reserved selector-`0xFD` integrity capability/words. The full
engine simulation publishes an atomic failed result; the measured two-cycle
v271 transient does not trip. See the
[runtime-integrity design](docs/runtime-integrity-candidate-design.md) and the
[v272 build record](docs/v272-build.md). Routed timing is WNS +0.018/WHS
+0.001 ns, routing and DRC errors are zero, and the detector synchronizer
structure passes explicit audit. Existing unrelated CDC/methodology caveats
and the absence of isolated-target bus-skew constraints remain. No hardware
was programmed during the build; the hardware result above now supersedes that
pre-program state.

The threshold decision is now closed by a v271 hardware characterization. A
250.280-ms F1_5 channel-0 disable produced one uninterrupted lane-12
error-active run of 3,133,090,464 RX cycles (about 9.72 seconds), zero adjacent-
lane errors, and zero native lock losses. The following clean sequence 6 passed
all four lanes, proving recovery after cleanup. The 100-ms consecutive-error
threshold is accepted for v272; the optical test did not
exercise missing RXUSRCLK2. F1 was v271 healthy IDLE at sequence/run ID 6
before the explicitly authorized v272 programming described above.
Required clocks and regulator status were healthy and F1_5 was 38 C. The FPGA
SysMon temperature query did not complete, so this run has no final FPGA-
temperature measurement. Board diagnostics must remain serialized on the
single MCU UART.
See [the threshold characterization](docs/v271-firefly-threshold-characterization.md).

Isolated diagnostic v271 / 2.5.21 (`0x00020115`) now implements the
zero-elapsed-profile repair. The complete Milestone simulation suite,
compressed incremental build, and independent routed audit pass. Routed
timing is WNS +0.018/WHS +0.001 ns with zero routing or DRC errors; all 16
descriptor bounds pass (worst +1.568 ns). The eight repaired measurement
crossings no longer have combinational logic before their synchronizers, and
all measurement/epoch first stages pass a direct registered-source structural
audit. Existing unrelated CDC/methodology caveats remain, and the isolated
target has no bus-skew constraints. F1 was then programmed with the exact
audited image and two consecutive 10-second four-lane external baselines
passed without reload or retry. Both request-toggle phases produced four
equal, nonzero profiles with zero errors/losses; traces retained 93/104 events
without overflow. A subsequent sequence-3 lane-12 pulse produced exactly two
error-active/profile cycles while all other lanes stayed clean. The complete
publication remained bit-for-bit stable for about 158 seconds after RUN, and
clean sequence 4 correctly replaced it with four equal nonzero profiles. At
that gate F1 was v271 healthy IDLE at sequence/run ID 4; sequences 5 and 6
above supersede that state. This supplies hardware support
for the profile repair, not hardware qualification. See
[v271 build record](docs/v271-build.md),
[v271 hardware baselines](docs/v271-hardware-baselines.md),
[profile hardware gate](docs/v271-profile-hardware-gate.md), and
[profile investigation and repair](docs/v270-profile-investigation.md).

## Historical diagnostic chronology

The entries below preserve earlier states and decisions. Their words such as
“next,” “latest,” or “remains” describe the time of that entry and do not
supersede the current all-direct v12 resume point above.

Historical result: F1 was back on v270 after an authorized reload, IDLE at sequence/
run ID 1. Timed alarm sampling confirms F1_5 FF/FF in IDLE, 00/00 during RUN,
then FF/FF in IDLE. Ordinary four-lane baseline records passed, but diagnostic
validation failed because lane 12's RX profile was marked valid with zero
elapsed cycles. Evidence is preserved; no retry. See
[RUN/IDLE alarm comparison](docs/v270-run-idle-alarms.md). The golden-loaded
description below is historical.

Historical golden update: F1 was reloaded with the unchanged historical golden IBERT
image for an authorized comparison after the successful post-power-cycle v270
baseline. The user explicitly permitted this historical uncompressed artifact;
new builds still require compression. The golden four-lane 10-second external
PRBS31 baseline passed with zero errors; F1 remains golden with links running.
F1_5 module LOS/CDR LOL both read 00 on the follow-up snapshot; continuous
golden versus idle v270 is an important comparison caveat. See
[comparison evidence](docs/golden-comparison-20260912.md). The v270/run-3
description below is historical, not the current loaded image.

Historical v270 observation: **F1 ran isolated diagnostic v270 (`0x00020114`),
healthy IDLE after request/response/run ID 3. The lane-12 pulse test passed**:
one injection request produced two RXPRBSERR-active cycles on lane 12 only,
zero lock losses, one cleanup restart and 103 retained trace events without
overflow. See [pulse characterization](docs/v270-pulse-characterization.md).
Both preceding 10-second four-lane external baselines passed, without a reload
between them: zero errors/losses, all
four lanes selected, one cleanup restart per run, traces of 103/108 events
without overflow. See [hardware baseline evidence](docs/v270-hardware-baselines.md).
No optical disable or fourth request was issued. F1 was 26.0 C before/after
the pulse; supply status clear. Optical characterization is paused pending
resolution of FireFly `FF/FF`: individual and block reads agree on page zero,
with plausible identity and telemetry. This is not complete qualification.

Historical v269's first baseline failed. Both MCU and AXI
descriptors requested `0xF000`, but lane 12 remained unselected and the result
was `0x00030301`; lanes 13–15 were clean. The expanded trace retained all 127
events without overflow and recorded an acquisition restart plus cleanup.
No second v269 run or fault stimulus was performed; it was later replaced by v270.

A focused simulation reproduces stale lane selection when the descriptor
synchronizer arrives one RX cycle after the start request. This establishes
an RTL CDC defect consistent with the hardware signature, not proof of the
exact hardware timing. A [source-level repair and regression](docs/descriptor-transfer-repair.md)
now adds descriptor settling time, retained accepted PRBS mode and publication
mask checking. The new [v270 / 2.5.20 diagnostic build](docs/v270-build.md)
(`0x00020114`) and independent routed audit pass: compressed, WNS +0.325 ns,
WHS +0.001 ns, zero routing/DRC errors. All 16 descriptor paths now have
effective 3.000-ns bounds, with worst slack +1.568 ns. Build time was 11m14s
using checkpoint/IP reuse. Existing non-descriptor CDC caveats remain.
V270 was programmed and passed the two baseline gates above. The FireFly
`FF/FF` readback investigation and later timed stimulus are recorded in the
newer v271 status above.

See [hardware evidence and next gate](docs/v269-hardware-baseline.md),
[build state](docs/memory/build-state.md), and [project memory](docs/memory/project.md).
Full-M3 v12 is a separate, unqualified artifact; v11's long-soak pass does not
constitute complete qualification. V272's lane-data detector passed its
hardware gate, but v272 is not fully qualified because both clean baselines
needed acquisition recovery and the shared-clock branch remains untested.

## Diagnostic development history

Recovery plan items 1–4 passed source/simulation validation; see
[the diagnostic archive, reset contract and retained diagnostic ABI](docs/recovery-items1-4.md).
[Items 5–6](docs/recovery-items5-6.md) add a separate v268 transition/error-profile
diagnostic build for characterization. Its build/audit passed, but the clean
hardware baseline overflowed the trace; characterization remains in progress.
Neither it nor archived v267 is a qualification candidate.
For fast isolated diagnostic iterations, see the
[checkpoint-reuse build flow](docs/incremental-diagnostic-builds.md). V269
expands the trace after v268's clean baseline exceeded its 64-entry capacity.
Its incremental build and independent routed audit passed in development:
10m57s build time versus v268's 14m41s (different RTL revisions). Its first
[hardware baseline](docs/v269-hardware-baseline.md) retained all 127 trace events
but unexpectedly left lane 12 unselected; further hardware tests are paused.
The eventual qualification candidate still requires a clean build.

## Quick start (golden standalone IBERT build)

The build requires Vivado 2023.2 with support for UltraScale+ devices:

```sh
vivado -mode batch -source scripts/create_project.tcl
```

This creates `build/vu13p_ibert_25g.xpr`. To generate the bitstream directly:

```sh
vivado -mode batch -source scripts/build_bitstream.tcl
```

All bitstream targets default to compressed output. The golden `top.bit` sets
`BITSTREAM.GENERAL.COMPRESS` in `constraints/board_pins.xdc`; the separate
Milestone 2 target sets the same property in its target-specific XDC, and
Milestone 3 inherits the board constraint. Every bitstream build script rejects
output if compression is not enabled.

The golden build and synthesis-continuation flow also generate `top.bin`
alongside `top.bit` in `build/vu13p_ibert_25g.runs/impl_1/`, using Vivado's
`STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE` option. The all-links v2 writers
`scripts/write_all_links_v2_bit.tcl` and
`scripts/write_all_links_v2_timing_hardened_control_boundary_fix_bit.tcl`
use `write_bitstream -bin_file` to emit a `.bin` beside the same-named `.bit`
from the audited checkpoint. BIN is the raw configuration image without the
BIT file header; compression remains enabled. These changes apply to future
output generation; archived artifacts and hardware release checks are unchanged.

Existing images were converted to BIN on **2026-11-09** without rerunning
synthesis, implementation or bitstream generation:

| Image | BIN file | Bytes |
| --- | --- | ---: |
| Golden IBERT, compressed | [golden_ibert_compressed.bin](build/configuration_bins_20261109/golden_ibert_compressed.bin) | 70,389,172 |
| Golden IBERT, historical uncompressed | [golden_ibert_historical.bin](build/configuration_bins_20261109/golden_ibert_historical.bin) | 113,318,376 |
| Latest audited all-links v2, `0x00020501`, compressed | [all_links_v2_timing_hardened.bin](build/configuration_bins_20261109/all_links_v2_timing_hardened.bin) | 70,100,232 |

Each BIN is the complete configuration payload of its existing BIT, with only
the container header removed. Byte order, compression and embedded BRAM data
are preserved; no padding or bit swapping was applied. Each output was checked
byte for byte against its source payload, and source BIT hashes remain
unchanged. [manifest.json](build/configuration_bins_20261109/manifest.json)
records source paths, header offsets and source/output SHA-256 hashes;
[SHA256SUMS](build/configuration_bins_20261109/SHA256SUMS) verifies the BINs:

```sh
(cd build/configuration_bins_20261109 && sha256sum -c SHA256SUMS)
```

These local generated files remain ignored by Git. No programming or hardware
test accompanied conversion; the existing BIT-based deployment pins remain in
effect.

The generated IBERT `quad_pblock.tcl` files contain paths relative to each
generated-core wrapper. `scripts/apply_ibert_floorplan.tcl` is installed as a
pre-place hook so the encrypted vendor constraints execute in the correct
hierarchical context; the hook requires 14 pblocks from each core.

The board's 200-MHz oscillator clocks the frequency monitor, I2C, and SysMon
logic. A dedicated `BUFGCE_DIV` output divides it by four for the distributed
IBERT debug hub and XSDB/DRP register fabric, matching the vendor example's
50-MHz debug-clock configuration.

If synthesis completed but a post-synthesis validation stopped the build, reuse
that checkpoint instead of rebuilding it:

```sh
vivado -mode batch -source scripts/continue_after_synthesis.tcl
```

Generated projects, IP products, reports, and run directories are ignored by
Git. Review `report_ip_status`, synthesis and implementation warnings, DRCs,
timing, and implemented GT placement before programming hardware.

## Configuration

- Device: `xcvu13p-flga2577-2-e`
- Line rate: 25.78125 Gb/s
- GT reference clocks: REFCLK0, 322.265625 MHz
- FireFly: 56 TX/RX lanes in GTY quads 121-134
- FPGA-to-FPGA: 56 TX/RX lanes in GTY quads 221-234
- Quad-L AXI C2C links are intentionally excluded; that interface operates at 10 Gb/s.
- Top level: `src/top.sv` (SystemVerilog).
- Four `SYSMONE4` monitors, explicitly placed one per SLR, sharing the board's
  dedicated SysMon PMBus pair. The 7-bit addresses are SLR0=`0x36`,
  SLR1=`0x34`, SLR2=`0x47`, and SLR3=`0x45`.

The four addresses are deliberately visible in the `sysmon_i2c_ssi` instance
in `src/top.sv` so they can be changed easily. Address bit 2 is set to select
PMBus behavior in `SYSMONE4`.

## Repository layout

| Path | Purpose |
|---|---|
| `src/top.sv` | SystemVerilog top level, address settings, and register map |
| `src/ibert_top.vhd` | Physical-lane packing for the two IBERT wrappers |
| `src/ibert_ultrascale_gty_*.vhd` | Structural wrappers for the generated IBERT IP |
| `src/clock_*.sv` | Input buffering and frequency measurement |
| `src/i2c_register_slave.sv` | Secondary I2C register slave |
| `src/sysmon_i2c_ssi.sv` | Four SLR-local SysMon instances and shared I2C wiring |
| `ip/` | Vivado IBERT XCI configurations |
| `constraints/` | Board pins, IP timing, SysMon placement, and CDC constraints |
| `scripts/` | Reproducible project creation and bitstream build |

## HDL-first parallel-test migration shell

An opt-in Milestone 2 hardware target provides the first HDL-first migration
stage without changing the golden IBERT project or `src/top.sv`. It includes a
Tcl-generated MicroBlaze supervisor, embedded interrupt-driven firmware, an
AXI4-Lite job controller, 112 concurrent synthetic lane engines, explicit CDC
handshakes, atomic double-buffered result BRAM, one completion interrupt, and
the reserved `0xA0`-`0xFF` I2C mailbox at the existing generic-slave address
`0x2B`. Both FPGA RGB LED triplets show a pre-firmware blue heartbeat, solid
blue while busy, healthy-idle green, or idle fault red; green depends on an
AXI write made by the embedded C supervisor. See
[docs/gt-test-engine.md](docs/gt-test-engine.md) for the separate build
commands, register map, result format, validation evidence, and LED pinout.

Milestone 3 is a second opt-in target. It removes only FireFly 5 / physical
quad 124 from the left IBERT core, manages those four lanes through a native
GT Wizard and HDL quad/lane controllers, and leaves the other 108 lanes under
IBERT. It adds atomic XPM result handshakes, native PRBS/loopback/error
injection, fatal quad-fault completion, and a 1-ms hardware timebase for long
soaks. The build and first-board-test commands are in the same document; keep
the compressed golden IBERT image available as the recovery image.

The historical full Milestone 3 development candidate was v12, version
`0x0002000C`. It preserves v11 acquisition behavior and adds native per-lane
`RXCDRLOCK` to runtime lock-loss detection without changing the MCU ABI.
The clean simulations, Vivado 2023.2.2 build, and independent routed audit
pass: WNS is `+0.141 ns`, WHS is `+0.009 ns`, all 785,247 routable nets are
fully routed, all four bus-skew constraints pass with worst slack
`+19.437 ns`, and all 13 IP instances are current. The compressed versioned
image is
`build/gt_test_milestone3/gt_test_milestone3.runs/impl_1/gt_test_milestone3_v12.bit`
(69,787,395 bytes, SHA-256
`35e8ba4ec565c9972e72e3ebf61ee842fd446d2b51d35650f1d9ec2b76ca180f`).
One PMA smoke and the following 60-second external smoke passed on F1, but
other fresh/restart attempts produced preserved `LOCK_WAIT` acquisition
faults, including one post-reload PMA failure. After a later explicit reload,
PMA and external gates passed again, but the FireFly CDR-loss stimulus showed
that native FPGA `RXCDRLOCK` remained asserted: lane 12 alone saturated its
error counter yet recorded zero lock losses while the module reported isolated
RX0/TX0 LOS and RX0 CDR LOL. V12 is therefore not hardware-qualified.
See `docs/memory/build-state.md` for the exact run history.

An isolated diagnostic target, Milestone 2.5.4 (`0x00020104`), now measures
RXPRBSERR-active cycles and substitutes managed RXUSRCLK2 into r38 without
changing any normal-image ABI. Its build and routed audit pass. Golden IBERT
proved that the FireFly outage leaves FPGA CDR lock, electrical-idle, and RX
clock indications healthy while producing sustained lane-local PRBS errors.
The first 2.5.4 external run failed acquisition before its FireFly stimulus
and was preserved without retry. An immediate post-fault golden check passed
all four external links cleanly, localizing the blocker to managed acquisition
rather than the optical loopback. F1 was left on golden. See
`docs/milestone254-signal-loss-characterization.md`.

Follow-up isolated targets 2.5.5/2.5.6 (`0x00020105`/`0x00020106`) tested a
one-shot RX reset after failed acquisition and safe post-capture RX-status
requalification. Version 2.5.6 completed one full FireFly channel-0 outage
characterization with healthy final IDLE: lane 12 asserted RXPRBSERR for
91.7491% of its measurement cycles, adjacent lanes stayed clean, lock-loss
counts stayed zero, and RXUSRCLK2 remained present. Its next unique request
failed acquisition before a planned transient injection; only lane 15 ever
locked despite the one recovery reset. The failure was preserved, and an
immediate golden control again ran all four links clean. The recovery is not
repeatable and must not be promoted. F1 is left on golden. See
`docs/milestone256-signal-loss-characterization.md`.

V11 (`0x0002000B`) is the preceding long-soak candidate. Its F1 short and
long-run record follows for historical continuity.
F1 short hardware acceptance passed on 2026-09-02: the lane-12 ten-second
external diagnostic and the lanes-12-through-15 60-second external smoke both
completed normally with zero measured errors and zero lock losses. The
four-lane run returned `0x00040401`, with 1,546,847,993,200 tested bits per
lane (`BER95 < 1.939e-12`). The following four-lane 12-hour F1 external soak
also passed, with zero errors and zero lock losses on every lane over
1,113,730,526,168,800 tested bits per lane (`BER95 < 2.694e-15`). It completed
at `2026-09-03T06:24:05+00:00`; final AVTT current and FPGA temperature still
need to be appended to the test record. The complete captured output is
`docs/evidence/legacy/milestone3_12hour_soak_20260902_182351.log`.

The subsequent unattended 24-hour v11 external qualification passed. Final
results captured in `docs/evidence/legacy/24hour.txt` on 2026-09-10 show matching request/response
sequence `5`, stable hardware run ID `4`, response/summary `0x00040401`, and
healthy IDLE. Lanes 12-13 each tested 2,227,461,058,375,760 bits over
27,843,263,229,697 valid cycles; lanes 14-15 each tested
2,227,461,058,375,680 bits over 27,843,263,229,696 valid cycles. Every lane
reported zero errors, zero lock losses, and `BER95 < 1.347e-15`; the counts
retain exact 80-bit-per-cycle accounting. No first-fault snapshot was valid.
The retained acquisition observation recorded sampled-error mask `0xF` and
sampled-unlock mask `0`; those startup observations were excluded from the
measurement by the post-observation native-counter reset.
The SSH connection died during the run, so the scheduled half-hour watcher
output was not retained; the file is the final-results snapshot rather than a
continuous status log. The exact completion timestamp, final F1 AVTT current,
and FPGA temperature remain to be appended.

The preceding full-image candidates remain historical records.
Version `0x00020008` extended bounded acquisition to ten seconds and added
persistent first-fault diagnostics. Its external smoke proved healthy quad
qualification and normal completion, but lanes 12 and 15 saturated their
native PRBS error counters even when tested separately. The same GT primitive
properties and pins passed in the isolated Milestone 2.5 image; the decisive
difference was the later external-path `GTRXRESET` sequence. Version
`0x00020009` therefore kept the receiver live in external mode, qualified the
quad supervisor from ARM through lock, retained the PMA-loopback reset flow and
post-lock counter clear, and waits for a stable four-bit running mask before
capturing it. Its clean implementation and audit passed, but its first
lane-12 launch exposed a missing increment in that stable-mask counter: the
engine remained in ARM with running mask `0x1` and the PRBS controller IDLE.
Version `0x0002000A` adds the missing progress assignment and a bounded
testbench watchdog. The selector-`0xFE` diagnostics remain unchanged. The v9
image passed its clean Vivado 2023.2.2 implementation and independent routed
audit. The v10 clean build and independent routed audit also pass: routed
timing, routing, all four bus-skew constraints, compression, GT ownership and
placement, 100/325-MHz clocks, and the golden managed-GT property checks are
all qualified. Its 70,098,947-byte bitstream has SHA-256
`fa4042fd1def68935e34e5c4d282d5db7416cc1182518b3a46c4e2f5fb40d268`.
The first v10 lane-12 diagnostic proved the ARM-progress fix and completed
normally, but reported exactly one native PRBS error with no lock loss or
saturation. The image therefore remains hardware-unaccepted; repeat the same
lane-12 test before attempting the 60-second all-lane smoke.
The previously validated isolated Milestone 2.5 and full Milestone 3 test
artifact is version
`0x00020004`; its hashes and hardware results remain historical records. The
intermediate `0x00020005` build failed routed setup timing and must not be
programmed. Version `0x00020006` passed implementation and proved that the
external path enters and completes `ST_RUN`, but its first 60-second test was
contaminated by pre-measurement acquisition errors on lanes 12, 14, and 15;
it is superseded by the later candidates.

Python 3.6-compatible operator utilities are provided for the external-path
smoke/soak campaign and clock-monitor readout:

```sh
python3 scripts/milestone3_60second_external_smoke.py start
python3 scripts/milestone3_12hour_external_soak.py status
scripts/run_milestone3_24hour_qualification.sh
python3 scripts/milestone3_dump_results.py
python3 scripts/milestone3_platform_diagnostics.py
python3 scripts/read_fpga_frequencies.py --fpga F1
```

These scripts use the `cm_interface` generic-port API, which performs the
board semaphore and I2C-mux handling. The frequency reader validates `r39`
before reporting all 37 direct-kHz values from `r02` through `r38`; it never
applies x2 scaling. The result dumper does not apply pass criteria or alter
the published result; its only write selects lane records through `0xCC`, so
it remains useful after an aggregate failure causes the normal results stage
to stop early.

The unattended 24-hour v11 qualification wrapper defaults to request sequence
`5` after sequence `4`, checks status 48 times at 30-minute intervals, captures
output to both screen and a timestamped log, and collects final results. It
must be executed under POSIX `sh` or
BusyBox `ash`, not sourced. The accepted run matched those continuation
defaults, although its periodic watcher output was lost with the SSH
connection. On 2026-09-11, v11 then passed targeted lane-12 error injection
(sequence 6/run ID 5), explicit abort (sequence 7/run ID 6), and automatic
timeout (sequence 8/run ID 7). A sequence-9 CPU-halted-test launch failed
before RUN with summary `0x04000404`: retained diagnostics show all four lanes
running but only mask `0xB` ever PRBS-locked, isolating the acquisition failure
to lane 14 while quad power, QPLL, user clocks, and reset-done remained healthy.
That result was preserved and was not retried. F1 was then explicitly reloaded
with the same audited v11 image. A fresh post-reload CPU-halted test passed as
sequence 1/run ID 1: hardware completed and published `0x00040401` while the
processor was stopped, the four lane records were clean and coherent, and
firmware acknowledged the same result after resume without restarting it.
The physical FireFly-5 channel-0 output was subsequently disabled through
lower-page byte 86 bit 0 for one second (post-reload sequence 4) and ten
seconds (sequence 5), restoring and verifying the original byte after each
interval. Both runs isolated the disturbance to global lane 12: its exact error
counter saturated while lanes 13-15 stayed error-free. However, the managed
GT's `RXPRBSLOCKED` input never deasserted, all lanes accumulated their full
valid-cycle counts, and lane 12 published zero lock losses. Thus the physical
single-lane disturbance isolation passed, but v11 did not demonstrate the
required lock-loss indication and is not fully hardware-qualified. Sequence 6
repeated the ten-second interval but sampled incorrect candidate alarm
addresses `0x07` and `0x15`; those zero reads are not module evidence.
Sequence 7/run ID 7 used the correct read-to-clear interrupt bytes. During the
disable, LOS byte 3 was `0x11` (RX0 and TX0) and CDR-LOL byte 5 was `0x01`
(RX0), proving that the module saw the intended isolated signal and CDR loss.
Nevertheless, the final v11 record again saturated errors only on lane 12 and
reported zero FPGA lock losses on every lane.

The preserved `0x00020004` Milestone 2.5 image has a deliberately separate
Python 3.6 test family. These scripts reject current Milestone 3 images and require clean request,
response, and run-ID state after programming. First reproduce the historical
one-second external smoke, then reprogram the same v2.5 bitstream before
running the automated restart/PMA-recovery matrix:

```sh
python3 scripts/milestone25_historical_external_smoke.py
# Reprogram the preserved v2.5 bitstream before the next command.
python3 scripts/milestone25_external_restart_matrix.py
```

Both scripts import only `milestone25_test_common.py`; they do not import the
current Milestone 3 soak module or weaken its version checks.

An isolated Milestone 2.5.1 diagnostic candidate tests the remaining managed-
PRBS acquisition hypothesis without paying the full two-IBERT Milestone 3
build time. It still contains only quad 124 (`MGT_X0Y16`-`X0Y19`), and keeps
the preserved v2.5 and full-M3 targets unchanged. Its distinguishing behavior
is to establish TX PRBS31 first, hold the RX checker disabled until the TX
control has settled, require one millisecond of continuously locked and
sampled-error-free RX operation, clear acquisition counts, and only then begin
the requested measurement. Build and independently audit it with:

```sh
scripts/build_milestone251_firmware.sh
vivado -mode batch -source scripts/build_milestone251_bitstream.tcl
vivado -mode batch -source scripts/audit_milestone251_routed.tcl
```

The resulting compressed candidate is version `0x00020101` at
`build/gt_test_milestone251/gt_test_milestone251.runs/impl_1/gt_test_milestone251.bit`.
After programming that image into F1, run its self-contained Python 3.6
acceptance matrix:

```sh
python3 scripts/milestone251_acceptance.py
python3 scripts/milestone251_platform_diagnostics.py
```

The script requires a freshly programmed, zero-sequence mailbox. It runs two
lane-12 external jobs, one four-lane external job, one four-lane near-end-PMA
job, and a final lane-12 external job. It sleeps and polls internally, prints
all selected lane records, and fails on any nonzero error, lock loss,
saturation, state/version mismatch, or aggregate mismatch. This candidate is
routed and audited but remains a diagnostic image until that hardware matrix
passes. The acceptance script prints selector-`0xFE` automatically if a
platform fault occurs; the separate diagnostic command can reread the same
persistent first-fault snapshot afterward without starting or clearing a run.

Milestone 2.5.2 (`0x00020102`) is the isolated follow-up to that result. It
keeps TX-before-RX staging, but observes a fixed 1-ms checker interval instead
of demanding that the entire interval be error-free. It retains whether an
error or unlock was sampled and the maximum consecutive clean streak, then
resets the native PRBS counters and begins the requested measurement. This
separates acquisition diagnostics from the acceptance measurement and avoids
turning a persistently noisy checker into a platform timeout.

Build, independently audit, and test only the matching candidate artifacts:

```sh
scripts/build_milestone252_firmware.sh
vivado -mode batch -source scripts/build_milestone252_bitstream.tcl
vivado -mode batch -source scripts/audit_milestone252_routed.tcl
python3 scripts/milestone252_acceptance.py
python3 scripts/milestone252_platform_diagnostics.py
```

Program
`build/gt_test_milestone252/gt_test_milestone252.runs/impl_1/gt_test_milestone252.bit`.
The acceptance matrix uses a fresh mailbox and runs the same five jobs as
2.5.1. The complete F1 matrix passed: first and repeated lane-12 external
tests, the four-lane external test, four-lane near-end PMA loopback, and the
post-PMA lane-12 external test all completed with zero errors and zero lock
losses. The fixed observation plus post-acquisition counter reset is therefore
the accepted managed acquisition sequence for quad 124. The current post-run
acquisition diagnostic fields clear in IDLE; their displayed zeros are not
retained evidence about the preceding observation interval.

Milestone 2.5.3 (`0x00020103`) corrects only that diagnostic lifetime. The
accepted acquisition and measurement sequence is unchanged; completed
observation evidence now remains readable throughout IDLE and is cleared when
the next stable running mask is accepted. Build and audit it with the matching
`build_milestone253_firmware.sh`, `build_milestone253_bitstream.tcl`, and
`audit_milestone253_routed.tcl` scripts. After programming
`build/gt_test_milestone253/gt_test_milestone253.runs/impl_1/gt_test_milestone253.bit`,
run the focused Python 3.6 hardware check:

```sh
python3 scripts/milestone253_acceptance.py
```

It runs one ten-second lane-12 external test and additionally requires the
retained maximum-clean-streak field to be nonzero.

The focused F1 check passed. Lane 12 completed with zero errors, zero lock
losses, and 257,808,252,880 tested bits (`BER95 < 1.164e-11`). The retained
observation reported no sampled errors or unlocks and the full 200,000-cycle
(1.000-ms) maximum clean streak. Milestone 2.5.3 is therefore the accepted
baseline for the subsequent full-Milestone-3 integration.

## Generic I2C clock monitor

The secondary board I2C pins (`V36`/`J32`) host a separate 7-bit slave at
`0x2B`. Its address is set on the `i2c_register_slave` instance in `src/top.sv`.
Registers are byte addressed; multi-byte values are little endian. A write of
the register address followed by data writes consecutive bytes. A write of the
register address followed by a repeated-start read reads consecutive bytes.

The MCU names each aligned 32-bit location `rNN`, where `NN` is the decimal
word index and the I2C byte address is `4*NN`.

| MCU register | Byte address | Access | Value |
|---:|---:|---|---|
| `r00` | `0x00` | R/W | Debug scratch register 0 |
| `r01` | `0x04` | R/W | Debug scratch register 1 |
| `r02` | `0x08` | R | `clk_200_ext` frequency in kHz |
| `r03` | `0x0C` | R | `lhc_clk` frequency in kHz |
| `r04` | `0x10` | R | `tcds40_clk` frequency in kHz |
| `r05` | `0x14` | R | `rt_x4_r0_clk` frequency in kHz |
| `r06` | `0x18` | R | `rt_x12_r0_clk` frequency in kHz |
| `r07` | `0x1C` | R | `lf_x4_r0_clk` frequency in kHz |
| `r08` | `0x20` | R | `lf_x12_r0_clk` frequency in kHz |
| `r09` | `0x24` | R | Generated `clk_100` frequency in kHz |
| `r10` | `0x28` | R | Generated `clk_325` frequency in kHz |
| `r11` | `0x2C` | R | `rt_r0_p` frequency in kHz |
| `r12` | `0x30` | R | `rt_r0_n` frequency in kHz |
| `r13` | `0x34` | R | `rt_r0_l` frequency in kHz |
| `r14` | `0x38` | R | `rt_r0_i` frequency in kHz |
| `r15` | `0x3C` | R | `rt_r0_g` frequency in kHz |
| `r16` | `0x40` | R | `rt_r0_e` frequency in kHz |
| `r17` | `0x44` | R | `rt_r0_b` frequency in kHz |
| `r18` | `0x48` | R | `lf_r0_y` frequency in kHz |
| `r19` | `0x4C` | R | `lf_r0_w` frequency in kHz |
| `r20` | `0x50` | R | `lf_r0_u` frequency in kHz |
| `r21` | `0x54` | R | `lf_r0_r` frequency in kHz |
| `r22` | `0x58` | R | `lf_r0_af` frequency in kHz |
| `r23` | `0x5C` | R | `lf_r0_ad` frequency in kHz |
| `r24` | `0x60` | R | `lf_r0_ab` frequency in kHz |
| `r25` | `0x64` | R | `rt_r1_p` frequency in kHz |
| `r26` | `0x68` | R | `rt_r1_n` frequency in kHz |
| `r27` | `0x6C` | R | `rt_r1_l` frequency in kHz |
| `r28` | `0x70` | R | `rt_r1_i` frequency in kHz |
| `r29` | `0x74` | R | `rt_r1_g` frequency in kHz |
| `r30` | `0x78` | R | `rt_r1_e` frequency in kHz |
| `r31` | `0x7C` | R | `rt_r1_b` frequency in kHz |
| `r32` | `0x80` | R | `lf_r1_y` frequency in kHz |
| `r33` | `0x84` | R | `lf_r1_w` frequency in kHz |
| `r34` | `0x88` | R | `lf_r1_u` frequency in kHz |
| `r35` | `0x8C` | R | `lf_r1_r` frequency in kHz |
| `r36` | `0x90` | R | `lf_r1_af` frequency in kHz |
| `r37` | `0x94` | R | `lf_r1_ad` frequency in kHz |
| `r38` | `0x98` | R | `lf_r1_ab` frequency in kHz |
| `r39` | `0x9C` | R | ID/status word |

The status layout is `[31:16]=0x434D` (`CM`), bit 15=`measurement_valid`,
`[14:8]=37` monitored clocks, and `[7:0]=1` format version. Thus a completed
valid measurement reads `0x434DA501`. This word belongs at `r39`, not `r38`.

The 1-ms measurement window uses the board's 200-MHz oscillator as its
absolute reference. Entry 0 consequently reports the configured nominal
200,000 kHz; all other entries are measured relative to it. Missing or stopped
clocks report zero after the next completed window.

The 100- and 325-MHz monitor clocks are generated from `clk_200` by an MMCM
configured equivalently to a Clocking Wizard with a 1300-MHz VCO. GT monitor
values are reported directly; no additional multiply-by-two scaling is used.
For example, a 322.265625-MHz GT reference clock should read approximately
`322266`, not `644531`.

## Required board setup

Program every REFCLK0 synthesizer output used below to 322.265625 MHz before
starting IBERT scans. REFCLK1 is not used by this image.

| Link group | GTY quads | Physical REFCLK0 input |
|---|---:|---|
| FireFly 1 | 121-123 | quad 122 / `lf_r0_ad` |
| FireFly 5 | 124 | quad 124 / `lf_r0_af` |
| FireFly 2 | 125-127 | quad 126 / `lf_r0_r` |
| FireFly 3 | 128-130 | quad 129 / `lf_r0_u` |
| FireFly 6 | 131 | quad 131 / `lf_r0_w` |
| FireFly 4 | 132-134 | quad 133 / `lf_r0_y` |
| FPGA-FPGA M/N/O | 221-223 | quad 222 / `rt_r0_n` |
| FPGA-FPGA P | 224 | quad 224 / `rt_r0_p` |
| FPGA-FPGA A/B/C | 225-227 | quad 226 / `rt_r0_b` |
| FPGA-FPGA D/E/F | 228-230 | quad 229 / `rt_r0_e` |
| FPGA-FPGA G | 231 | quad 231 / `rt_r0_g` |
| FPGA-FPGA H/I/J | 232-234 | quad 233 / `rt_r0_i` |

## Source and provenance

The pin assignments are a restricted extraction of the upstream
`configs/Cornell_rev3_p2_VU13p-1-SM_USP/src/top_pins.xdc` file. The two IBERT
XCI configurations and their structural wrappers derive from the upstream
`Cornell_rev3_p2_VU13p-1-SM_USP_heaters_TF` reference implementation. The
top-level mapping was rewritten for the rev3 FireFly numbering in the supplied
constraint file. The active package pins were cross-checked against the RevA
January 2025 schematic and canonical `VU13P_pins.xdc`: all 520 shared entries
match. FF6 RX lane 1 uses the schematic's bonded `M48`/`M49` pair; the canonical
XDC instead has obsolete `N48`/`N49` assignments commented out.

The VHDL integration wrapper deliberately packs each IBERT vector into an
intermediate signal before the port map. Do not replace this with multiple
slice associations of the same formal; Vivado reports Synth 8-5838 for that
construct.

FireFly 3 is the exception to the otherwise ascending lane packing. Schematic
page 64 maps lane 11 to GTY128 channel 0 and lane 0 to GTY130 channel 3, so its
12-bit RX and TX segments are reversed at the IBERT wrapper boundary. The
package-pin constraints retain the board's lane numbering.

A clean Vivado 2023.2 batch build remains the authoritative validation step.
