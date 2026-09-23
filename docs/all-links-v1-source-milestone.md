# All-links source milestone

## V2 subset-participation repair — timing-clean audited candidate

All-links v1 / `0x00020500` is superseded as a hardware candidate.  Its
all-quad acquisition/capture reductions strand a direct-only request because
the fourteen unselected FireFly controllers remain IDLE and false.  V2 uses
the distinct FW/HW identity `0x00020501`; no v1 artifact was relabeled.

The engine now publishes its accepted 112-bit lane mask.  The management
domain derives one participation bit per four-lane quad and registers each
6/8/8/6 slice at the existing SLR bank boundary with the accepted descriptor
controls.  Only acquisition-ready and capture-done use
`quad_selected ? quad_status : 1'b1`.  Global ready, fault, idle, reset and
TX-session barriers still include all 28 quads.  Lane order, FireFly-3
reversal, session/recovery behavior, diagnostics, ABI and historical targets
are unchanged.

The new integrated engine-plus-four-bank regression proves direct-only
globals56--111 completes while all FireFly quads are unselected, sparse masks
that omit whole quads complete, all 112 lanes complete, selected IDLE
controllers cannot admit early RUN, unselected quads remain active in the
fault/idle/session barriers, and back-to-back changed masks retain one epoch.
The focused bank, all112, subset, re-arm, aggregate/session, descriptor,
historical direct, and FireFly reset/session/subset regressions all pass.
ELF SHA-256 is
`d947fd47e684a1e0be08296d34b4de1b1e28d7c056ecabffcbfb681786730f9c`.

Fresh clean synthesis and exact preflight pass: 112 channels, 28 commons,
twelve managed REFCLK inputs, 28 controllers, 112 engines, 28 participation
registers split 6/8/8/6, four bank resets, exact descriptor/session CDC and 28
bus-skew groups.  Synth DCP SHA-256 is
`e1a8a3a20d177e6828b4378230dfb74d55bc624481f54fce86dcee8c2cd00a71`.

The single normal implementation is physically clean but fails timing.
Signoff setup is WNS/TNS -0.158/-26.399 ns over 580 endpoints in 18 clock
groups: `clk_200` is -0.158/-9.680 over 122 endpoints, RXOUTCLK group 4 is
-0.124/-14.894 over 366, and sixteen other RX groups have 1--39 failures.
Hold is +0.010/0.000 with zero failures; 212,076/212,076 routable nets are
fully routed with zero routing errors/unrouted/partial/overlap nets, zero Error
DRCs, and 28/28 bus-skew groups met.  Routed DCP SHA-256 is
`ec0de1a6268e76c3666f3d2984333e89e6c1b3ca05b2b3c1809f0faf4aa50f9c`.
This broad multi-clock failure does not meet the reviewed criterion for the
single optional post-route default `phys_opt_design`; it was not run.  No
audit or bitstream followed.  Evidence is frozen under
`build/diagnostic_archive/all-links-v2-0x00020501-normal-route-timing-failure/`.

A separate, bounded incremental close attempt then attached the exact audited
v1 routed DCP to the frozen v2 synthesis DCP.  The read-only compatibility
gate and placed design retained 98.94% cell and 97.08% net reuse.  Placement
passed the corrected bank/locality gate at setup WNS/TNS -0.770/-3.982 ns over
11 endpoints and hold -0.080 ns over 21.  One default `phys_opt_design`
improved estimated setup to +0.001 ns.  The following single `route_design`
was physically clean but failed signoff setup at -0.119/-5.883 ns over 93
endpoints, exclusively `clk_200`; hold passed at +0.005/0.000 ns with zero
endpoints.  All 212,112 routable nets are fully routed with zero route errors,
zero Error DRCs, and 28/28 bus-skew groups met.  Routed DCP SHA-256 is
`6fd5e2b102f7b2fc79e4868adc66b7fca4cb737c7aa4989ff21ef74c6dc91824`.
Evidence is frozen under
`build/diagnostic_archive/all-links-v2-v1-incremental-timing-close-attempt-retry2/`.
The gate stopped without extra post-route physopt, retry, audit, bitstream, or
hardware action.

### V2 timing-hardening closeout

The successful strategy changes only v2's timing structure. Four registered
result-copy banks replace the central 112-to-1 mux; each lane's atomic 256-bit
snapshot is transferred as four parallel 64-bit handshakes; and each quad has
a cycle-matched local reset-release register. The four-bank copy remains
functionally registered and exact, while physical copy-stage residency is
diagnostic rather than an architectural invariant. Only the existing eight
control/reset boundary registers per SLR are hard-contained.

Focused participation, result-copy and bank-reset regressions pass alongside
the historical focused, subset and same-instance re-arm regressions. Fresh
synthesis/preflight proves exact 112 channels, 28 commons, 12 managed REFCLKs,
28 controllers, 112 engines, four result banks, 1024 data plus four valid
copy registers, 28 per-quad reset releases, 28,672 split-snapshot payload
registers and 448 capture enables at fanout 64. Synth DCP SHA-256 is
`a914ff24b3a9e9a106ff92a6276ce2c0842df701112c420e65e4c61e1847b8f9`.

The single focused control/reset-boundary implementation passes signoff setup
and hold at +0.046/+0.009 ns with zero failing endpoints. All 220,150 routable
nets are fully routed, routing and Error DRC counts are zero, and all 476 skew
groups meet. Routed DCP SHA-256 is
`323ff58252ae66a81e42c84d38b528ce053561804cdc7eeecb99d3066107993a`.
A fresh-process independent audit passes exact topology and GT properties,
CDC, descriptor/session/barrier semantics, and strict physical 6/8/8/6
participation and per-quad reset residency. The result-copy locality report
records the SLR0 bank as 24 cells in SLR0 and 233 in SLR1; the other three
257-cell banks are fully resident in their assigned SLRs. That distribution
is informational because the registered structure and timing are the gates.

A hash-pinned writer opened only the independently audited routed DCP,
required its audit marker, verified compression, passed write-time DRC with
zero errors and generated the bitstream without rebuilding or rerouting.
BIT/DCP/ELF SHA-256 values are
`163172d938f5aa87fd606061e75e058f5d7040916d86d4744a206309f970b66f`,
`323ff58252ae66a81e42c84d38b528ce053561804cdc7eeecb99d3066107993a`,
and `d947fd47e684a1e0be08296d34b4de1b1e28d7c056ecabffcbfb681786730f9c`.
Exact artifacts, implementation reports, the independent audit, regression
logs and writer evidence are frozen under
`build/diagnostic_archive/all-links-v2-timing-hardened-control-boundary-clean/`.
No launcher/deployment choice was released and no hardware was accessed.

Offline F1-only launcher scaffolding remains explicitly `RELEASED=False`; it
has no released artifact pins or programming choice and cannot act on
hardware. A future hardware gate must also
acknowledge that loading all-links brings outward FireFly serializers up with
PRBSSEL=0 and zero userdata rather than v12's tied-off outputs.  No hardware
was accessed for this repair/build.

## V1 historical record

Status: superseded by v2; revised SLR-bank source, clean synthesis, corrected placement gate, and
one default phys-opt/route continuation completed; routed setup timing failed,
2026-09-19.
This target has not produced a timing-clean/audited bitstream and has not been
programmed or tested on hardware.

## Allocation and scope

The new symmetric target is `all-links v1`, top
`gt_test_all_links_v1_top`, FW/HW identity `0x00020500`. It is independent of
all historical targets. It is based on all-direct v12 behavior and manages all
112 25.78125-Gb/s lanes without IBERT or the 10-Gb/s AXI C2C lanes:

| Global lanes | Connector | GT quads |
|---:|---|---|
| 0--11 | FF1 | q121--q123 |
| 12--15 | FF5 | q124 |
| 16--27 | FF2 | q125--q127 |
| 28--39 | FF3 | q128--q130, reverse-12 physical packing |
| 40--43 | FF6 | q131 |
| 44--55 | FF4 | q132--q134 |
| 56--111 | direct FPGA-to-FPGA | q221--q234 |

The managed RTL mask is `112'hffffffffffffffffffffffffffff`. Firmware uses
mask words `ffffffff`, `ffffffff`, `ffffffff`, `0000ffff`. The design has 28
independent four-lane Wizard/common groups and twelve physical REFCLK0 input
buffers. Common source quads are q122/q124/q126/q129/q131/q133 and
q222/q224/q226/q229/q231/q233, with local/north/south dedicated routing. Four
control launch banks feed explicit SLR-local aggregate groups of 6/8/8/6
quads. All 28 TX-domain session acknowledgements are ANDed before the
management-domain acknowledgement is returned.

The stable mailbox/result ABI, generic and SysMon addresses, FE diagnostics,
clock-monitor ordering, FSM encodings, compression policy, and 112-lane result
layout are retained. A session request is global: **any external-mode session
drives all 112 transmitters selected by the request mask, including outward
FireFly transmitters.** No external-mode hardware test is authorized until an
explicit board/operator policy approves those outward emissions. Near-end PMA
does not require a TX session.

## Reproducible source gates completed

- Static source tests: five tests pass.
- RTL parser/source contract passes.
- Aggregate regression passes the 6/8/8/6 partition and all-28 acknowledgement
  barrier.
- Fresh all-112 and fresh subset engine regressions pass, including rejection
  of lane 112 as out of range.
- Fourteen left-side IPs generate reproducibly (56 channels, 14 commons), and
  fourteen exact local/north/south topology wrappers derive successfully.
- Firmware builds with one matching ELF. SHA-256:
  `96d3ab54308b894d34f2add001c16d1aa52029bc1474aba506c3017ca6a978ae`.
- The independent project recipe scopes each generated left Wizard XDC to its
  topology wrapper, enables canonical full-board pins, and retains the proven
  all-direct v12 right-side IP/configuration.
- Vivado RTL elaboration proves one matching ELF, 112 `GTYE4_CHANNEL`s, 28
  `GTYE4_COMMON`s, twelve managed-GT physical REFCLK buffers, and no IBERT or
  C2C hierarchy.

The focused regressions now also include a deterministic same-instance re-arm:
request phase 0 selects all 112 lanes and request phase 1 selects the sparse
set `{0,31,32,33,66,67,96,111}`. Both publications match the accepted epoch
and mask. The earlier exploratory mismatch did not reproduce; it was a stale
synchronous result-bank/selector observation. The regression therefore uses
selector settling and two AXI reads, and no production RTL or mailbox ABI
change was justified.

## Clean synthesis and implementation blocker

Clean non-incremental Vivado 2023.2 synthesis passes with zero errors and zero
critical warnings. Preflight proves the exact CDC, clock, descriptor, control,
reset, session and result-copy inventories, plus 112 channels, 28 commons and
twelve managed physical REFCLK buffers. Canonical synthesis DCP:
`build/gt_test_all_links_v1/gt_test_all_links_v1_synth.dcp`.

The first clean route completed with zero failed/unrouted/partial nets and no
DRC errors, but failed signoff setup at WNS/TNS -1.277/-1517.198 ns (4916
endpoints); its clk_200 subset was -0.978/-1406.601 ns (4392 endpoints), and
hold was +0.010 ns. Worst clk_200 paths showed q133 controller logic
round-tripping SLR2->SLR3->SLR2 despite advisory SLR assignments. Evidence is
frozen under
`build/diagnostic_archive/all-links-v1-first-route-timing-failure/`.

One reviewed constraint-only experiment hard-confined all quad-wrapper
hierarchies to 6/8/8/6 SLR pblocks. It removed placer partition warnings but
overconstrained Wizard/controller support logic. Its clean route again had
zero failed nets and no DRC errors, but signoff worsened to WNS/TNS
-1.412/-3535.183 ns (10939 endpoints); its clk_200 subset was
-1.412/-2888.379 ns (7274 endpoints), and signoff hold was +0.005 ns. Worst
paths include the
high-fanout top-level power-on reset into q234 controller reset pins and q124
DRP/control enable paths. That failed experiment is evidence, not a candidate
constraint set, and was reverted after archiving under
`build/diagnostic_archive/all-links-v1-hard-pblock-timing-failure/`.

A third, constraint-only attempt explicitly enumerated the primitive leaves of
the 28 PRBS controllers, 112 lane engines, 112 Wizard power-good delay blocks,
and four SLR-local reducers while retaining only the existing control and
descriptor banks. Preflight was exact: 136,057 synthesis leaves split
28,935/38,934/38,935/29,253, with zero overlap or GT, common, BUFG, REFCLK,
session/native, or reset-tree inclusion. Vivado then canonicalized the complete
leaf lists to 256 hierarchy roots (55/73/73/55). Placement completed, but the
mandatory read-only re-expansion check failed: 506 real optimized leaves in 13
roots were outside their expected SLR; a further 649 VCC/GND pseudo-primitives
are intrinsically non-placeable. The placer estimate was WNS -1.240 ns. The
attempt stopped before phys-opt and route, so it has no routed timing, route,
DRC, bus-skew, bitstream, or audit result. Placed DCP SHA-256 is
`2210494576b52fe157cab387d4d2b5532bc315aa77c1755f5e20c4b3b8adb140`;
evidence is frozen under
`build/diagnostic_archive/all-links-v1-enumerated-leaf-locality-attempt/`.
The failed locality pblocks and optional final-reducer advisory were reverted;
the proven control/descriptor pblocks remain. Do not repeat this canonicalized
parent-membership approach.

A fourth and final reviewed locality experiment used an all-links-only,
synthesis-only XDC to preserve exactly the 28 `gt_prbs_test_controller` roots.
Fresh non-incremental synthesis passed with all 28 roots carrying
`KEEP_HIERARCHY`, zero `DONT_TOUCH`, all PRBS FSM registers retaining
`FSM_ENCODING=none`, and the expected 112 channels, 28 commons, twelve managed
REFCLK buffers, 112 engines, 28 controllers, session/CDC inventories, and
matching ELF. The experimental synthesis DCP SHA-256 is
`7722afa7346774b7ac0695cb3a59eec4ef1a8f36059e8caf83ca93b6bc6218be`.
Exact preflight then applied 256 hierarchy roots split 55/73/73/55: controllers
6/8/8/6, engines 24/32/32/24, Wizard power-good roots 24/32/32/24, and one
local reducer per SLR. The existing control/descriptor pblocks remained.

Post-opt root proof passed. Placement improved its estimate from the preceding
-1.240 ns to WNS -1.089 ns and all 28 bus-skew groups were met, but the
mandatory containment gate failed: 257 real optimized leaves escaped across
five mixed roots, with zero duplicate leaves. The mixed roots were three PRBS
controllers and the SLR0/SLR3 local reducers. The reducer selection also
captured ten explicitly excluded `tx_session_applied` primitives, so it failed
the session-support exclusion independently. Another 649 VCC/GND primitives
were reported separately as non-placeable constants. The attempt therefore
stopped before standalone phys-opt and route; it has no routed timing, route,
DRC, bitstream, or independent audit result. Placed DCP SHA-256 is
`9b3844aef5b5728d3dc6c270aa52c698f3e9e23df44115982c1ffb1dbffd0e9e`;
evidence is frozen under
`build/diagnostic_archive/all-links-v1-keep-hierarchy-locality-attempt/`.
The experimental XDC/property and pblocks were removed from the active target,
and a fresh clean synthesis of the reverted target passes with 28 controllers,
zero controller `KEEP_HIERARCHY`, zero controller `DONT_TOUCH`, and the exact
structural preflight. The restored canonical synthesis DCP SHA-256 is
`7a65ce41ad68a407e113f5d39778d6438e6553f4665af1727f7a151bbf2d488b`.
Do not repeat this KEEP_HIERARCHY-root approach.

A fifth reviewed experiment changed only the all-links branch to four explicit
`all_links_v1_slr_bank` roots.  The banks own 6/8/8/6 quads (left low, right
high), and each contains one unchanged seven-output control pipeline, one
synchronous one-cycle local reset-release register initialized low, its
managed wrappers, and one unchanged local aggregate.  The engine and final
four-bank reducer remain on global reset.  Only the four bank roots carry
`KEEP_HIERARCHY`; there is no `DONT_TOUCH`.  Constraints use soft
`USER_SLR_ASSIGNMENT` on those roots and hard SLR pblocks only for the intended
seven control outputs plus local-reset register per bank, while retaining the
descriptor-launch pblocks.

The focused bank-reset/session/packing test and all-112, subset, same-instance
re-arm, aggregate/session, descriptor, historical direct, and FireFly
regressions pass.  Fresh nonincremental synthesis completed with zero errors or
critical warnings.  Preflight proved 112 channels, 28 commons, twelve managed
REFCLK buffers, 28 controllers, 112 engines, 28 request and 28 return two-flop
session chains, 28 bus-skew groups, bank ownership 6/8/8/6, synthesized control
registers 7/7/7/7, local resets 1/1/1/1, and reset fanouts confined to their
banks.  Synth DCP SHA-256 is
`409a7a24819c0da515d5443688df038649584c0b4e5820e583e909890b812ace`.

The original placement interpretation stopped the single clean nonincremental
implementation at its mandatory gate.  `opt_design` removed
`controls_out_reg[1]` from
every bank, leaving 6/6/6/6 control primitives plus the four local-reset
registers instead of the mandatory 7/7/7/7 plus four.  All surviving boundary
registers were in their assigned SLR, but 47 controller/local-reducer leaves
escaped: q223 controller leaves crossed SLR0->SLR1, q132/q133 controller
leaves crossed SLR3->SLR2, and three SLR3 reducer leaves crossed to SLR2.
The old gate treated both facts as structural failures and no phys-opt or route
was run at that time.
Placed timing nevertheless improved substantially to setup WNS/TNS
-0.511/-3.798 ns over 48 endpoints; placed hold was -0.219/-9.499 ns over 192
endpoints, all 28 bus-skew groups met, and the global POR/reset was absent from
significant failing endpoints.  These timing numbers are diagnostic only and
cannot override the structural gate.  Failed placed DCP SHA-256 is
`2ce015893cfbb15ad62be0bb77d98d71d697c44d517e1910e71dbab58271f439`;
evidence remains frozen, unchanged, under
`build/diagnostic_archive/all-links-v1-slr-bank-attempt/`.

A reviewed closeout corrected that gate without changing RTL, constraints, IP,
synthesis, placement, seed, or directives.  Static and hash-pinned synthesis
proofs show that all 28 wrapper controllers use the default
`RUNTIME_INTEGRITY_DETECTOR=0`; therefore bank-local
`controls_out_reg[1]` has no post-opt load, while all 112 lane engines still
receive the global engine measurement control.  The exact post-opt boundary is
indices `{0,2,3,4,5,6}` plus `local_resetn` in each bank.  Fanout proof shows
all 47 cross-SLR leaves are publication-only: q223/q132/q133 exact-error logic
terminates in exact-count/result-copy sinks and the three SLR3 reducer leaves
terminate in the final reducer, with no controller feedback.  The corrected
read-only gate passed 6/8/8/6 ownership, reset confinement, soft assignments,
obsolete-pblock exclusion, 28/28 bus-skew, publication timing, and the original
placement improvement.

The exact placed DCP above then received one default `phys_opt_design` and one
default `route_design`.  A first launcher invocation failed before phys-opt at
license checkout and is preserved separately; after the approved `lmutil`
preflight reported the server UP and Implementation 10 issued/0 used, the same
hash-pinned continuation acquired a license.  Phys-opt improved estimated
setup to WNS/TNS -0.117/-1.677 ns.  Route is physically clean: 212,246/212,246
routable nets fully routed, zero routing errors/unrouted/partial/overlap nets,
zero Error-severity DRCs, and all 28 bus-skew groups met.  Hold passes at
WHS/THS +0.010/0.000 ns with zero endpoints.  Setup remains negative only in
`clk_200`: WNS/TNS -0.034/-0.343 ns over 22 endpoints; all other clock groups
are nonnegative.  The strict gate therefore failed and stopped as required.
No bitstream or independent audit was produced.  Phys-opt/routed DCP SHA-256
values are `ddd16b4d5678b838f39e2b1e8d6e1a70ad8f75df98d8901e0df49eea21e4b832`
and `4631ff396e6b18baf61a312c6beaa7d77b00f6ba267830c40367a163a222a974`;
evidence is under
`build/diagnostic_archive/all-links-v1-slr-bank-closeout-continuation-retry1/`.
Do not rerun this exact route or add speculative timing exceptions.

A reviewed conservative closeout then used only the exact routed DCP above.
Read-only preflight reproduced its timing, route, DRC, skew, topology,
bank/reset state, and all 22 endpoints in eight residual path families. Exactly
one plain `phys_opt_design` was invoked, without `-post_route`, `route_design`,
directive, or retry. It optimized 14 cells/nets, added and removed none, and
improved setup WNS/TNS to +0.001/0.000 ns. Hold remains +0.010/0.000 ns;
setup and hold have zero failing endpoints in every clock group. Routing is
clean at 212,249/212,249 routable nets, with zero route errors, zero Error
DRCs, and 28/28 bus-skew groups met.

The fresh-process independent audit passes timing/routing/DRC, CDC,
methodology, all 448 descriptor endpoints and 28 skew groups, corrected bank
controls/reset/session inventories, exact 112 channels/28 commons/12 physical
REFCLK buffers, 28 dedicated common routes, 224 QPLL sinks, and golden GT
properties. Its first invocation exposed an audit-query bug that applied an
`FD*` filter to hierarchical controller roots; the unchanged DCP passed after
that query was corrected. Compressed BIT/DCP/ELF SHA-256 values are
`5cb71e186edf73ce42adc33eeaa9e1d9ef090468d2f4e297fc83cecc6c2e729d`,
`a6862fdd15945b9532257d55dbfcb5e48dbde8c4ff9fb11637e7ed28d085d4c3`, and
`96d3ab54308b894d34f2add001c16d1aa52029bc1474aba506c3017ca6a978ae`.
Evidence is under
`build/diagnostic_archive/all-links-v1-postroute-default-physopt-attempt/`.

The current bank-source synthesis DCP, historical baseline failed routed DCP,
historical retry failed routed DCP, and firmware ELF SHA-256 values are
respectively
`409a7a24819c0da515d5443688df038649584c0b4e5820e583e909890b812ace`,
`639ccad82679a0462d765a3c5881de3ac98cb37bf0f08e4da30e3d55e7d05f31`,
`c49b78b9f0bffdc464bd241a585ad462a5085f862c69dd3f29bb7795bc9ec980`,
and `96d3ab54308b894d34f2add001c16d1aa52029bc1474aba506c3017ca6a978ae`.
The prior failed routes remain evidence only. The later closeout artifact above
is the sole audited build candidate.

## Next gate

The source milestone now has one timing-clean, independently audited,
compressed build candidate. Do not rerun implementation or mutate this
artifact. Any programming or PMA/external hardware qualification requires a
separately reviewed, hash-pinned hardware gate. External testing remains
policy-blocked as above.

No hardware launcher or deployment choice was created in this milestone.
