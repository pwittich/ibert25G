# AGENTS.md

## Scope

This repository builds Vivado 2023.2 IBERT and managed-GTY images for either
VU13P site on the Cornell rev3 board. Keep builds reproducible from Tcl and do
not commit generated `build/` products.

## Design invariants

- Target `xcvu13p-flga2577-2-e`; the golden-image top is `src/top.sv`.
- FireFly and FPGA-to-FPGA GTY lanes run at 25.78125 Gb/s from
  322.265625-MHz REFCLK0 inputs. Never add the 10-Gb/s AXI C2C lanes to these
  IBERT cores.
- Preserve the physical lane and reference-clock ordering in `README.md` and
  the XDC files. The full Milestone 3 image has 112 exclusive channel owners:
  52 left-IBERT lanes, managed `GTYE4_CHANNEL_X0Y16`-`X0Y19`, and 56
  right-IBERT lanes.
- In VHDL port maps, associate each vector formal once. Pack or unpack outside
  the map; Vivado rejects repeated slice associations of one formal.
- Treat XCI files and generated IBERT wrappers as Vivado-owned structure. Make
  only necessary wrapper edits and document them.
- Generate `clk_100` and `clk_325` from the 200-MHz board clock with the
  1300-MHz-VCO MMCM configuration. Keep both in the clock-monitor map.
- Every bitstream must be compressed. Set and enforce
  `BITSTREAM.GENERAL.COMPRESS=TRUE` in target Tcl/XDC and keep `README.md` and
  `docs/memory/build-state.md` current.

## Stable interfaces

- Preserve generic I2C address `0x2B` and visibly labeled SysMon addresses in
  `src/top.sv`: SLR0=`0x36`, SLR1=`0x34`, SLR2=`0x47`, SLR3=`0x45`.
- Preserve the MCU ABI documented in `README.md`: `r00`/`r01` are scratch,
  `r02`-`r38` are 37 direct-kHz clock readings in documented order, and `r39`
  is the `0x434D` status word. Never apply x2 scaling to GT monitor values.
- Preserve diagnostic selector `0xFE`, which maps `0xD0`-`0xEC` to live and
  first-fault platform diagnostics without moving normal lane or clock data.
- Diagnostic FSM encodings are ABI. Retain `fsm_encoding="none"` on engine,
  quad, and PRBS state registers and review synthesis for attempted recoding.
- Multi-byte generic-port values are little-endian. Keep operator scripts
  compatible with Python 3.6 and the `cm_interface` API.
- Board access must hold the MCU I2C5 software semaphore for the entire
  transaction and select exactly one FPGA through mux `0x70`.

## Managed-quad behavior

- Near-end PMA loopback uses `LOOPBACK=010` and the bounded RX datapath/PMA
  reset sequence. Default/historical external mode uses `LOOPBACK=000`, keeps
  an already-live RX datapath out of reset, and qualifies the quad supervisor
  through acquisition. The isolated v273 diagnostic explicitly performs one
  planned coordinated full-quad restart after controls settle; do not enable
  that default-off policy in historical targets.
- Preserve staged TX-before-RX startup, the fixed 200,000-cycle (1-ms)
  acquisition observation, and the post-observation native-counter reset.
- Retain completed acquisition diagnostics throughout IDLE; clear them only
  when the next stable running mask is accepted.
- Preserve the post-lock counter reset in both loopback modes. Startup errors
  captured by acquisition diagnostics must not contaminate measurement, while
  errors injected during measurement must remain countable.

## Targets and versions

- All-links v2 / `0x00020501` repairs v1's direct-only subset deadlock.  The
  engine's accepted 112-bit lane mask is reduced to 28 quad-participation bits
  and registered 6/8/8/6 with the four SLR-bank controls.  Only acquisition
  ready and capture done neutralize an unselected quad; global ready, fault,
  idle, reset and TX-session barriers remain all-quad. The image manages
  globals0--55 as the 56 FireFly lanes in q121--q134 and
  globals56--111 as the 56 direct FPGA-to-FPGA lanes in q221--q234; it has no
  IBERT and excludes the 10-Gb/s AXI C2C lanes. Integrated direct-only, sparse,
  all112, settle/barrier and changed-epoch tests plus the requested
  historical regressions pass.  Fresh synthesis/preflight passes exact
  112/28/12 GT inventory, 28 controllers, 112 engines, participation and all
  prior CDC/session/descriptor checks.  The single normal implementation is
  physically clean (212076/212076 routed, zero routing/Error-DRC failures,
  28/28 skew, hold +0.010 ns) but setup fails -0.158/-26.399 ns over 580
  endpoints in 18 clock groups.  Because this is broad, not comparable to
  v1's narrow 22-endpoint closeout, no optional post-route physopt, audit or
  bit followed.  Synth/routed-DCP/ELF SHA-256 values are
  `e1a8a3a20d177e6828b4378230dfb74d55bc624481f54fce86dcee8c2cd00a71` /
  `ec0de1a6268e76c3666f3d2984333e89e6c1b3ca05b2b3c1809f0faf4aa50f9c` /
  `d947fd47e684a1e0be08296d34b4de1b1e28d7c056ecabffcbfb681786730f9c`;
  evidence is frozen under
  `build/diagnostic_archive/all-links-v2-0x00020501-normal-route-timing-failure/`.
  The one-shot F1 PMA launcher drafted for this failed candidate remained
  unreleased/fail-closed and was later removed as obsolete; it never
  authorized a programming or hardware action. Loading any future all-links image also
  brings outward FireFly serializers up with PRBSSEL=0/zero userdata rather
  than v12 tied-off outputs.
  One later hash-pinned incremental close attempt reused the exact audited v1
  route at 98.94% of cells and 97.08% of nets. Its sole default phys-opt
  reached estimated WNS +0.001 ns, but the sole route failed signoff setup at
  -0.119/-5.883 ns over 93 `clk_200` endpoints. Hold passed at +0.005 ns;
  212112/212112 nets routed with zero errors, zero Error DRCs, and 28/28 skew
  groups met. Routed DCP SHA is
  `6fd5e2b102f7b2fc79e4868adc66b7fca4cb737c7aa4989ff21ef74c6dc91824`;
  evidence is under
  `build/diagnostic_archive/all-links-v2-v1-incremental-timing-close-attempt-retry2/`.
  No extra post-route physopt, retry, audit, bitstream, or hardware action
  followed.
  A later v2-only source hardening closes timing without changing ABI,
  topology, clocks, FSM encodings, sessions or barriers. It replaces the
  central result copy mux with four registered banks, splits each 256-bit
  snapshot transfer into four 64-bit handshakes, and localizes reset release
  per quad with matched latency. Only the eight existing control/reset
  boundary registers per SLR are hard-contained; result-copy placement is
  soft and diagnostic. Focused and historical regressions plus fresh exact
  synthesis/preflight pass. The focused implementation and independent audit
  pass setup/hold +0.046/+0.009 ns with zero failing endpoints,
  220150/220150 fully routed nets, zero routing/Error-DRC failures, 476/476
  skew groups, and strict physical participation/reset residency 6/8/8/6.
  Compressed BIT/routed-DCP/synth-DCP/ELF SHA-256 values are
  `163172d938f5aa87fd606061e75e058f5d7040916d86d4744a206309f970b66f` /
  `323ff58252ae66a81e42c84d38b528ce053561804cdc7eeecb99d3066107993a` /
  `a914ff24b3a9e9a106ff92a6276ce2c0842df701112c420e65e4c61e1847b8f9` /
  `d947fd47e684a1e0be08296d34b4de1b1e28d7c056ecabffcbfb681786730f9c`;
  exact evidence is frozen under
  `build/diagnostic_archive/all-links-v2-timing-hardened-control-boundary-clean/`.
  Both sites now run this exact audited image. The first 180-second direct
  hardware gate failed without retry: F1 passed all 54 fitted receive lanes;
  F2 passed 53/54, while global98/q231 saturated errors at `0xffffffff` with
  zero native lock losses. Both sessions stopped cleanly and that failed gate
  remains consumed. After a separately authorized board power cycle, both
  sites were reprogrammed with the same hash-pinned image and a fresh second
  180-second gate passed 54/54 receivers at both endpoints with zero errors
  and zero native lock losses; global98 passed with about 4.64e12 tested bits.
  Final F1/F2 are healthy IDLE/session-off at sequence/ack3, run1, with no
  retained platform fault. The second gate's sequences1--3/run1 are consumed;
  do not replay them. The pass supports, but does not prove, a transient
  board/startup-state cause for the first failure. See
  `docs/all-links-v2-inter-fpga-hardware-gate.md`.
  After a cold start, exact `all_links_v2_f2` may enumerate as the second bare
  FPGA at target2 or as target4 after F1 debug children appear. Its programmer
  permits only those two positions and still requires exactly two xcvu13p
  devices with F1 at target1; do not weaken other image topology guards.

  All-links-v2 timed test launchers (90-second default) are released for
  reviewed use. One tests both directions of the 54 fitted
  inter-FPGA receivers per endpoint; its full-mask TX session also drives all
  outward FireFly TXs and therefore requires an explicit acknowledgement.
  The other tests physical FireFly external loopbacks on a selectable
  q121--q134 receive quad/range at both endpoints; its session still drives
  all 112 TXs and also requires acknowledgement. Both validate required FPGA
  clock counters first and
  log pre/one-third/two-thirds/post 12-V power, FPGA diode, all-LGA80D, and all-FireFly
  temperatures. Each completed test process, pass or fail, creates an
  exclusive sibling Markdown report derived from the authoritative log, with
  frozen hashes, clock/lane/telemetry summaries and failure tail. The current
  user-facing launchers omit the obsolete `_90s` suffix:
  `board_all_links_v2_inter_fpga.py` and
  `board_all_links_v2_firefly_loopback.py`; duration defaults to 90 seconds.
  Their maintained remote bundle is `/home/cms/25G`; verify its clean
  `cm_interface` is exactly tag v1.0.0/commit
  `8e56fdf24c038b64f69f26b55f0facb7c77e0537` before every stage.
  The seven required remote runtime files were deployed and independently
  hash-matched on 2026-09-20; no hardware action accompanied that sync.
  Discover sequence/run state under the MCU lock by default; preserve the
  optional explicit predecessor guards for automation and do not automatically
  retry hardware actions. See
  `docs/all-links-v2-timed-tests.md`.
  Subsequent q121--q123 FireFly external-loopback run3 failed on F1 lanes
  1/3/4/6 (83/391/309/5 errors) and F2 lane4 (3 errors). The user's one
  explicitly authorized 90-second repeat, run4, reproduced the same four F1
  lanes at 104/400/306/15 errors while F2 passed 12/12. All records remained
  selected+locked, had zero native lock losses, and measured about 2.320e12
  bits/lane. Both sites stopped cleanly and are healthy IDLE/session-off at
  sequence/ack12, run4, with no platform fault and valid clocks. The repeat is
  consumed; do not retry it without new authorization. Repeat evidence is
  `build/diagnostic_archive/all-links-v2-timed-firefly-q121-q123-90s-1789945308268594.{log,report.md}`.
  Confirmed bench wiring self-loops q121--q124 independently on both F1 and
  F2; these are same-endpoint optical loops, not F1-to-F2 links. The symmetric
  two-site FireFly launcher and both endpoints' results are therefore valid.
  One later authorized 90-second q121--q124 run5 failed only the same F1 lanes
  1/3/4/6 at 56/172/84/10 errors. F2 passed 16/16; q123 and q124 passed on both
  sites. All lanes stayed selected+locked with zero native losses over about
  2.320e12 bits/lane. Cleanup passed; current F1/F2 are healthy IDLE/session-
  off at sequence/ack15, run5, no platform fault, valid clocks. The run is
  consumed. Evidence is
  `build/diagnostic_archive/all-links-v2-timed-firefly-q121-q124-90s-1789950159117782.{log,report.md}`.

- Historical all-links v1 / `0x00020500` is functionally superseded and must
  not be programmed despite its audited timing-clean artifact.  It is clean-synthesized but implementation-timing
  blocked and remains unqualified. Its
  symmetric top manages all 112 25G lanes: FireFly q121--q134 at globals0--55
  and direct q221--q234 at globals56--111. Focused source, aggregate/session-
  ack, fresh all112/subset engine, generated-IP/topology, firmware, project,
  RTL-elaboration, deterministic same-instance all112-to-sparse changed-mask,
  and clean synthesis/preflight gates pass; there is no candidate
  bit/DCP/audit/deployment or hardware test. Synthesis proves 112 channels, 28 commons, twelve managed-
  GT physical REFCLK buffers, no IBERT/C2C, and one matching ELF. Any external
  session can drive all selected outward FireFly TXs; external hardware testing
  is blocked pending explicit policy. Complete target-specific CDC/placement,
  compressed implementation, and independent routed audit before considering
  PMA hardware. A live-instance changed-mask descriptor re-arm trial is not
  qualified. The baseline clean route had zero failed nets/DRC errors but
  failed signoff setup at WNS/TNS -1.277/-1517.198 ns (clk_200 subset
  -0.978/-1406.601 ns). A reviewed hard whole-wrapper 6/8/8/6 pblock experiment
  removed partition warnings but worsened signoff setup to -1.412/-3535.183 ns
  (clk_200 subset -1.412/-2888.379 ns); it was reverted after preserving evidence
  under `build/diagnostic_archive/all-links-v1-hard-pblock-timing-failure/`. Do not repeat
  it. A reviewed enumerated-leaf controller/engine/Wizard-power-good/reducer
  attempt passed exact synthesis preflight but failed its mandatory placement
  proof: 506 real optimized leaves in 13 canonicalized roots escaped their
  expected SLR. It stopped before phys-opt/route at estimated WNS -1.240 ns;
  placed DCP SHA is `2210494576b52fe157cab387d4d2b5532bc315aa77c1755f5e20c4b3b8adb140`,
  with evidence under
  `build/diagnostic_archive/all-links-v1-enumerated-leaf-locality-attempt/`.
  Its pblocks and the conflicting final-reducer advisory were reverted. Do not
  repeat either hard-pblock approach. A subsequent all-links-only synthesis
  `KEEP_HIERARCHY` experiment preserved exactly 28 controller roots and passed
  fresh synthesis/preflight/post-opt. Its 256 roots split 55/73/73/55, but the
  mandatory placement gate still failed: 257 optimized leaves escaped across
  five mixed roots, and the reducer roots included ten excluded
  `tx_session_applied` primitives. Placed WNS improved to -1.089 ns and all 28
  bus-skew groups met, but the attempt stopped before standalone phys-opt/route.
  Placed DCP SHA is
  `9b3844aef5b5728d3dc6c270aa52c698f3e9e23df44115982c1ffb1dbffd0e9e`;
  evidence is under
  `build/diagnostic_archive/all-links-v1-keep-hierarchy-locality-attempt/`.
  Its synthesis property/XDC and pblocks were reverted; only the proven
  control/descriptor pblocks remain. Fresh post-revert synthesis and structural
  checks pass with zero controller `KEEP_HIERARCHY`/`DONT_TOUCH`; canonical DCP
  SHA is `7a65ce41ad68a407e113f5d39778d6438e6553f4665af1727f7a151bbf2d488b`.
  A later lean all-links-only source experiment introduced exactly four
  6/8/8/6 `all_links_v1_slr_bank` roots. Each has one existing seven-output
  control pipeline, one initialized-low synchronous local reset-release
  register, its wrappers, and one local reducer; the engine/final reducer and
  historical targets remain unchanged. Exactly four bank roots have
  `KEEP_HIERARCHY`, none has `DONT_TOUCH`; bank assignment is soft and only
  the intended 32 control/reset boundary registers plus descriptor launches
  have hard pblocks. Focused and full regressions pass. Fresh synthesis and
  exact preflight pass; DCP SHA is
  `409a7a24819c0da515d5443688df038649584c0b4e5820e583e909890b812ace`.
  Its original gate stopped at placement: control bit 1 was optimized away in
  every bank (6/6/6/6 remain), and 47 controller/reducer leaves crossed their
  SLR. Diagnostic setup improved to WNS/TNS
  -0.511/-3.798 ns over 48 endpoints; hold was -0.219/-9.499 ns over 192;
  all 28 bus-skew groups met and global POR was absent from significant
  endpoints. No phys-opt/route/bit/audit followed. Failed placed DCP SHA is
  `2ce015893cfbb15ad62be0bb77d98d71d697c44d517e1910e71dbab58271f439`;
  evidence remains unchanged under
  `build/diagnostic_archive/all-links-v1-slr-bank-attempt/`. A reviewed
  correction proved control bit 1 only fed constant-disabled wrapper runtime
  detectors (the 112 lane engines retain global measurement control), and all
  47 crossing leaves are timed publication-only paths with no controller
  feedback. The corrected placement gate passed. One default phys-opt/route
  continuation from the exact placed DCP then completed: 212,246 routable nets
  are fully routed, zero routing errors/unrouted/partial/overlap nets, zero
  Error DRCs, 28/28 bus-skew met, and hold +0.010/0.000 ns with zero endpoints.
  Only `clk_200` setup fails at WNS/TNS -0.034/-0.343 ns over 22 endpoints; all
  other clock groups pass. No bit/audit followed. Phys-opt/routed DCP SHAs are
  `ddd16b4d5678b838f39e2b1e8d6e1a70ad8f75df98d8901e0df49eea21e4b832` /
  `4631ff396e6b18baf61a312c6beaa7d77b00f6ba267830c40367a163a222a974`;
  evidence is under `build/diagnostic_archive/all-links-v1-slr-bank-closeout-continuation-retry1/`.
  Do not rerun that route or add speculative false paths. A reviewed,
  hash-pinned continuation opened only that routed DCP and ran one plain
  `phys_opt_design`, with no reroute/directive/retry. Setup/hold WNS is now
  +0.001/+0.010 ns with zero failing endpoints; 212,249/212,249 routable nets,
  zero route errors/Error DRCs, and 28/28 skew pass. The independent audit
  passes exact topology, GT properties, CDC/descriptor/session, and 6/8/8/6
  bank/reset structure. Compressed BIT/DCP/ELF SHA-256 values are
  `5cb71e186edf73ce42adc33eeaa9e1d9ef090468d2f4e297fc83cecc6c2e729d` /
  `a6862fdd15945b9532257d55dbfcb5e48dbde8c4ff9fb11637e7ed28d085d4c3` /
  `96d3ab54308b894d34f2add001c16d1aa52029bc1474aba506c3017ca6a978ae`;
  evidence is under
  `build/diagnostic_archive/all-links-v1-postroute-default-physopt-attempt/`.
  This audited build candidate has not been programmed or hardware-tested;
  require a separate reviewed hardware gate. See
  `docs/all-links-v1-source-milestone.md`.

- Current all-direct v12 / `0x00020409` is loaded on both F1 and F2. It uses
  selected per-lane RXRESETDONE and RXPMARESETDONE for post-capture
  requalification instead of the stale Wizard-wide aggregate that failed v11.
  Updated simulation, compressed implementation, focused structure inspection,
  and independent routed audit pass. Signoff WNS/WHS is +0.019/+0.006 ns,
  zero routing/DRC errors, all 14 bus-skew constraints pass (worst +1.746 ns),
  and the audit proves all 56 golden-matched channels, 14 dedicated common
  REFCLK routes, and 112 QPLL0 connections. Bit/DCP/ELF SHA-256 values are
  `5bce735128e22f3be029972e0290bf8a552dc196e08258a071b7ef31b30c5697` /
  `68d0e0535f4eb8f4b17169545a0f171415222da342a2bd1170a8942523454260` /
  `a2370f4b0b6132bffef5323aca834b5a4c174dfedeb4b0c113df6a0bc6a3c163`.
  Exact artifacts and cited evidence are frozen under
  `build/diagnostic_archive/direct-all-v12-0x00020409-scoped-pass/`; retained
  v12 deployment pins resolve only to its `artifacts/` subtree.
  Each endpoint passed one fresh all-56-lane 10-second PMA sequence/run 1 gate.
  One overlapping bidirectional external sequence-3/run-2 gate then passed all
  54 fitted receive lanes per endpoint at about 257.808e9 bits/lane, with zero
  errors and native lock losses. Both safe stops consumed sequence 4 and left
  F1 and F2 healthy IDLE at sequence/ack 4, run 2, state `0x00100000`, with
  sessions off, stable publications, and no retained fault. All v12 stages and
  sentinels are consumed: do not replay, reload, reset, or issue another
  request. This is broad fitted-link functional coverage, not long-BER or
  channel requalification. Complete record:
  `docs/direct-all-v12-hardware-gate.md`.

- Historical all-direct v11 / `0x00020408` passed both 56-lane PMA gates and
  published a clean 54-lane-per-site external measurement, but F1 later timed
  out in `POST_CAPTURE_RX_REQUAL`. Its selected primitive RX/PMA reset-done
  indications and quad supervisor were healthy while the Wizard aggregate was
  low. F2 stopped cleanly; F1 retained the stage-22 platform fault at
  sequence/ack 3, run 2. Exact artifacts and evidence are frozen under
  `build/diagnostic_archive/direct-all-v11-0x00020408-post-capture-aggregate-timeout/`.
  Do not replay v11. V12 is the narrow per-lane requalification repair.

- Historical all-direct v10 / `0x00020407` passed both PMA gates. Its first
  external launcher stopped before measurement because it expected the old
  active-state value. A later authorized asymmetric resume gave F1 a clean
  54-lane publication and clean stop, while F2 retained a `CAPTURE_DONE`
  cleanup-reason-`0x20` fault at sequence/ack 3, run 2. No retry followed.
  Later versions supersede its cleanup behavior. Preserve
  `docs/direct-all-v10-hardware-gate.md` and archived evidence; do not replay
  v10.

- Historical all-direct v9 / `0x00020406` passed both 56-lane PMA gates, then
  its single external attempt received all 54 fitted lanes clean at F1 while
  all 54 F2 lanes showed wrong-pattern error activity. Both later retained
  cleanup reason `0x20`. Its artifacts and evidence are frozen under
  `build/diagnostic_archive/direct-all-v9-0x00020406-external-failure/`; do
  not retry it. V10 repaired the concrete session-application protocol gap;
  v12 now supplies the completed scoped external gate.

- V6 direct-quad scoped gate PASSED: F1 N/q222 identity `0x00020400` and F2
  I/q233 identity `0x00020403`, physical order 60/61/62/63 ↔ 107/106/105/104.
  Final F1 bit/ELF hashes are `06501f6d69a84d80fb47521b8835ea542dab3b6edaca42c8defa742f51b83dcc` /
  `262bbdf17844694d124e345b0f71b599dd57800dbf93ecc8c8ea35bb25611568`;
  final F2 bit/DCP/ELF hashes are `5a7e5f3dabd7165baeb25ad920652bd9bfa017f741371ef1f1c82516cc37cfa9` /
  `067782afcae42d2e16c7ddf65761153717d761db864bfcc76c94a151c900a842` /
  `ea7d79aca4e5edde9f0cf3ccd45644e9ceb722a71706ba077af35d432cf7a52a`.
  Simulation, compressed builds, and independent routed audits pass. Final F2
  matches every non-metadata q233 primitive difference against golden IBERT.
  F1's preserved PMA run1 and fresh F2 PMA run1 passed; two overlapping
  bidirectional external PRBS31 windows (runs2/3) passed all eight lane records
  with zero errors/native losses. Both endpoints are healthy IDLE at seq/ack5,
  run3, sessions off, required clocks valid, no retained fault. Sequences1–5
  and runs1–3 are consumed: no replay/reload/reset/later request without a new
  reviewed gate. This is one-quad category coverage, not all-channel or long-
  BER qualification. Earlier F2 `0x00020401` no-lock and `0x00020402` lane105
  saturated-error failures are preserved, not retried. See
  `docs/v6-direct-quad-qualification.md`.

### Historical FireFly chronology

The status labels below were current when recorded. They do not supersede the
all-direct v12 state above.

- CURRENT SCOPED CLOSEOUT PASS: user explicitly excludes MCU latching work
  and channel requalification (channels previously qualified). Critiqued plan
  ran exactly one fresh10s all12PRBS31 smoke: F2seq24/run8, summary000C0C01,
  all12 zeroerrors/native losses. FinalF1seq17/run0 F2seq25/run8 healthyIDLE,
  sessionsoff, requiredclocksvalid, physicaldisablemasks0000. start-closeout
  consumed. No more hardware tests pending; no reset/reload/newbuild/soak.
  This proves clean reuse after fresh acquisition, not automatic in-run
  recovery. Native loss counters missed prior moduleCDRLOL; limitation stands.
  docs/firefly1-v5-closeout.md has critique, protocol and archived evidence.
  Earlier CURRENT/LATEST notes below are chronological history, not live state.

- LATEST alarm test COMPLETE: clean all12 baseline F2seq20/run6 PASS first.
  New TX02 interruption seq21/run7 captured module RX02 CDRLOL004 at1/5/9s;
  all other bits clear. LOS000 is inconclusive with competing polling.
  Restored original0000 after10.074281s; CDRLOL000 at5/20s postrestore.
  Lane9/X0Y13 alone saturated errorsFFFFFFFF,status5809; all11 neighbors
  clean; FPGA native losses all0 despite observed moduleCDRLOL. Summary
  010B0C01, equal1546849564400bits/lane, no retainedfault. Bothstops verified:
  F1seq15/run0 F2seq22/run7 healthyIDLE/sessionoff. No subsequent baseline,
  reset/reload/retry. start-alarm consumed; running note below historical.
  docs/firefly1-v5-alarm.md records evidence and clear-on-read limitations.

- CURRENT alarm follow-up RUNNING: user authorized LOS/CDR observation.
  start-alarm consumed, detachedworker110343 owns MCU. Fixed F1session14,
  F2session19 then cleanbaseline20/run6; only if clean proceeds RX21/run7
  60s with one10s TX02 disable/raw alarm reads/finallyrestore. Plannedstops
  F1seq15/F2seq22. Monitoring remains enabled; MCU source overwrites cached
  flags, so zero direct samples cannot exclude events. RX CDR0FFF, masks0.
  No concurrentUART/reset/replay. Use approved managed-oneway launcher
  status-alarm/results-alarm (log-only). docs/firefly1-v5-alarm.md has details.

- LATEST: reviewed TX02 interruption executed once, start-loss CONSUMED.
  Worker ended FAIL at heuristic RSSI mapping (<25% baseline) gate, not an
  acquisition/transport/restoration failure. RX02 went935.5→535.6/532.9→
  1037.7uW; only lane9/X0Y13 saturated errorsFFFFFFFF, status5809, zero
  native lock losses. Other11 lanes clean, full60s denominators; normal
  stop summary010B0C01/run5, no retained fault. TX original0000 restored
  after10.010531s; both sessions explicitly stopped. FinalF1seq13/run0,
  F2seq18/run5,C8=00100000. No recovery baseline/sweep/reset/reload/retry.
  Preserve failed marker/threshold; evidence supports lane-local disturbance
  but does not prove complete optical extinction or post-stimulus BER recovery.
  docs/firefly1-v5-loss.md and results-loss-1789604713240431.log have details.

- CURRENT (supersedes historical running/idle notes below): one-hour all12
  F1→F2 PRBS31 soak PASS, F2 sequence14/run4, summary000C0C01, zero errors
  and native lock losses; ~92.81e12 bits/lane. Both sessions stopped,
  final F1seq11/run0, F2seq15/run4, healthy IDLE. Evidence:
  firefly1-v5-managed-oneway-results-soak1h-1789604293332380.log.
  User authorized critique and execution of the revised next plan. Reviewed
  loss characterization uses the same approved managed-oneway launcher with
  deploy-loss/start-loss/status-loss/results-loss; new exclusive directory
  /tmp/firefly1-v5-loss-20260916. Fixed F1session12,F2session16, RX17/run5
  (60s), one F1 TX02 raw byte53bit2 disable10s during confirmed RUN, RSSI
  mapping, unconditional original-byte restoration, stopsF1seq13/F2seq18.
  No automatic baseline/sweep/reset/retry. Native integrity detector is off
  in v5; absence of retained fault does not disprove the optical interruption.
  Monitor detached worker logs only while active; serialize MCU access.
  See docs/firefly1-v5-loss.md. Preparation complete; start not yet issued.

- CURRENT ONE-HOUR SOAK RUNNING: user explicitly authorized3600000ms all12
  F1→F2PRBS31. Approved launcher start-soak1h consumed once. Detached Apollo
  workerPID108549 owns serializedMCU polling and automatic boundedcleanup.
  F1sessionseq10/run0;F2sessionseq13/run3 thenRXseq14 expectedrun4. Confirmed
  RUN C8=00120002,ack13,publishedrun3 at epoch1789596622.695. Both leases65min;
  planned successstopF1seq11/run0,F2seq15/run4. Do NOT program/reset/start
  another test or use concurrentUART diagnostics. Use only log-reading
  board_firefly1_v5_managed_oneway.py status-soak1h/results-soak1h to monitor.
  No final result yet. Details docs/firefly1-v5-soak1h.md. Never replaystart.

- CURRENT all12 follow-up: two distinct10s external F1→F2PRBS31 gates PASS
  with unchanged auditedv5 andmaskFFF, includinglane9/X0Y13. F2seq8/run2 and
  seq11/run3 eachreturned000C0C01; all12 zeroerrors/native losses,nonzero
  valid denominators,stable publication across stops. FinalF1seq/ack9run0,
  F2seq/ack12run3,bothhealthy IDLE,C8=00100000,PRBSsessionsoff,no faults,
  requiredclocksvalid. start-all12 and repeat-all12 are CONSUMED; no replay.
  Results/evidence: docs/firefly1-v5-all12.md. Do not continue excludinglane9
  solely on historicalgoldenfailure; it passed both currentmeasured gates.
  No reload/newbuild/drivechange. Longer soak only proposed,not launched;
  shortbaselines are not fullqualification. Preserve currentstate.

- CURRENT: reviewed two-v5 receive follow-up PASS. Both seq4 TX sessions,
 20s RSSI observation then one F2seq5/run1 PRBS31maskDFF/10s returned000B0B01.
 Eleven selected lanes have zero errors/native losses; lane9 unselected/zero.
 Both explicit stops succeeded: F1seq/ack5,run0;F2seq/ack6,run1;both healthy
 IDLE,C8=00100000,PRBS sessions off,no faults,required clocks valid. All12RSSI
 channels rose by the5.246s sample (about1023–1720uW), includingRx02, so the
 earlier1s hardgate was premature, not evidence of five dead links. No new
 build/swing change needed for this baseline. The approved fixed launcher
 board_firefly1_v5_managed_oneway.py start-receive is consumed; no replay.
 Evidence/results: docs/firefly1-v5-managed-oneway.md. Lane9 remains untested;
 do not claim full12lane qualification. Preserve current state.

- Latest two-v5 test STOPPED at RSSI pre-gate: both session seq1 commands
  succeeded, but Rx06/07/08/09/11 did not rise in the one-second snapshot.
  No F2 receive request issued. Both explicit stops seq3 succeeded; current
  both seq/ack3,run0,C8=00100000,healthy IDLE,TX off,no faults. New
  board_firefly1_v5_managed_oneway.py start is CONSUMED; no replay. Evidence
  and per-channel powers: docs/firefly1-v5-managed-oneway.md. Module disable
  masks remain0000. Suspects include v5 TXDIFFCTRL24 versus golden9 and RSSI
  settling/update latency (not characterized); do not call this a BER failure
  or five confirmed broken links. User asked to stop when tests fail.

- Current state superseding the golden notes below: user explicitly deferred
  the IBERT capture investigation and requested our bitstream on both ends.
  F1 then F2 were restored once to exact audited v5 (bit SHA a1014f7d...21f28e)
  with both PROGRAM_COMPLETE markers. Fresh status confirms FW/HW20304,
  seq/ack/run0, C8=00100000 (TX off), platform40, no retained faults, clocks
  100000/325000/FF1ref322260 kHz on both. Evidence: firefly1-v5-F1-program-
  1789592459984466.log, firefly1-v5-F2-program-1789592508855029.log and
  firefly1-v5-status-1789592558754291.log under build/diagnostic_archive.
  Direct F2_1 RSSI with F1 TX off is low (0–61.2uW); this is an off-reference,
  not proof of active data. Use python3 scripts/board_diagnostics.py
  firefly1-rssi (raw page1/206–229, verified descending channel map).
  Golden live-capture prerequisite is deferred by user; no new BER/session
  request has been issued. Old pma/external sentinels remain consumed; the
  prepared golden-F1 one-way launcher does not fit the new two-v5 topology.

- Latest manual hardware state: user loaded golden IBERT onto F1 and F2,
  superseding the v5 retained-state notes below. Wiring for this test is
  F1_1 TX to F2_1 RX, not bidirectional. Golden PRBS31 has an existing
  X0Y13 NO LINK, with datasheet Rx02 RSSI 61.2 uW. Direct single-channel
  RX-disable/RSSI sweeps establish reversed optical-to-GT ordering, supported
  by user's GUI observation X0Y15 down to X0Y4: GT Y=15-optical channel.
  Every disable mask was restored/read back as 0000. User subsequently
  confirmed all formerly working links recovered and no additional errors
  after resetting IBERT counters. The last direct Rx11 RSSI was 42.7 uW;
  no later RSSI measurement establishes its recovery, so do not confuse that
  historical sample with a continuing GUI link fault. F2 X0Y13 also passes
  user-tested near-end PMA PRBS31, but fails externally. Last per-lane GUI
  loopback settings were not captured; verify them before another external test.
  Working golden TX settings: PRBS31, TXDIFFCTRL=01001 (GUI 630 mV),
  pre/postcursor=0. F1 q121–123 all passed PMA. No timed/bit-counted golden
  external baseline was archived. See docs/firefly1-rx-channel-mapping.md.
  Use datasheet RX channel-disable bytes52–53, not cm_interface's erroneous
  symbolic RX_DISABLE=0x36. User's MCU RSSI labels match datasheet numbering;
  the earlier reversed-label claim was incorrect.
  The later one-way wiring correction invalidates the original bidirectional
  v5 test assumption; do not attribute F1 errors to F2 TX shutdown as an
  established physical cause. Preserve archived v5 evidence, not its now-
  superseded live state. Reviewed next work: preserve a timed golden reference,
  compare GT settings and simulate existing v5 with mask 0x0DFF (exclude lane9).
  User authorizes the remaining steps only after prerequisite GO: keep F1
  golden, program exact audited v5 onto F2 only, then use the new fixed one-way
  launcher (session mask FFF, receive mask DFF). Its review gate remains closed
  pending evidence; no new hardware test has run. Verify JTAG enumeration:
  the existing F2 programmer assumes target4 with a managed F1 peer.
  Defer TX fault-policy redesign and a new bitstream unless evidence requires
  them. Reduced-mask success would not qualify all twelve lanes.
  Preparation result: existing-v5 subset simulation PASS (two DFF runs,
  excluded lane9 unlocked; selected-lock and physical-reset faults still fail).
  New one-way launcher has 20 passing offline tests and remains review-held.
  Routed comparison confirms v5 TXDIFFCTRL=24, pre/post=0, polarity=0,
  RXLPMEN=1; golden dynamic ports cannot establish current GUI settings.
  Recorded hw_server lnx4189:3121 was unreachable during read-only capture;
  no golden settings/counter baseline was captured and neither FPGA changed.
  The board endpoint is TCP:apollo3010-1:2542 (XVC), accessed from lnx4189.
  Do NOT depend on the user's GUI hw_server at localhost3121; it exists only
  while their Vivado is running. XSDB programming/enumeration uses
  connect -xvc-url TCP:apollo3010-1:2542 directly. Vivado IBERT requires an
  hw_server bridge even for XVC: python3 scripts/board_golden_xvc.py capture
  owns a temporary private bridge on lnx4189 localhost43121, runs the standard
  Vivado helper, and explicitly opens XVC via open_hw_target -xvc_url.
  It terminates only its own bridge, holds the programming lock, refuses an
  occupied private port, and never programs/resets/commits IBERT controls.
  First independent bridge startup succeeded, but open_hw_target timed out
  opening apollo3010-1:2542 before target discovery. Log:
  build/logs/capture_firefly1_golden_readonly-20260916T204924Z.log.
  Initial cleanup stopped only the shell wrapper, leaving hw_server/loader
  PIDs4139544/4139512 on43121. A later retry detected this, verified their
  identity, and terminated only those two leftovers. The launcher now owns
  a separate process group and terminates that group, not only the wrapper.
  Neither FPGA changed. A competing GUI XVC
  connection is possible, not proven. Do not disconnect the user's GUI or
  claim a golden baseline from bridge startup alone.
  After user closed GUI XVC, direct board_jtag_status.py succeeded: F1 is
  target1 with Legacy Debug Hub2; F2 is target3 with Legacy Debug Hub4.
  The old F2 target4 programmer guard is NOT valid with both golden images.
  Vivado hostname-form XVC timed out. Numeric IPv4 (resolved on lnx4189 with
  getent ahostsv4, currently192.168.21.162) opens the XVC target but reports
  No devices detected. This persisted after user cleared another process;
  logs20260916T205726Z and20260916T205814Z. Direct XSDB enumeration succeeded,
  so do not equate this Vivado discovery failure with board power loss.
  Capture remains NO-GO; neither FPGA was programmed/reset. Bridge cleanup
  now waits for port release and logs XVC_BRIDGE_PORT_RELEASED (verified).
  Port preflight uses SO_REUSEADDR to ignore TIME_WAIT but rejects listeners.
  Final post-clear board_jtag_status.py again found targets1/3. Its output
  explicitly showed XSDB automatically starting hw_server on localhost3121:
  connect -xvc-url is the direct user-facing API, NOT proof of a server-free
  implementation. That bootstrap is independent of a GUI; account for its
  server/connection lifetime when diagnosing competing XVC clients.
  Datasheet audit report: docs/cm-interface-datasheet-audit.md; library fixes
  have not been applied. Actual source is under
  /nfs/cms/tracktrigger/wittich/int_test/cm_interface, PDFs under sibling
  datasheets (requested docs directory was absent).

- FireFly-1 v5 (`0x00020304`) implements default-off independent bounded
  PRBS31 TX sessions on all twelve lanes, with separate receive requests.
  Session commands consume mailbox sequences but not measurement run IDs.
  C8 bits 17–20 expose active/expired/rejected/capability. Historical modes
  remain unchanged with ENABLE_TX_SESSION=0; v5 PMA requires session off.
  Full 13-test regression and new dual-endpoint session/fault tests pass.
  Clean top-level synthesis with completed v4 IP reuse and hash-verified v4
  routed-reference incremental implementation and independent audit PASS at
  WNS/WHS +0.372/+0.003 ns, zero routing/DRC errors. Build script
  `build_firefly1_loopback_v5_bitstream.tcl` preserves synth/routed checkpoints.
  Never reuse automatic incremental synthesis for these changes.
  V5 also explicitly broadcasts each scalar quad reset to all four lanes;
  historical disabled-session targets retain their prior mapping. Corrected
  clean synthesis and the group-wrapper reset wiring test pass. Current
  build log is `build/logs/rebuild_firefly1_v5_reset_fanout-20260916T172040Z.log`.
  Approved fixed helper `python3 scripts/board_firefly1_v5.py
  deploy|status|pma|external|optics-api|optics` is deployed. Both devices were
  programmed once through separately approved hash-pinned v5/v5_f2 choices.
  Bit SHA256 a1014f7d2451045ae6fbae66f0d2d1faef60d74c4a74190584be20b6a821f28e;
  ELF SHA256 37972efc9f7cd65ff2bd2569bd6b776bec0263d2ad00a32e9c3de2975ab06528.
  PMA sequence/run 1 passed both sites. External sequence 3/run 2 FAILED:
  F1 summary 0x04080c01 (errors 47/96/57/19 on lanes 1/3/4/6, no native
  lock losses); F2 0x0c000c04, retained 10-second LOCK_WAIT timeout despite
  healthy clocks/reset qualifiers. F2 records are synthetic failures, not
  measured native lock losses. No sequence 4, reset, reload or retry.
  F1 stopped TX with sequence 5, run remains 2, C8=0x00100000; F2 fault
  stopped TX automatically, remains sequence 3/run 2, C8=0x00150000.
  Both pma/external helpers are consumed; never clear sentinels/replay them.
  Session termination still uses aggregate platform fault including RX PRBS
  faults: possible cross-endpoint error contamination, not proved causation.
  The installed tf optics preset renumbers a sparse list; use only the
  reviewed physical map in the v5 optics helper, not its registry labels.
  V5 is NOT qualified. See `docs/firefly1-v5-tx-session.md` for evidence and
  the next proposed diagnostic; obtain direction before new hardware gates.

- F2 v4 PMA sequence/run 1 now PASSES: summary 0x000c0c01, twelve equal
  257,808,259,520-bit / 3,222,603,244-cycle records, zero errors/native lock
  losses, final healthy IDLE/no first fault. F1 unchanged at passed run 1.
  Both clocks rechecked healthy. F2 gate is consumed; no retry/reset/reload.
  Approved fixed helper: `python3 scripts/board_firefly1_v4_f2.py
  deploy|start|status|results|diagnostics`; do not invoke start again.
  Read-only dual check `board_firefly1_v4_inspect.py pma-complete` expects
  both run 1; earlier verify stage intentionally expects F2 run 0.
  Actual-engine simulation reproduces the bidirectional stop race: staggered
  acquisition plus equal durations lets one PRBS transmitter stop before its
  peer finishes measuring. Do not run optical baselines with the existing
  PMA launchers or claim simultaneous host submission fixes this. A bounded
  TX-hold/new-version design or validated alternative is needed first.
  Evidence and qualification limits: `docs/firefly1-v4-f2-bringup.md`.

- F2 was explicitly programmed once with the same final v4 bit on 2026-09-16
  using `python3 scripts/board_program.py firefly1_loopback_v4_f2` (separately
  approved fixed choice). JTAG target 4, PROGRAM_F2_COMPLETE, FW/HW 0x00020303,
  fresh IDLE at sequence/run 0. F1 remained unchanged at successful run 1.
  Both clock monitors are valid 0x434da501: 100.000/325.000 MHz, FF1 REFCLK
  322.260 MHz. F2 has not run PMA or optical qualification yet. User confirms
  all 12-channel Fireflies are connected F1-to-F2 quad-to-quad, with matching
  reference clocks. New approved read-only helper:
  `python3 scripts/board_firefly1_v4_inspect.py preflight|verify`.
  It reads both sites sequentially, preserves logs, and performs no writes.
  Its verification expects current F1 run 1 / F2 run 0; revise explicitly for
  later authorized gates. Programming permission is not permission to reload.
  See `docs/firefly1-v4-f2-bringup.md`.

- FireFly-1 v4 (`0x00020303`) now PASSES its fixed ten-second twelve-lane
  PMA-loopback gate on the clean-synthesized repair. F1 is healthy IDLE after
  sequence/run 1, summary `0x000c0c01`, all twelve nonzero records clean with
  zero native lock losses, no retained fault after bounded cleanup observation.
  Final bit SHA `cc450c14786a2a00fca7ad844d47be7e5438d160590b463f8f2bd85ffc17443a`;
  ELF `abe06ba6f83ca94b0748076092c9bd3a2763d338987edfa14eb1e73d64956ab2`.
  Full simulation, compressed build and strengthened routed audit pass at
  +0.206/+0.010 ns. All 15 cleanup acknowledgement registers are present.
  F1 28.765625 C, AVTT 1.2001953125 V; required clocks healthy.
  Results: `firefly1-v4-results-1789576567.log`. Do not retry/reload the
  completed gate automatically. This is not external or full qualification.
  See `docs/firefly1-v4-repair.md` for prior failures and exact evidence.

- FireFly-1 v3 (`0x00020302`) built and passed its limited routed audit, then
  consumed sequence/run 1 with platform-failure summary `0x0c000c04` and
  reason `0x80` (PRBS controller fault). Detailed FE words were tied to zero;
  they do NOT establish reset-done failure. The `0x2800` lane records and
  lock-loss value 1 are synthetic failures, not measurements. The polarity
  hypothesis is unconfirmed. Do not describe enabling RXPOLARITY as a proven
  startup cause. The programmed mailbox identity was verified; the programmer
  output showed PROGRAM_F1, not PROGRAM_F1_COMPLETE.
- Current v4 (`0x00020303`) removes the speculative polarity change and P/N
  swap. It fixes missing staged-acquisition parameter forwarding to all three
  native PRBS controllers and exposes retained first-fault FE diagnostics.
  The user explicitly authorized continued fixes, simulation/build/audit,
  and hardware testing, including evidence-preserving retries, on 2026-09-16.
  Approved fixed helpers are `board_program.py firefly1_loopback_v4` and
  `board_firefly1_loopback_v4.py deploy|start|status|results|diagnostics`.
  Pin completed artifacts before programming and keep each request unique.
  The first v4 artifact was rejected during methodology review: importing
  board_pins.xdc alone omitted GT and monitor clock declarations. Restored
  declarations recover six active user clocks; `apply_firefly1_descriptor_cdc.tcl`
  keeps all 48 descriptor endpoints timed at 3 ns with three bus-skew bounds.
  Require no TIMING-17/TIMING-26 findings. `resume_firefly1_v4_clock_repair.tcl`
  preserves the rejected bit/DCP and reimplements from valid synthesis.
  Its canonical checkpoint is `build/gt_test_firefly1_loopback_v4/gt_test_firefly1_loopback_v4_routed.dcp`;
  do not audit the old impl_1 routed checkpoint after this repair.
  The clock-repaired first hardware revision (bit SHA `fe21094d2a204fade6b2eb957c47bbd074c2a6f917ec59a4c34fa5ca3cb1bfc4`)
  passed routed audit at +0.244/+0.010 ns and programmed with a completion
  marker, but sequence 1 failed: summary `0x05070c01`, saturated lanes
  0/1/5/6/9 and post-publication RX reset-done fault `0x20`.
  `firefly1-v4-results-1789573694.log` contains retained FE diagnostics.
  Investigation reproduced a controller bug: PMA loopback dropped in states
  20/21/26. The completed v4 development repair retained firmware/ABI while
  archiving the exact previous bit/DCP/audit under
  `build/diagnostic_archive/firefly1-v4-first-hardware-revision/`.
  Re-pin only the newly audited bit; never treat an earlier consumed sequence
  as a new request without the explicitly authorized replacement programming.
  The next revision (`d54a0d71aa0f53ae3c0089875655b7951814535e78463ab35c93452b2b99240d`)
  passed simulation/build/audit and measured twelve identical clean records
  (257,808,261,600 bits, zero errors/losses), summary `0x000c0c01`, but still
  failed final healthy IDLE with retained post-cleanup reason `0x20`.
  Evidence: `firefly1-v4-results-1789574820.log`. Simulation proves a fixed
  delay cannot replace reset acknowledgement; incremental omissions prevent
  inferring that the intended guard was present in that hardware revision.
  An explicit low-then-high
  Wizard/per-lane acknowledgement repair now passes after clean synthesis; prior bit/DCP/audit
  are retained under `firefly1-v4-clean-measurement-revision/`. See
  `docs/firefly1-v4-repair.md`; the programmer pins only the final passing hash above.

- FireFly-1 functional v2 / `0x00020301` completed its only authorized
  10-second sequence/run-ID-1 PMA-loopback gate but failed normally with
  response/summary `0x05070C01`: lanes 0, 1, 2, 5, and 6 saturated errors;
  lanes 3, 4, and 7--11 were clean with zero lock losses. The retained final
  platform fault is reason `0x20` (RX reset-done absent after publication),
  separate from the measurement result. The generated q121--q123 Wizards have
  RX/TX polarity controls disabled, a leading but unconfirmed explanation for
  the lane-specific error split. Evidence is under
  `build/diagnostic_archive/firefly1-v2-*`. Do not reload, reset, or retry;
  never program invalid FireFly-1 v1 (`0x00020300`).

- Full v15 / `0x0002000F` passed its initial hardware gate after the user
  manually loaded its exact audited bitstream: fresh fixed external
  sequence/run IDs 1 and 2 each returned `0x00040401`; all four lanes had equal
  nonzero records, zero errors, and zero native lock losses. F1 is healthy
  IDLE at ID 2. Final MCU F1 temperature was 53.5625 C, AVTT 1.20117 V, and
  required monitor clocks were valid. This is not full qualification and does
  not test optical LOS, native CDR loss, or shared-RXUSRCLK2 loss. Both
  sequences are consumed: do not retry/reset/reload them silently. The
  automatic XSDB/XVC programming helper still fails before its completion
  marker; this is distinct from the manually loaded image's successful
  hardware gate. See `docs/v15-programming-interface-failure.md`.

- Full v15 fixed 12-hour external PRBS31 sequence/run ID 3 passed after the
  two short baselines: normal `0x00040401`, four equal
  1,113,730,550,445,760-bit / 13,921,631,880,572-cycle records, zero errors and
  native lock losses, final healthy IDLE, F1 54.4375 C, AVTT 1.203125 V, and
  valid clocks. Do not retry/reset/reload or submit a new v15 request without
  explicit direction. See `docs/v15-programming-interface-failure.md`.

- Full v15 / `0x0002000F` completed simulation, compressed build, and
  independent routed audit. Its bitstream SHA-256 is
  `789c668c7bcf2bf30ac9046b6a6546819c64e4f64c8d81955431245a8a14b7f3`; its
  firmware SHA-256 is
  `b62b160c483aac2a7d323d2e1307977bdb39483bbc117f9e3f09c6a269006391`.
  The designated deployment helper verified its test bundle and the designated
  programmer verified these artifacts and selected F1 through
  `TCP:apollo3010-1:2542`, but `fpga -file` did not emit its completion marker.
  F1 mailbox and clock reads immediately returned `ADDR_ACK_ERROR`, and the
  read-only JTAG helper did not return a target list. No v15 request was
  issued. MCU rails/regulator status were healthy; module `FF/FF` alarms were
  pre-existing. Preserve this context and do not retry programming, reset, or
  start a test without explicit direction after XVC/JTAG and F1 generic
  interface recovery. See `docs/v15-programming-interface-failure.md`.

- Full v14 / `0x0002000E` is a separately versioned, unqualified diagnostic of
  full v13. It changes only `EXTERNAL_STARTUP_QUAD_RESTART=0`; retain staged
  acquisition, `EXTERNAL_QUAD_RECOVERY=1`, no external RX recovery,
  post-capture quad restart, the integrity detector, and physical-only
  heartbeat. Matching firmware, compressed build, and independent routed
  audit pass: WNS/WHS +0.222/+0.009 ns, zero routing/DRC errors, four met
  bus-skew constraints, all 16 descriptor bounds (worst +2.155 ns), full
  52+4+56 ownership, golden managed RX properties, and profile/runtime
  structure. Bitstream SHA-256 is
  `02633d63dce3e75b4e80de537341b89d7e6aa964ee6b710b8e3432e2ad665931`; firmware
  SHA-256 is `d8eecdb9b84c9d0395e6a0a06f5f84d0add22b6622e2dc6566e3f87afa2a41c9`.
  Do not program a substitute artifact. Following a power cycle, F1 was
  programmed once through XVC `TCP:apollo3010-1:2542` as target 1 (F2 is
  target 5). Fresh external sequence/run IDs 1 and 2 passed: normal
  `0x00040401`, four equal 1,546,848,197,680-bit / 19,335,602,471-cycle and
  1,546,848,072,800-bit / 19,335,600,910-cycle records, respectively, with
  zero errors and native lock losses, no retained fault, and final healthy
  IDLE at ID 2. This
  supports the narrow startup-restart hypothesis only; it is not qualification.
  Both sequences are consumed: do not retry/reset/reload them silently. AVTT
  status was clear after both runs (1.20435 V, 24.21875 A, 42.6875 C; then
  1.20093 V, 24.34375 A, 43.25 C). The serialized MCU ADC helper captured F1/
  F2 temperatures at 54.59375/27.71875 C. The separate FPGA-SysMon helper is
  stale at `lnx4189:3121` and requires XVC conversion only if it is needed.
  See `docs/v14-no-startup-restart-diagnostic.md`.

- Full v13 / `0x0002000D` had two independently programmed fresh external
  `0x04000404` failures before RUN. The second repeat was explicitly used to
  rule out a transient and is not a retry to be repeated. Routed comparison
  with v275 found matching managed GT configuration, placement, golden RX
  properties, and no managed-to-full-IBERT net. The v14 experiment tests only
  the remaining planned-startup-restart hypothesis.

- Isolated v275 / 2.5.25 is `0x00020119`, the initial qualification candidate.
  It freezes v272's runtime-integrity detector and v273's planned startup
  restart while explicitly disabling v274's heartbeat test hook. Full
  simulation, compressed implementation, and independent audit pass at
  WNS/WHS +0.009/+0.001 ns with zero routing/DRC errors. All structural checks
  pass, including physical-only heartbeat fan-in; existing v273
  CDC/methodology caveats and absent bus-skew constraints remain. F1 was
  programmed once and passed two unique consecutive 10-second clean baselines
  without reload/retry, acquisition recovery, errors, lock losses, integrity
  events, or trace overflow. The fixed unique sequence-3 uninterrupted 12-hour
  external soak then passed without reload/retry: normal summary `0x00040401`,
  matching request/response/run ID 3, and four equal 1,113,731,693,556,560-bit
  records with zero errors, native lock losses, or saturation. Final FPGA
  temperature was 24.5 C, raw/unvalidated F1 AVTT current -0.6494140625 A,
  and required clocks were healthy. F1 remains v275 healthy IDLE at run ID 3.
  Sequence 3 and its non-overwriting `start`/`results` operations are consumed;
  do not invoke them again, reload, reset, or retry. See
  `docs/v275-qualification-candidate.md`.

- Isolated v274 / 2.5.24 is `0x00020118`. It preserves v273 behavior and
  enables a default-off controlled heartbeat-monitor test hook. The hook gates
  only the divided heartbeat presented to the runtime monitor; it does not stop
  physical RXUSRCLK2 or establish optical/native clock-loss behavior. Full
  simulation, compressed implementation, and independent routed audit pass at
  WNS/WHS +0.009/+0.001 ns with zero routing/DRC errors. The explicit routed
  fan-in proof passes. Existing CDC/methodology caveats remain; the intentional
  pre-synchronizer gate changes one CDC-3 to CDC-10, and no bus-skew constraints
  exist. One unique clean 10-second sequence/run-ID-1 baseline passed. The
  fixed sequence/run-ID-2 watcher then produced one retained clock-only event
  at stage 27 after about 119 ms and restored its control with the second and
  final write. Physical managed RX clock remained 322.260 MHz, the quad stayed
  READY, retained data lanes were clear, and lane 15 recorded only the expected
  two-cycle toggle-edge pulse. F1 retains the v274 sequence/run-ID-2 platform
  fault; no retry/later request/reset/reload. This validates controlled monitor
  injection, not physical RXUSRCLK2 or optical/native loss. See
  `docs/v274-heartbeat-test.md`.

- Isolated v273 / 2.5.23 is `0x00020117`. It preserves v272 runtime integrity
  and enables a default-off, v273-only planned full-quad restart after external
  controls settle. Full simulation, compressed incremental build, and
  independent audit pass: WNS/WHS +0.009/+0.001 ns, zero routing/DRC errors,
  all 16 descriptor bounds pass (worst +1.568 ns), and runtime/profile
  structural checks pass. Two consecutive unique 10-second F1 baselines passed
  without reload/retry: each recorded planned cause 4 plus cleanup cause 3,
  no reactive cause-2 recovery, four clean profiles, zero native lock losses,
  and no trace overflow. A sequence-3 pulse launcher race was refused before
  any stimulus write and preserved as a clean run. Sequence 4 then captured
  exactly two lane-12 error cycles without an integrity event. Sequence 5's
  250.304-ms F1_5 channel-0 disable retained one lane-12 integrity event, no
  shared-clock cause, and fault stage 27. All `RXPRBSLOCKED` inputs were high
  at first fault, then fell when the retained fault disabled the checker; the
  quad stayed READY and was not reset. Final `0x280c`–`0x280f` records are
  synthetic platform-failure records, not measured lock-loss counters. This
  resolves the narrow
  startup test and passes the lane-data detector gate but is not full
  qualification. At the end of v273, F1 retained the sequence/run-ID-5
  platform fault; the later v274 gate above supersedes that state. See
  `docs/v273-planned-startup-restart.md`.

- V272 lane-data runtime-integrity hardware testing passed. F1 was programmed
  once with the exact audited `0x00020116` image. Sequences 1 and 2 were clean
  10-second measurements but each needed one bounded acquisition recovery, so
  neither is a no-recovery baseline. With explicit continuation, sequence 3's
  watched two-cycle lane-12 pulse did not trip the detector. Sequence 4's
  0.250289-s F1_5 channel-0 disable retained one lane-12 integrity event,
  fault stage 27, and response/summary `0x04000404`; lanes 13–15, the shared-
  clock cause, and native lock-loss counts stayed clear. Byte 86 was restored.
  This tests sustained PRBS corruption, not optical LOS/CDR loss; missing
  RXUSRCLK2 remains untested. V272 is not fully qualification-ready because of
  repeatable acquisition recovery. One later authorized same-image reload and
  fresh sequence/run-ID-1 request reproduced it: all lock/reset/clock
  qualifiers were healthy, all four lanes were observed error-active, and the
  aggregate had zero clean cycles for 100 ms before full-quad recovery. The
  measurement was clean and no retry followed. F1 was then v272 healthy IDLE
  at request/response/run ID 1. The subsequent explicit v273 experiment
  resolved the startup-policy decision without changing v272.
  See `docs/v272-hardware-gate.md` and
  `docs/v272-startup-recovery-investigation.md`.

- V271 sequence 5 hardware threshold characterization disabled F1_5 channel 0
  for 250.280 ms and produced one uninterrupted lane-12 error-active run of
  3,133,090,464 RX cycles (~9.72 s), with adjacent lanes clean and no native
  lock losses. Byte 86 was restored; clean sequence 6 passed afterward. F1 was
  v271 healthy IDLE at request/response/run ID 6 before the authorized v272
  programming. This accepts the 100-ms
  consecutive-error policy for initial v272 but does not test missing shared
  RXUSRCLK2. Required clocks, F1_5 temperature (38 C), and regulator status
  were healthy; FPGA SysMon temperature was not captured because that helper
  did not complete. Serialize all MCU-UART diagnostics: a parallel preflight
  caused two read failures but no writes, and the repeated serialized preflight
  passed. See `docs/v271-firefly-threshold-characterization.md`.

- Isolated v272 / 2.5.22 is `0x00020116`. Its complete simulation, matching
  firmware, compressed incremental build, and independent routed audit pass:
  WNS/WHS +0.018/+0.001 ns, zero routing/DRC errors, all 16 descriptor bounds
  pass (worst +1.568 ns), and all ten detector synchronizer registers have
  `ASYNC_REG`. It qualifies 100 ms of consecutive PRBS-error
  activity and 100 ms without the shared RXUSRCLK2 heartbeat only during the
  registered measurement window, then uses retained fault stage 27 and the
  existing platform-fault publication path. Selector FD capability bit 1 and
  words 6–7 expose its event count/state when enabled. Do not call either
  observation optical LOS or native CDR loss. The policy and full simulation
  status are in `docs/runtime-integrity-candidate-design.md` and
  `docs/v272-build.md`. Existing unrelated CDC/methodology caveats and absent
  isolated-target bus-skew constraints remain. The subsequent hardware gate
  and current retained F1 state are recorded above.

- Isolated 2.5.21 / v271 is `0x00020115`. It implements the profile
  measurement-source and run-epoch repair. Full simulation, compressed build,
  and independent routed audit pass: WNS/WHS +0.018/+0.001 ns, zero routing/
  DRC errors, all 16 descriptor bounds pass (worst +1.568 ns), and all eight
  profile measurement/epoch first stages have direct registered sources with
  no combinational fan-in. Existing non-profile CDC/methodology caveats and
  the absence of bus-skew constraints remain. V271 is diagnostic, not a
  qualification candidate. F1 was programmed with the exact audited image and
  passed two unique consecutive 10-second four-lane external baselines without
  reload/retry. Both toggle phases produced four equal nonzero profiles, zero
  errors/losses, one cleanup, and 93/104 trace events without overflow.
  Sequence 3 then captured a two-cycle lane-12-only pulse in a full nonzero
  profile; the entire publication stayed unchanged for about 158 seconds in
  IDLE. Clean sequence 4 replaced it with four equal zero-error profiles. At
  that gate F1 was v271 healthy IDLE at sequence/run ID 4; threshold-
  characterization sequences 5 and 6 above supersede that state. No retry or
  reload occurred. See `docs/v271-build.md`,
  `docs/v271-hardware-baselines.md`, and `docs/v271-profile-hardware-gate.md`.

- Shared reset has now been reported complete; post-reset snapshots are in
  `build/diagnostic_archive/after-shared-reset-*`. No fourth run or FPGA reload.
  User reports CDR_LOL=FF, LOS=00, whereas agent's raw x4 bytes 3/5 read FF/FF.
  Reconcile module/address/display before treating byte 3 as confirmed LOS
  or proceeding with baseline 4. Prior pending-reset note below is historical.

- Shared FireFly reset pending (2026-09-12): user will toggle the reset common
  to all F1 Fireflies after pre-reset capture. Agent has not reset anything.
  Complete v270/run-3 capture and all ten F1 physical endpoints are saved in
  `build/diagnostic_archive/before-shared-reset-*`. Both x4 modules have FF/FF
  alarms, outputs enabled, page 0. Await confirmation, compare fresh post-reset
  controls/alarms and FPGA state, then clean baseline; no automatic FPGA reload.
  User confirms FF-page reads are fresh; MCU source is not a prerequisite.

- Resume point (2026-09-12): F1 runs isolated v270 / 2.5.20, FW/HW
  `0x00020114`, healthy IDLE after request/response/run ID 3. One lane-12
  pulse request passed characterization: two RXPRBSERR-active cycles only on
  lane 12, zero lock losses, one cleanup restart, 103 trace events/no overflow.
  Native profile longest/span both 2; trace error_seen was already `0xF` at
  measurement start, so do not use it to time the pulse. Two preceding 10-second
  four-lane external baselines passed without reload, zero errors/losses,
  one cleanup restart each, 103/108 trace events without overflow. Both
  handshake phases exercised. No optical disable or fourth request. F1 26.0 C
  pre/post pulse, power status clear. Optical tests paused: resolve FireFly
  `FF/FF` (individual/block reads agree, page 0, part B0425040011201) before
  stimuli. Next sequence would be 4 after 3 / run ID 4 if unchanged.
  See `docs/v270-pulse-characterization.md` and `docs/v270-hardware-baselines.md`.
  V270 remains diagnostic, not qualification.

- Historical isolated v269 / 2.5.19:
  FW/HW `0x00020113`, IDLE after failed baseline sequence/run ID 1. Descriptor
  mask was `0xF000` at MCU and AXI, but lane 12 was unselected; result
  `0x00030301`. Trace retained 127 events without overflow, with acquisition
  restart plus cleanup. No second run or fault stimulus was issued.
  A one-cycle descriptor CDC skew reproduces stale selection in simulation;
  source-stage settling/accepted-mode and publication-mask repairs now pass
  regression (see `docs/descriptor-transfer-repair.md`). New isolated v270 /
  2.5.20 (`0x00020114`) build and independent audit pass with effective
  3.000-ns bounds on all 16 descriptor endpoints (worst slack +1.568 ns).
  It is compressed, WNS +0.325 / WHS +0.001 ns, zero routing/DRC errors;
  existing non-descriptor CDC caveats remain. See
  `docs/v270-build.md` for build hashes and limitations.
  Extra RX stages are a bounded budget, not arbitrary-skew immunity. Resolve
  FireFly alarm `FF/FF` readback before optical stimuli. See
  `docs/v269-hardware-baseline.md` and the top of `docs/memory/build-state.md`.
  The v269 incremental build/audit passed; this is not hardware qualification.

- Recovery plan items 1–4: the pre-change v2.5.17 diagnostic source/products are
  archived under `build/diagnostic_archive/`; hashes and evidence limits are in
  `docs/recovery-items1-4.md`. Current shared RTL differs from that archive.
  Recovery must preserve lane protocol phases regardless of running/selection;
  only management reset clears them. Selector 0xFD captures retained restart
  records; 0xFE is unchanged. These changes have no qualification bitstream yet.

- Keep golden `top`, historical Milestone 2.5, isolated diagnostic targets,
  and full Milestone 3 separate. Never relabel historical artifacts or mix an
  ELF, bitstream, audit, or operator script with another target/version.
- Validated historical Milestone 2.5 is `0x00020004`.
- Isolated 2.5.1/2.5.2/2.5.3 are respectively `0x00020101`, `0x00020102`, and
  `0x00020103`. Use only their matching `251`/`252`/`253` build, audit, and
  acceptance files. The 2.5.2 behavior and 2.5.3 diagnostic lifetime passed
  F1 hardware acceptance.
- Isolated 2.5.4 is `0x00020104`. It counts RXPRBSERR-active cycles and maps
  managed RXUSRCLK2 to r38 only for signal-loss characterization. Its build
  and routed audit pass; its first external request failed acquisition before
  the FireFly stimulus and was preserved without retry.
- Isolated 2.5.5/2.5.6 are `0x00020105`/`0x00020106`. They test one bounded
  external RX recovery; 2.5.6 also requalifies RX status after capture. One
  2.5.6 FireFly-loss run passed and established sustained lane-local PRBS
  activity with an unchanged RX clock, but the next unique request failed
  acquisition after its one recovery attempt. Do not promote this recovery.
  F1 was restored to golden and all four Quad-124 links checked clean.
- Current full Milestone 3 is v12, firmware/hardware `0x0002000C`. It preserves
  v11 acquisition behavior and qualifies runtime lane lock with both native
  `RXPRBSLOCKED` and `RXCDRLOCK`. Its clean simulations, build, and routed
  audit pass. A PMA smoke and a following 60-second external smoke passed on
  F1, but separate fresh/restart attempts produced preserved all-lane
  `LOCK_WAIT` acquisition faults, and one post-reload PMA attempt also failed.
  After a later explicit reload, fresh PMA and external gates passed, but the
  intended FireFly test proved native FPGA `RXCDRLOCK` also remained asserted
  through module-confirmed channel-0 LOS/CDR LOL. Lane 12 saturated errors but
  recorded zero lock losses. V12 is not hardware-qualified. V11
  (`0x0002000B`) remains the completed long-soak historical record but is not
  fully qualified because it likewise missed module-confirmed loss.

## Vivado environment

Vivado is not on the default batch-shell path. Use the Cornell 2023.2 tools
and license in the same shell:

```sh
export XILINXD_LICENSE_FILE=2100@lnxlm.classe.cornell.edu
source /nfs/opt/Xilinx/Vivado/2023.2/settings64.sh
```

Agent sandbox DNS may not reach the license server, so licensed commands may
require the approved external environment. If `lmutil` reports `No such file
or directory`, launch its unwrapped binary through
`/lib64/ld-linux-x86-64.so.2` and query
`lmstat -a -c 2100@lnxlm.classe.cornell.edu` before retrying Vivado.

### Required Vivado helper

For every Vivado synthesis, implementation, bitstream, audit, IP-generation,
or Tcl simulation task, invoke the project helper rather than calling Vivado
or sourcing settings directly:

```sh
bash skills/vivado-build-project/scripts/run-vivado.sh scripts/<task>.tcl
```

The helper supplies the approved Cornell 2023.2 environment, license, and
execution form. Tcl files are inputs to that helper, not a reason to bypass
it. Use a designated versioned firmware/programming/diagnostic helper where
one exists; do not substitute ad-hoc shell wrappers or raw `vivado`/`xsdb`
commands. Raw executable forms below are retained only for legacy permission
documentation and exceptional tool diagnosis.

### Codex build-session note

For FireFly v4 controller repairs, disable `AUTO_INCREMENTAL_CHECKPOINT` and
clear `INCREMENTAL_CHECKPOINT` on synth_1. On 2026-09-16 the automatic
incremental result lacked all new cleanup acknowledgement registers; the
same source passed the structural gate after clean synthesis. Do not infer
source inclusion from timing PASS or a changed-module log alone. Require
three Wizard and twelve lane reset-acknowledgement registers in routed audit.
The rejected incremental bit/DCP remain archived and were never programmed.

For normal Vivado work, invoke only the required helper; it sources the Cornell
2023.2 settings when needed, exports `XILINXD_LICENSE_FILE=2100@lnxlm.classe.cornell.edu`
when unset, and writes timestamped journals/logs in `build/logs/`. Do not
pre-source Vivado settings or manually export the license for this path.

When invoking the helper from Codex, run the exact command below in an attached
PTY/terminal session, allow the approved external execution environment when
needed, and poll that same session until it exits:

```sh
bash skills/vivado-build-project/scripts/run-vivado.sh scripts/<task>.tcl
```

Do not use a detached `nohup`/background launcher, and do not use a short-lived
non-PTY command session: this environment can clean up the child before Vivado
starts, leaving queued runs without a worker or launcher log. This is a
process-lifetime constraint, not a reason to replace the helper or invoke
Vivado directly.

Read local logs with ordinary sandboxed `tail`/`rg`; do not request external
execution for each log read. Save and poll the helper's returned session ID.
Before restarting after an interruption, inspect the existing log/session so
two builds never use the same generated project directory concurrently.
The helper approval covers simulation, IP, build and audit Tcl entry points.
New fixed hardware launchers need their own scoped approval; request it for
the reviewed launcher's operations before a long build when unattended work
is requested. Never change permission-rule files to bypass approval.

## Approved command forms

Execution permission is not authorization to program, reset, stimulate, or
otherwise change hardware. The task must separately authorize those actions,
and the evidence-preservation and serialized-MCU rules above still apply.
The active rules are under `/home/wittich/.codex/rules/`; this section records
the project-specific forms so agents do not defeat prefix matching with shell
wrappers.

- Vivado simulation/build tools are allowed as direct commands `vivado`,
  `xsim`, `xelab`, `xvlog`, and `xvhdl`, or by their absolute paths under
  `/nfs/opt/Xilinx/Vivado/2023.2/bin/`. For licensed batch work, prefer the
  exact prefix-matched form. Prefer the Required Vivado helper above for all
  normal project work:

  ```sh
  env XILINXD_LICENSE_FILE=2100@lnxlm.classe.cornell.edu PATH=/nfs/opt/Xilinx/Vivado/2023.2/gnu/microblaze/lin/bin:/nfs/opt/Xilinx/Vivado/2023.2/bin:/usr/bin:/bin /nfs/opt/Xilinx/Vivado/2023.2/bin/vivado -mode batch -source scripts/<script>.tcl
  ```

  A second allowed PATH form omits the MicroBlaze directory for jobs that do
  not build firmware. Do not prepend `export`/`source`, pipe the command, or
  place it inside `bash -lc`; that changes the command prefix and can trigger a
  new approval. The absolute Vivado command also works directly for simulations
  that do not need a license checkout.

- The absolute Cornell XSDB executable
  `/nfs/opt/Xilinx/Vivado/2023.2/bin/xsdb` is permitted for direct local
  invocation. That rule does not cover an `ssh` wrapper when XSDB must execute
  on `lnx4189`; remote XSDB actions need their own fixed launcher and narrow
  approval. Treat every XSDB use as potentially hardware-changing; use only
  reviewed Tcl and explicit task authorization.

- The v272 sequence-3 one-shot pulse uses only
  `python3 scripts/board_pulse.py v272-run3`. Its reviewed watcher requires the
  exact v272 identity, prior sequence/run ID 2, sequence 3 in RUN, and mask
  `0xF000`, then toggles lane 12 exactly once without halting or resetting the
  MicroBlaze. Do not wrap this launcher in `test`, a pipe, redirection, or
  `bash -lc`; those forms are not covered by its narrow permission.

- Read-mostly board diagnostics use only the fixed absolute launcher and one
  of its four operations:

  ```sh
  python3 /nfs/cms/hw/wittich/25G_2/vu13p_ibert_25g/scripts/board_diagnostics.py clocks
  python3 /nfs/cms/hw/wittich/25G_2/vu13p_ibert_25g/scripts/board_diagnostics.py modules
  python3 /nfs/cms/hw/wittich/25G_2/vu13p_ibert_25g/scripts/board_diagnostics.py results
  python3 /nfs/cms/hw/wittich/25G_2/vu13p_ibert_25g/scripts/board_diagnostics.py temperatures
  ```

  `--dry-run` may be appended. Module reads can clear latched alarms, result
  reads move the diagnostic selector, and all MCU-UART operations must be
  serialized.

- F1 programming uses `scripts/board_program.py` only with a supported,
  hash-pinned fixed choice. The installed narrow rule covers absolute-path
  `v270` and `golden`; a separately approved project-relative rule covers
  `v271`, `v272`, and `v273`; the narrow v274 programming rule is now also
  installed. V272 is pinned to bitstream SHA-256
  `7ca91032b55f3e71a97dd27678ab5b1bf9b00cbd0d105646cdcdc0666147215d`
  and matching ELF SHA-256
  `38187f08c33b02602623d7d25db136b70cfcac5611f9d7eeb1b786845daacf0c`.
  V273 is pinned to bitstream SHA-256
  `84a2d4db34f8ac4437dbec6f89fb2931f76f663a1846ba5b1e7d2075b08cfedf`
  and ELF SHA-256
  `e32976fabe1e7834fc34c14db21829b25741386278663869bb544c4721beb62b`.
  V274 is pinned to bitstream SHA-256
  `0dd18f901c69f43e51a80aeb5e9e0727b8842e9aa98f69565af3ee07f48ad80a`
  and ELF SHA-256
  `dc20fc8b37d19d393f031786df21313df5aee9dc82f21ef0c1102ee5e5b1d7b0`.
  V275 is pinned to bitstream SHA-256
  `92cf91bbfd2214f0349cb6155c527eddf198268a03585d25fbe715e84d90d08e`
  and ELF SHA-256
  `b72ac12cfa79d4e43d3b119eff74f1da7fa8b77b925a31618caa4576f5a58adf`.
  A permitted command form does not authorize another reload.

- All-direct v12 programming used only `python3 scripts/board_program.py
  direct_all_v12_f1|direct_all_v12_f2`. Both choices pin the exact v12 BIT and
  ELF hashes above and were consumed successfully. The hardware gate used only
  `python3 scripts/board_all_direct_v7.py
  deploy|status|pma-f1|pma-f2|external`, with the fixed remote namespace
  `/tmp/all-direct-v12-20260918`. All programming and gate stages are consumed;
  do not invoke them again. Historical v11 choices now point to its preserved
  archive, and retained v12 choices point to the frozen scoped-pass archive,
  rather than mutable current build products.

- V273 deployment and fixed hardware gates use only `python3
  scripts/board_v273.py deploy|clean1|clean2|pulse4|firefly5`. The installed
  narrow rule covers this launcher. It accepts no arbitrary host, path, sequence,
  command, stimulus, or retry; its stimulus choices pin their sequence and
  expected prior state, it hash-verifies the reviewed Apollo bundle, and it
  retrieves raw evidence even if validation fails. The pulse launcher waits
  for an explicit watcher-arm acknowledgement before submitting the request.
  Outputs are non-overwriting. Do not add another run or stimulus behind this
  permission without review and task authorization.

- V274 deployment and its fixed two-run gate use only `python3
  scripts/board_v274.py deploy|clean1|heartbeat2`. The installed narrow rule
  covers this launcher. It accepts no
  arbitrary host, path, sequence, duration, command, or retry. `heartbeat2`
  waits for a watcher-arm acknowledgement before submitting sequence 2, writes
  only the lane-15 toggle mask once to suppress the monitor heartbeat and once
  to restore it, and uses an unconditional restoration path after the first
  write. Outputs are exclusive/non-overwriting. A new narrow command approval
  was used for the completed two-run gate. Do not add a later run or stimulus
  behind this permission; approval of the helper does not authorize either.

- V275 deployment and its fixed clean gate use only `python3
  scripts/board_v275.py deploy|clean1|clean2`. The installed narrow rule covers
  this launcher. It pins identity, predecessor sequence, run ID, 10-second
  duration, clean stimulus, remote directory, and non-overwriting evidence
  names; deployment verifies every remote file hash. It contains no program,
  reset, retry, arbitrary command, sequence, duration, path, or stimulus. Both
  fixed runs are complete; do not add a long soak behind this permission.

- The separate v275 soak rule covers only `python3
  scripts/board_v275_soak.py deploy|start|status|results`. The reviewed helper
  fixes F1, v275 identity, sequence 3 after sequence/run 2, all four managed
  lanes, 43,200,000 ms, host/path, and non-overwriting logs. `start` is already
  consumed and must never be invoked again. Its first
  postcondition incorrectly expected run ID 3 immediately after RUN entry and
  returned failure after a successful submission; no retry occurred. The
  corrected, hash-verified helper requires run ID 2 while RUN and run ID 3 only
  after publication. The uninterrupted soak passed and the non-overwriting
  `results` operation is also consumed. Do not invoke `start` or `results`
  again; `status` is read-only but is no longer required for monitoring.

- Legacy `default.rules` contains broad and one-off SSH/SCP permissions for
  `lnx4189` and `apollo3010-1`, plus historical qualification commands. Prefer
  the fixed launchers above. If direct remote access is genuinely required,
  preserve the fixed `-F /dev/null`, control socket, `BatchMode=yes`, host/user,
  and exact remote command; do not infer permission for a new test, write,
  transfer, reset, or stimulus from an old matching rule.

The narrow rule details and caveats are documented in
`docs/diagnostic-approvals.md`; `docs/board-diagnostics.rules.proposed` is a
reference copy, not active policy. The active `vivado.rules`,
`board-diagnostics.rules`, `board-program.rules`, and legacy `default.rules`
remain the source of truth if this summary and installed policy diverge.

## Validation workflow

For the golden image, run:

```sh
bash skills/vivado-build-project/scripts/run-vivado.sh scripts/create_project.tcl
bash skills/vivado-build-project/scripts/run-vivado.sh scripts/build_bitstream.tcl
```

For full Milestone 3, use matching sources and version identities:

```sh
bash skills/vivado-build-project/scripts/run-vivado.sh scripts/run_milestone3_unit_sim.tcl
bash scripts/build_milestone3_firmware.sh
bash skills/vivado-build-project/scripts/run-vivado.sh scripts/build_milestone3_bitstream.tcl
bash skills/vivado-build-project/scripts/run-vivado.sh scripts/audit_milestone3_routed.tcl
```

For the full v14 diagnostic, use only its matching versioned entry points:

```sh
bash scripts/build_milestone3_v14_firmware.sh
bash skills/vivado-build-project/scripts/run-vivado.sh scripts/build_milestone3_v14_bitstream.tcl
bash skills/vivado-build-project/scripts/run-vivado.sh scripts/audit_milestone3_v14_routed.tcl
```

For isolated v272 / 2.5.22, use its matching identity and entry points:

```sh
bash skills/vivado-build-project/scripts/run-vivado.sh scripts/run_milestone3_unit_sim.tcl
bash scripts/build_milestone272_firmware.sh
bash skills/vivado-build-project/scripts/run-vivado.sh scripts/build_milestone272_bitstream.tcl
bash skills/vivado-build-project/scripts/run-vivado.sh scripts/audit_milestone272_routed.tcl
```

For isolated v273 / 2.5.23, use the corresponding `273` firmware, bitstream,
and routed-audit scripts. V273 alone enables the planned startup restart.

For isolated v274 / 2.5.24, use the corresponding `274` firmware, bitstream,
and routed-audit scripts. V274 alone enables the controlled heartbeat-monitor
test hook; run the v274-specific routed fan-in check and preserve the physical-
clock evidence boundary.

For isolated v275 / 2.5.25, use the corresponding `275` firmware, bitstream,
and routed-audit scripts. V275 enables the accepted detector/startup policy and
explicitly disables the v274 test hook; require the physical-only routed
heartbeat fan-in check.

Before programming hardware, verify matching firmware/hardware versions,
compression, IP status, synthesis and implementation warnings, routed DRC,
CDC/methodology findings, GT ownership/placement and golden RX properties,
timing, routing, clock frequencies, and bus skew. Require 100.000-MHz and
325.000-MHz implemented monitor clocks, zero routing errors, all bus-skew
constraints met, and no timing or DRC errors. Do not describe the design as
globally CDC-clean merely because reviewed generated-IP and intentional CDC
findings are accepted.

## Hardware qualification

- Use unique request sequences and require exactly one hardware run-ID
  increment, matching response sequence, atomic lane records, and final healthy
  IDLE. Never silently retry a failed run.
- On an unexpected error, preserve results first with
  `scripts/milestone3_dump_results.py`, then capture power, temperature,
  reference-clock, module, and link-partner state before reconfiguration.
- `scripts/run_milestone3_12hour_soak.sh` is POSIX `sh`/BusyBox `ash`
  compatible. Execute it; do not source it. It logs stdout/stderr to screen and
  file, checks status every 30 minutes, and collects final results.
- `scripts/run_milestone3_24hour_qualification.sh` provides the same unattended
  logging and 30-minute status cadence for the 24-hour v11 qualification. Its
  continuation defaults are request sequence 5 after sequence 4.
- The unattended 24-hour v11 external qualification passed; final results are
  in `docs/evidence/legacy/24hour.txt`. The SSH connection died, so the half-hour watcher output was
  not retained. The exact completion timestamp, final AVTT current, and FPGA
  temperature remain to be appended. On 2026-09-11, v11 targeted
  measurement-time error injection passed as sequence 6/run ID 5, explicit
  abort passed as sequence 7/run ID 6, and automatic timeout passed as
  sequence 8/run ID 7. The first CPU-halted-test launch, sequence 9/run ID 8,
  failed before RUN because lane 14 never acquired PRBS lock; its
  `0x04000404` result and first-fault diagnostics were preserved. Do not retry
  or reconfigure silently. After explicitly recording that failure, F1 was
  reloaded with the same audited v11 image and CPU-halted completion passed as
  fresh post-reload sequence 1/run ID 1. Post-reload sequences 4 and 5 then
  disabled only physical F1 FireFly-5 channel 0/global lane 12 for one and ten
  seconds. Lane 12 alone saturated its error count and lanes 13-15 stayed
  clean, but `RXPRBSLOCKED` never deasserted and the lane-12 lock-loss count
  remained zero. Sequence 7 captured FireFly byte-3 LOS `0x11` (RX0/TX0) and
  byte-5 CDR LOL `0x01` (RX0) during the outage, proving the module saw the
  intended isolated loss. Single-lane disturbance isolation passed, but the
  required FPGA lock-loss indication did not; do not describe v11 as fully
  qualified.
