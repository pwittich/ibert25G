# VU13P IBERT Project Memory

Last updated: 2026-11-10

## Runtime quad control implementation

The user approved implementing all-links v3 (`0x00020502`) with independent
28-bit TX/RX masks per FPGA, applied only while IDLE/session-off. Both masks
default to zero. TX disable uses electrical idle; RX disable quiesces checking
and lane protocol without powering down clocks/PLLs. Fully disabled quads are
excluded from operational health barriers while raw diagnostics remain visible.

Working baseline is committed as `34c73bb`; the feature branch is
`feature/all-links-v3-quad-control`. New modules/ELF/project/scripts isolate
the feature from v2 and historical targets. Build products remain ignored.
No hardware/deployment action is authorized by the implementation phase.
V3 passes static qualification with an independently audited compressed
BIT/BIN. Its pinned launcher remains fail-closed/unreleased pending a
separate reviewed hardware procedure. `docs/all-links-v3-runtime-control.md`
and the top of `docs/memory/build-state.md` record development and build state.

## BIN output and existing-image conversion — 2026-11-09

The user requested BIN alongside BIT in future builds, then requested BINs
from existing golden IBERT and latest other-build artifacts without a rebuild.
Golden project creation and synthesis continuation now enable
`STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE`; both build entry points require
nonempty `top.bin` alongside `top.bit`. The standard and timing-hardened
control-boundary all-links v2 writers use `write_bitstream -bin_file`, retain
compression/audit checks and reject existing BIT or BIN outputs. The hardened
writer reports both hashes. Historical one-shot build scripts were not updated.
Vivado 2023.2.2 accepted/read back the option in an empty temporary project;
Tcl completeness and whitespace checks passed. No full build was run.

Created and verified under `build/configuration_bins_20261109/`:

- `golden_ibert_compressed.bin`: 70,389,172 bytes, from
  `build/golden_compressed_20260912/top.bit`.
- `golden_ibert_historical.bin`: 113,318,376 bytes, from the canonical
  `build/vu13p_ibert_25g.runs/impl_1/top.bit`; retains historical uncompressed
  configuration data.
- `all_links_v2_timing_hardened.bin`: 70,100,232 bytes, from the exact audited
  `0x00020501` BIT under
  `build/diagnostic_archive/all-links-v2-timing-hardened-control-boundary-clean/artifacts/`.

Conversion removed only BIT container headers, preserving byte order,
compression and all configuration/embedded BRAM data, with no padding or bit
swapping. Each BIN equals its full source payload byte for byte; source BIT
hashes were rechecked unchanged. `manifest.json` records exact source/output
hashes, paths, metadata and payload offsets; `SHA256SUMS` passes for all three.
See README's golden-build section for clickable artifact links and the
verification command. All outputs remain ignored generated `build/` products.
No synthesis, implementation, checkpoint re-emission, programming or hardware
test occurred. Board state below remains the last observation, October 27.

## Current resume state — October 2026 session

The latest observed board state is from **2026-10-27**, not a new live read on
the memory-update date. F1 and F2 on Apollo 3010 run the exact audited
all-links v2 image, firmware/hardware `0x00020501`. Both are healthy
IDLE/session-off `0x00100000`, request/ack **3**, run **1**, summary
`0x00363601`, with required clocks valid. No agent-issued test, reload or reset followed
that run; subsequent work changed operator scripts, documentation and slides.
The old September seq/ack15/run5 optical state below is historical.

On October 27, F1 and then F2 were separately programmed at the user's
request. F2 emitted `PROGRAM_F2_COMPLETE` and showed its MicroBlaze running,
then XSDB aborted during shutdown (`Tcl_FindHashEntry on deleted table`, exit
134). No programming retry was made. Independent generic-I2C/MCU checks and
the subsequent complete PRBS31 run verified the loaded image.

The user then authorized one **180-second bidirectional inter-FPGA PRBS31**
test with clean `cm_interface` **v1.0.3**, commit
`64260cf23b01c9da987feda1fbf51567240c2c71`. All **54 fitted receive lanes per
endpoint** passed with zero errors and zero native lock losses, approximately
4.64055e12 tested bits/lane. F1 globals70/71 and F2 globals96/97 are unfitted
and excluded. Both stops completed. The new sequences1--3/run1 are consumed;
do not replay the archived invocation or start another hardware action just
to validate a script/documentation change.

Primary evidence:

- `build/diagnostic_archive/firefly1-all-links-v2-F1-program-1793110477206097.log`
- `build/diagnostic_archive/firefly1-all-links-v2-F2-program-1793111080326955.log`
- `build/diagnostic_archive/all-links-v2-readonly-v103-after-F2-1793111080326955.log`
- `build/diagnostic_archive/all-links-v2-timed-inter-fpga-180s-1793111744850372.{log,report.md,launcher.py}`
- `build/diagnostic_archive/all-links-v2-timed-status-1793113074559486.log`
- `docs/all-links-v2-inter-fpga-hardware-gate.md`

## Operator decisions and deployment status

- Prefer `cm_interface` **v1.0.3**, as explicitly requested by the user. It
  passed read-only checks plus the complete 180-second command/result/
  telemetry/session-stop procedure. Preserve its exact clean tag and commit.
- We are on **lnx4189**; SSH directly to `cms@apollo3010-1` for blade scripts.
  An extra jump via lnx4189 is unnecessary. Existing workstation wrappers
  still contain the older jump/control-socket configuration and v1.0.0 pin;
  do not mistake those defaults for the tested v1.0.3 deployment.
- The actual v1.0.3 runtime bundle is
  `/tmp/all-links-v2-status-v103-20261027` on the blade. It is temporary and
  predates the automatic-counter source change. The persistent
  `/home/cms/25G-v1.0.3` directory in HOWTO/PPT is an installation example,
  **not a deployment performed in this session**. The old `/home/cms/25G`
  deployment was absent when first checked in October.
- At the user's request, the current repository test runners and workstation
  launchers no longer require manual sequence/run arguments. They discover
  stable idle state while holding the MCU lock, log `PREDECESSOR` values,
  and recheck state/sequence before issuing commands. All four former flags
  remain optional expected-state guards for automation. Unguarded
  reinvocation is a **new test**, not resume or exactly-once retry.
- This CLI update has **15 passing focused offline tests**, Python-3.6 grammar
  checks and checked shell examples. It has **not been deployed or exercised
  on hardware**. Redeploy and hash-verify the complete runtime before using
  the simplified CLI on the blade. No HDL, firmware ELF or BIT was changed.
- Fresh programming is **not** required for each test. Reuse the correct,
  healthy running image. Old fresh/zero-sequence requirements belong to
  historical acceptance scripts or an explicitly guarded procedure.
- The MCU runtime DONE field (`0x06:0x15`) is raw **active low**: bit0=F1,
  bit1=F2. `0x00` means both configured; `0x02` means F1 only; `0x01` F2 only;
  `0x03` neither. Do not interpret `bool(raw & FpgaDone.F1)` as configured.
  Version/state readback still identifies which image is running.
- Each blade has **two** VU13Ps. A stale `hw_server` previously connected to
  blade 3017-1 caused XSDB to list four devices while checking 3010. The user
  cleared that server; fresh enumeration restored the expected two. Keep
  programming topology checks rather than weakening them to accept a stale
  combined listing. Exact F2 programming permits target2 or target4 only.
- The audited compressed BIT includes the MicroBlaze program as local-BRAM
  initialization data. Hardware Manager and XSDB both load it by programming
  that BIT; the ELF is not separately downloaded in the fixed programmer.

## Scope and user-facing artifacts

Every TX session selects all **112 transmitters per FPGA** (56 optical and
56 direct), even for a receive subset. The user explicitly confirmed that
all then-connected optical equipment can safely receive PRBS31; retain the
acknowledgement requirement and check wiring context before assuming that
statement applies to another setup. Selection limits **RX measurement**.
FireFly CLI selection supports q121--q134 singles/ranges/comma-separated sets
at both sites; direct CLI selection remains the fixed 54 fitted RXs/site.
Arbitrary 2xx subsets, mixed selections or differing optical masks per site
need a CLI extension. Global health/session barriers still involve all quads.
The September F1 FireFly lane1/3/4/6 error pattern remains unresolved; a clean
October direct test does not qualify those optical receivers.

- `HOWTO.md`: general operator guide with a quick start, real recorded
  results, deployment, v1.0.3 checks, selection limits, logging and cleanup.
- `docs/presentations/vu13p_25g_project_talk.pptx` and `.pdf`: **28 slides**
  for LHC physicists and engineers, with speaker notes. The opening contains
  how-to slides2--4 and real results on slide5; the editable FPGA block
  diagram is **slide9**. The architecture, I2C ABI, MicroBlaze/ELF build,
  CDC/timing, verification, BER statistics and limits follow.
- `docs/presentations/make_project_talk.py` regenerates the PPTX, text notes,
  scientific plots and diagram SVG. The archived raw measurement log is a
  required input. Dependencies/build steps are in
  `docs/presentations/README.md`; Inkscape makes the diagram PNG and
  LibreOffice the PDF. Figures were rendered and inspected.
- `docs/fpga-firmware.md` plus `fpga-firmware-block-diagram.{svg,png}`:
  standalone architecture. I2C accesses hardware mailbox/results directly;
  MicroBlaze supervises jobs over AXI, not each I2C byte. Both native slide
  objects and SVG come from the same generator.

The last recorded hardware run used the archived explicitly guarded launcher; its
pass must not be presented as hardware validation of the later automatic
counter-discovery update. The work remains in the shared working tree;
no commit or deployment of that update was made. Leave unrelated `.agents/`
contents intact. See `docs/memory/build-state.md` for exact build/run detail.

## Historical September development — all-links v2 timing-clean build

The following September chronology predates the October resume state above.

All-links v2 / `0x00020501` now has a timing-clean, independently audited,
compressed build candidate. It manages all 112 25.78125-Gb/s board lanes:
globals 0--55 are the 56 FireFly lanes in q121--q134, and globals 56--111 are
the 56 direct FPGA-to-FPGA lanes in q221--q234. It contains no IBERT and does
not own the 10-Gb/s AXI C2C lanes.

The source-level timing repair uses four registered result-copy banks, four
64-bit snapshot handshakes per lane, and cycle-matched per-quad reset release.
Signoff setup/hold is +0.046/+0.009 ns with zero failing endpoints; all
220,150 routable nets, 476 bus-skew groups, routing checks, Error DRCs, and the
fresh-process independent audit pass. Compressed BIT/routed-DCP/synth-DCP/ELF
SHA-256 values are `163172d9...0b66f`, `323ff582...993a`,
`a914ff24...7b8f9`, and `d947fd47...30f9c`. Exact evidence is frozen under
`build/diagnostic_archive/all-links-v2-timing-hardened-control-boundary-clean/`.
The concise successful/failed strategy record is
`docs/all-links-v2-timing-strategy.md`.
Both FPGAs now run this exact image. The first 180-second direct gate failed
without retry: F1 passed 54/54 fitted receivers; F2 passed 53/54, with
global98/q231 saturated errors and zero native lock losses. That gate remains
consumed. After a separately authorized power cycle and exact-image
reprogramming, a fresh second 180-second gate passed 54/54 fitted receivers at
both endpoints with zero errors and zero native lock losses, including
global98 at about 4.64e12 bits. Both sites are healthy IDLE/session-off at
seq/ack3,run1 with valid clocks; the second gate is consumed too. This supports
but does not prove a transient board/startup-state cause for the first result.
See `docs/all-links-v2-inter-fpga-hardware-gate.md`.

Prepared timed test launchers (90-second default) are released for reviewed use: one runs simultaneous
bidirectional external PRBS31 on the 54 fitted inter-FPGA receivers per site;
the other runs external PRBS31 through physical FireFly loopbacks on a
selectable q121--q134 receive quad/range at both sites. They gate on all
required FPGA clock counters and log 12-V power,
the two MCU-ADC FPGA diode temperatures, every LGA80D temperature, and every
physical FireFly temperature at pre/one-third/two-thirds/post points. The direct launcher
requires acknowledgement that the v2 full-mask session drives all 112 TXs;
the FireFly range limits measured receivers only. The direct gate above has
run; the FireFly receive gates are recorded below. User-facing names omit `_90s`, and
each completed test automatically writes an immutable Markdown summary beside
the authoritative log, including failures. The seven required remote runtime
files were deployed and hash-verified in September under `/home/cms/25G`, with
clean `cm_interface` v1.0.0/`8e56fdf24c038b64f69f26b55f0facb7c77e0537`.
The October deployment and user preference are recorded above.
See
`docs/all-links-v2-timed-tests.md`.

The q121--q123 FireFly gate failed twice. Run3 had F1 errors on lanes 1/3/4/6
and three F2 lane4 errors. One authorized 90-second repeat, run4, reproduced
the same four F1 lanes with 104/400/306/15 errors; F2 was then 12/12 clean.
All lanes stayed locked with zero native losses. Both endpoints are now
healthy IDLE/session-off at seq/ack12, run4. The repeat is consumed.
Q121--q124 are confirmed as independent same-endpoint self-loopbacks on both
F1 and F2, so the symmetric launcher and both sites' results are applicable.
A later q121--q124 run5 passed q124 and q123 at both sites and all 16 F2 lanes;
F1 again failed only q121/q122 lanes 1/3/4/6 (56/172/84/10 errors). All stayed
locked with zero native losses. Final F1/F2 are healthy IDLE/session-off at
seq/ack15, run5; this run is consumed.

## Historical live hardware — all-direct v12 scoped gate passed

The symmetric audited v12 / `0x00020409` image was previously loaded on both FPGAs. Full
simulation, compressed implementation, and independent routed audits pass at
WNS/WHS +0.019/+0.006 ns. BIT/DCP/ELF hashes are `5bce7351...c5697`,
`68d0e053...4260`, and `a2370f4b...c163`. Both sites passed fresh sequence/run
1 all-56-lane 10-second PMA gates. One simultaneous bidirectional external
sequence-3/run-2 window passed all 54 fitted receive lanes per site with zero
errors and zero native lock losses. Both sequence-4 stops passed and preserved
the publications.

Its final F1 and F2 state was healthy IDLE at sequence/ack 4, run 2, state00100000,
with TX sessions off and no retained fault. Every v12 stage is consumed: no
replay, reload, reset, or later request. This is full fitted-link functional
coverage, not long-BER or channel requalification. Authoritative record:
docs/direct-all-v12-hardware-gate.md. Exact artifacts and cited evidence are
frozen under build/diagnostic_archive/direct-all-v12-0x00020409-scoped-pass/.

## Historical resume point — v6 direct-quad scoped gate passed

F1N/q222 `0x00020400` and F2I/q233 `0x00020403` loaded; physical lane order
reversed. Compressed builds/audits pass. Both PMA gates and two overlapping
bidirectional10s PRBS31 runs pass all8 lane records with zeroerrors/native
losses. Final both seq/ack5,run3,healthyIDLE,sessionsoff,clocksvalid,nofault.
All sequences1–5/runs1–3 consumed; no replay/reload/reset/new request. Earlier
F2 no-lock and lane105 saturated-error attempts preserved. One-quad category
coverage only; expansion/all-channel/long BER remain separate decisions.
docs/v6-direct-quad-qualification.md is authoritative.

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

ONE-HOUR all12 PRBS31 soak RUNNING; userauthorizedduration3600000ms. Detached
Apollo worker108549 ownsMCU monitoring/cleanup. F1session10,F2session13,
F2RXseq14/run4pending; confirmedstate00120002,ack13,publishedrun3. Start
consumed, no replay/reset/reload/concurrentUART. Use launcher status-soak1h
log-only. docs/firefly1-v5-soak1h.md has evidence andprotocol; finalresultpending.

LATEST: twoall12 ten-second externalPRBS31 gatesPASS, includingX0Y13,
zeroerrors/native losses,summary000C0C01. FinalF1seq/ack9run0,F2seq/ack12run3,
bothhealthy IDLE,PRBSsessionsoff. Newall12 start/repeat consumed. No rebuild,
reload or drivesettingchange. docs/firefly1-v5-all12.md has full evidence.
Longer soak remainsproposed,notstarted. Earlier reduced-mask notes historical.

CURRENT: revised eleven-lane receive diagnostic PASS, summary000B0B01,
zeroerrors/native losses,stable publication. F1seq/ack5run0,F2seq/ack6run1,
bothhealthy IDLE,PRBSsessionsoff. RSSIroseall12channelsby5.246s; one-second
hardgate waspremature. No newfirmware/swingchange needed. Lane9excluded,
notfullqualification. Approved start-receive consumed; preserve state.
Details docs/firefly1-v5-managed-oneway.md. Following pre-gate notes historical.

Latest test failed the RSSI pre-gate: Rx06/07/08/09/11 did not rise in the
one-second TX-on sample. No receive request. Both sessions safely stopped;
both seq/ack3,run0,healthy IDLE,TX off. New managed-oneway start consumed.
Module channel/output disables0000. Investigate drive24 versus golden9 and
uncharacterized RSSI settling before another reviewed stimulus. Details in
docs/firefly1-v5-managed-oneway.md; no proof of BER failure/broken links.

User deferred golden-capture tooling and requested audited v5 on both ends.
Both programming completion markers and fresh MCU identities verified:
FW/HW20304,seq/ack/run0,healthy IDLE,TX off,no faults,required clocks valid.
See build-state.md for program/status evidence. Raw F2 RSSI with F1 TX off
is 0–61.2uW: an off-reference, not active-PRBS evidence. Next is a new bounded
TX/RSSI comparison and matching one-way F2 receive test; old sentinels remain
consumed. Golden-F1 launcher assumptions must be revised for two-v5 operation.

## Historical golden comparison

User manually loaded golden IBERT on F1/F2, superseding v5 live state.
Actual optical test wiring is one-way F1_1 TX → F2_1 RX. F1 quads121–123
pass PMA PRBS31; eleven F2 external links work at TXDIFFCTRL01001 (GUI630 mV),
zero pre/postcursor. F2 X0Y13 fails externally but passes local near-end PMA
PRBS31. Its corresponding optical Rx02 remains weak at61.2 µW. Do not claim
a specific faulty component or that this completely explains v5 acquisition.

Channel mapping established by raw single-channel disable/RSSI sweeps plus
user GUI observation: optical Rx00→X0Y15, …, Rx11→X0Y4; logical test lane
equals11-optical channel. Rx02→X0Y13 is ordering/exclusion, not a new
transition on an already failed link. MCU RSSI labels match datasheet channels;
earlier suggestion of reversed MCU labels was wrong. Every disable mask was
restored/read back0000. User confirmed all formerly working links recovered,
with no new errors after clearing IBERT counters. Rx11's last direct RSSI
remained42.7 µW; it was not reread after that GUI confirmation. No timed
golden BER/bit-count baseline was archived. Verify final GUI loopback modes
before any future external test, especially X0Y13 after the PMA check.

Reviewed minimal next step: preserve a timed golden reference and configuration,
compare GT settings and simulate existing v5 at mask0x0DFF excluding lane9.
After prerequisite GO, user authorizes F1 to remain golden and F2-only loading
of the exact audited v5 followed by a new fixed one-way diagnostic. The new
launcher is offline-tested and review-held; verify JTAG numbering with golden
F1 before programming. No new hardware test has run. Defer TX fault-policy
redesign and a new bitstream until evidence requires them. Full twelve-lane
qualification remains blocked. Do not rerun consumed
v5 scripts or infer a reverse optical connection. Details/evidence:
docs/firefly1-rx-channel-mapping.md, docs/firefly1-v5-tx-session.md.

cm_interface audit completed in docs/cm-interface-datasheet-audit.md. Source:
/nfs/cms/tracktrigger/wittich/int_test/cm_interface; actual PDF directory:
/nfs/cms/tracktrigger/wittich/datasheets. No library fixes applied. Use exact
x12 Rev4 manufacturer addresses rather than wrong RX enum/JSON definitions.

## Historical v5 gate (before manual golden programming)

V5 (`0x00020304`) implements independent, bounded PRBS31 TX sessions and
separate RX measurements. Simulations, compressed checkpoint-assisted build,
independent audit (+0.372/+0.003 ns), and both PMA hardware gates pass.
The first external dual gate FAILED: F2 retained a 10-second LOCK_WAIT
timeout; F1 measured small errors on lanes 1/3/4/6. No second baseline/retry.
At that gate both TX sessions were off: F1 healthy IDLE at sequence 5/run 2
with failed measurement retained; F2 platform fault at sequence 3/run 2.
Those live states have since been replaced by golden; raw evidence remains.
Aggregate PRBS fault still stops TX, so peer-error contamination is possible;
initial F2 acquisition cause is unresolved. Later one-way wiring evidence
means the proposed F2-TX-shutdown explanation for F1 errors was not established.
Fixed optical controls match;
installed sparse tf registry renumbers physical endpoints, so do not use its
labels for FireFly reads. V5 is not qualified; preserve archived evidence. See
`docs/firefly1-v5-tx-session.md` and `docs/memory/build-state.md`.

Historical v4 gate/design decision:

F2 PMA gate subsequently passed at run 1, twelve equal clean records and
healthy IDLE. F1 unchanged at run 1; no optical test. Dual-engine simulation
confirms peer TX can shut off before the later receiver finishes, so a
bounded transmit-hold/new-version design or validated alternative precedes
bidirectional external qualification. See `docs/firefly1-v4-f2-bringup.md`.

Historical pre-gate bring-up:

F2 now also runs the final v4 bit: fresh IDLE/run 0, matching version and
healthy required clocks. F1 remains at passed run 1. User confirms 12-channel
Fireflies wired F1↔F2 quad-to-quad and matching clocks. F2 programming and
read-only verification completed; no new PRBS request. See
`docs/firefly1-v4-f2-bringup.md` before subsequent work.

## Historical development branch: FireFly-1 functional PMA loopback

The preceding v4 work (`0x00020303`) forwarded the staged-acquisition parameters
that the native wrapper previously ignored, and expose retained first-fault
diagnostics through FE. Physical P/N connections and polarity remain unchanged.
V3 consumed sequence 1 with `0x0c000c04`/PRBS fault `0x80`; its detail words
were tied low and lane records synthetic. Neither reset-done failure nor a
polarity cause was established. The initially proposed v4 P/N swap was
withdrawn before implementation. User authorized continued correction,
simulation/build/audit and hardware testing on 2026-09-16. Fixed v4 launcher
and programmer prefixes are approved; see the top of build-state.md.
The first clock-repaired v4 revision failed its PMA hardware gate. The final
clean-synthesized continuity/reset-ack repair passes full regression, routed
audit, and the twelve-lane PMA gate; F1 is healthy IDLE at sequence/run 1,
summary 0x000c0c01, zero errors/losses and no retained fault. Exact revision
hashes and preserved evidence are in
`docs/firefly1-v4-repair.md`; do not infer current readiness from older PASS logs.

V1 (`gt_test_firefly1_loopback_v1`, `0x00020300`) is invalid and must not be
programmed: the routed audit proved it implemented q124 rather than FireFly-1.
The separate replacement is `gt_test_firefly1_loopback_v2` / `0x00020301`.
It forwards `FIREFLY1_FUNCTIONAL` through the isolated board wrapper, uses one
q121 REFCLK buffer in the functional group (rather than a second monitor
buffer), and imports the generated Wizard placement XDCs for q121--q123.
The matching v2 firmware and compressed bitstream are built (SHA-256
`ff01323bc6f96ea3caaef2c6ce3d94c6371c152a9cb3dead0e695a860f87219e` and
`098cf83f130fca3e5c084065f9aa3bf47655f399a45bb52d4b3f09a7ee06e4a9`,
respectively).  Its 2026-09-16 attached-session routed audit passed exact
q121--q123 ownership, routing, timing, and error-severity DRC checks (the
existing RPBF-3 I2C warning remains). V2-specific hash-pinned programming and
fixed functional-test helpers were used for the single authorized hardware
gate; never substitute the forbidden v1 FireFly script or artifact.

V2's sole fixed hardware gate (sequence/run ID 1) completed normally but
failed five of twelve lanes: 0, 1, 2, 5, and 6 saturated PRBS errors, while
3, 4, and 7--11 were clean with zero lock losses. The final retained
post-result `0x20` RX-reset-done platform fault is distinct from the
measurement result. No retry, reload, or reset is permitted. The generated
functional Wizards disable both RX and TX polarity-control ports, making an
unmodelled per-lane polarity correction the leading hypothesis; do not treat
it as confirmed without a separate corrected build and hardware authorization.

Historical resume point: the user manually loaded audited full v15 /
`0x0002000F`
after the automated XSDB/XVC programming path repeatedly failed to complete.
The F1 mailbox then verified v15, and unique fixed external sequence/run IDs
1 and 2 passed with four equal nonzero lane records, zero errors, zero native
lock losses, and final healthy IDLE at ID 2. Do not repeat, reset, reload, or
launch a new v15 request without explicit direction. The automatic programming
failure remains a separate XSDB/XVC tooling issue; see
`docs/v15-programming-interface-failure.md`.

Historical resume point: full v14 / `0x0002000E` was built and independently
audited but not programmed. It disables only full v13's planned external-
startup full-quad restart. V13 had two independent fresh failures before RUN
and F1 remained in that preserved retained-fault state. The next authorized
hardware step at that time was a serialized v13 preservation preflight, hash-pinned v14
programming, and exactly one fresh v14 external request; no v13 retry. See
`docs/v14-no-startup-restart-diagnostic.md`.

## Historical full-Milestone-3 resume snapshots

The statements in this section describe their recorded points in the full-M3
campaign; they do not describe the current all-direct v12 hardware.

- Full v14 / `0x0002000E` is a one-variable, unqualified diagnostic. Its
  compressed implementation and independent routed audit pass at WNS/WHS
  `+0.222/+0.009 ns`, zero routing/DRC errors, all four bus-skew constraints,
  all 16 descriptor bounds (worst `+2.155 ns`), 112 GT owners, golden managed
  properties, profile/runtime structure, and physical-only heartbeat fan-in.
  It changes only `EXTERNAL_STARTUP_QUAD_RESTART=0` from full v13. Do not infer
  a qualification result, missing-RXUSRCLK2 result, or optical/native-lock
  result from it. Artifact hashes and procedure are in
  `docs/v14-no-startup-restart-diagnostic.md`.

- At that point F1 retained a full-v13 platform fault after two independent,
  freshly programmed external requests failed pre-RUN with `0x04000404`.
  The plan preserved the results and serialized health evidence before v14
  reconfiguration. Do not repeat either v13 request. The first v14 run must
  use a new sequence and one run-ID increment; preserve its result before any
  reset, retry, or reconfiguration.

- A later isolated-target state was v275 / 2.5.25 healthy IDLE after the fixed
  unique sequence/run-ID-3 12-hour external soak passed. Final FPGA temperature
  was
  24.5 C, raw/unvalidated F1 AVTT current -0.6494140625 A, and required clocks
  were healthy. Do not invoke the consumed `start` or `results` operations
  again, reload, reset, or retry. See
  `docs/v275-qualification-candidate.md`.

- Historical v274 / 2.5.24 (`0x00020118`) is built and independently audited.
  It preserves v273 and enables a controlled monitor-input heartbeat
  suppression while leaving physical RXUSRCLK2 running. Full simulation,
  compressed implementation, and routed audit pass at WNS/WHS
  +0.009/+0.001 ns with zero routing/DRC errors. Explicit routed fan-in proves
  the control reaches the heartbeat synchronizer. Existing CDC/methodology and
  absent bus-skew-constraint caveats remain. The hardware gate passed without
  retry: clean sequence/run 1 had four zero-error profiles; sequence/run 2
  retained one clock-only stage-27 event after about 119 ms, restored the test
  control, kept the physical managed clock at 322.260 MHz and the quad READY,
  and measured only the expected two-cycle lane-15 toggle pulse. F1 retains
  v274 sequence/run-ID 2. See `docs/v274-heartbeat-test.md`.

- Isolated v273 / 2.5.23 (`0x00020117`) preserves the v272 detector and enables
  one planned coordinated full-quad restart after external controls settle.
  Full simulation, compressed build, and independent routed audit pass at
  WNS/WHS +0.009/+0.001 ns with zero routing/DRC errors. Two consecutive unique
  10-second F1 baselines passed without reload/retry. Each recorded cause 4
  startup plus cause 3 cleanup, no reactive cause-2 recovery, four complete
  clean profiles, zero native lock losses, and no trace overflow. The narrow
  startup test is conclusive in favor of the planned restart. Sequence 3 was a
  preserved clean no-stimulus run after the watcher safely refused a launcher
  race. Race-free sequence 4 recorded exactly two lane-12 error cycles without
  an integrity event. Sequence 5's 250.304-ms channel-0 disable retained one
  lane-12 integrity event, no shared-clock cause, and fault stage 27.
  `RXPRBSLOCKED` was asserted on every lane at first fault, then fell when the
  fault disabled the checker; the quad remained READY without a reset. The
  final `0x280c`–`0x280f` publications are synthetic platform-failure records,
  not measured lock-loss counters. This
  passes the lane-data gate but is not full qualification. At the end of v273,
  F1 retained the sequence/run-ID-5 platform fault; the later v274 gate above
  supersedes that state. See
  `docs/v273-planned-startup-restart.md`.

- The accepted v272 100-ms policy and v273 planned-startup behavior are now
  frozen in v275. V274 validated controlled monitor-heartbeat absence; actual
  missing physical RXUSRCLK2 remains untested. The historical retained v274
  fault was cleared only by the explicitly authorized v275 programming above.

- V272's lane-data runtime-integrity hardware gate passed. Sequences/run IDs 1
  and 2 measured all four lanes cleanly for 10 seconds, but each needed one
  bounded acquisition recovery and therefore failed the no-recovery baseline
  criterion. After explicit continuation, sequence 3's watched two-cycle
  lane-12 pulse did not trip the detector. Sequence 4's 0.250289-s F1_5
  channel-0 disable retained one lane-12 integrity event, fault stage 27, and
  response/summary `0x04000404`; adjacent lanes, shared-clock cause, and native
  lock-loss counts stayed clear. FireFly byte 86 was restored. Missing
  RXUSRCLK2 remains untested, and this is not an optical LOS/CDR-loss claim.
  V272 is not fully qualification-ready because both clean baselines required
  recovery. One later authorized same-image reload cleared the fault. A single
  fresh sequence/run-ID-1 request reproduced the acquisition recovery with all
  native lock/reset/clock qualifiers healthy, all four lanes observed error-
  active, and zero aggregate clean cycles for 100 ms. The restart recovered and
  measurement passed; no retry followed. F1 was then v272 healthy IDLE at
  sequence/run ID 1. The explicit v273 experiment above subsequently resolved
  the narrow policy decision without changing v272.
  See `docs/v272-hardware-gate.md` and
  `docs/v272-startup-recovery-investigation.md`.

- Isolated v272 / 2.5.22 (`0x00020116`) is frozen, built, and independently
  audited with runtime integrity enabled only there. Full regression, firmware,
  compressed incremental implementation, timing/routing/DRC, detector
  structure, profile-source structure, and all 16 descriptor bounds pass.
  WNS/WHS are +0.018/+0.001 ns; routing and DRC errors are zero. Existing
  unrelated CDC/methodology caveats and absent isolated-target bus-skew
  constraints remain. The subsequent hardware result is summarized above. See
  `docs/v272-build.md`.

- V271 threshold characterization now passes. Sequence 5 disabled only F1_5
  channel 0 for a measured 250.280 ms. Lane 12 recorded one uninterrupted
  3,133,090,464-cycle (~9.72-s) error run; lanes 13–15 stayed clean and every
  native lock-loss count remained zero. Byte 86 was restored to `00`, power
  remained clear, and sequence 6 then passed cleanly on all four lanes. F1 was
  v271 healthy IDLE at request/response/run ID 6 before v272 programming. The
  100-ms consecutive-error
  threshold is accepted for initial v272; missing shared RXUSRCLK2 was not
  exercised. The distinct v272 build/audit gate above now passes.
  Required clocks were in range, F1_5 was 38 C, and regulator status was clear.
  The FPGA SysMon temperature helper did not complete, so no final FPGA
  temperature was recorded. Keep all MCU-UART board diagnostics serialized;
  one attempted parallel preflight caused two read failures but made no writes,
  and the complete serialized preflight passed before sequence 5.
  See `docs/v271-firefly-threshold-characterization.md`.

- The shared source contains a default-off runtime-integrity detector. It
  is armed only by registered `measurement_enable`, uses the accepted lane
  mask, asserts on 100 ms of consecutive synchronized PRBS-error activity or
  100 ms without the shared RXUSRCLK2 heartbeat, and retains distinct causes
  in selector `FD` capability bit 1/words 6–7. Fault stage 27 follows the
  existing platform-fault path; native lock-loss semantics are unchanged.
  Standalone, controller, and full engine regressions pass, including rejection
  of the v271 two-cycle transient and atomic failed-result publication. This is
  enabled only by the v272 target; historical targets remain disabled. The
  v272 firmware/build/audit and lane-data hardware gates pass. The shared-clock
  branch has no hardware result, and repeatable acquisition recovery prevents
  a full qualification claim. See `docs/runtime-integrity-candidate-design.md`,
  `docs/v272-build.md`, and `docs/v272-hardware-gate.md`.

- Isolated diagnostic v271 / 2.5.21 (`0x00020115`) now carries the
  zero-elapsed-profile repair. Full simulation, compressed incremental build,
  and independent routed audit pass. WNS/WHS are +0.018/+0.001 ns; routing and
  DRC errors are zero. All 16 descriptor bounds pass (worst +1.568 ns), and
  every profile measurement/epoch first stage has a direct registered source
  with no combinational fan-in. Existing non-profile CDC/methodology caveats
  remain; there are no bus-skew constraints. F1 was then programmed with the
  exact audited image and passed two consecutive unique 10-second external
  baselines without reload/retry. Both toggle phases yielded four equal,
  nonzero profiles, zero errors/losses and 93/104 trace events without
  overflow. Sequence 3 then recorded a two-cycle lane-12-only pulse in a full
  nonzero profile, retained the entire publication unchanged for about 158
  seconds in IDLE, and clean sequence 4 replaced it normally. At that gate F1
  was v271 healthy IDLE at sequence/run ID 4; sequences 5 and 6 above
  supersede that state. This supports the profile repair in
  hardware; it is a diagnostic gate, not qualification. See
  `docs/v271-build.md`, `docs/v271-hardware-baselines.md`, and
  `docs/v271-profile-hardware-gate.md`.

### Historical resume snapshots

Everything below this heading is chronology, not the active resume state.
Older “latest,” “next,” “pending,” and sequence instructions are preserved as
historical evidence and do not supersede the all-links v2 resume point above.

- Historical timed-alarm state was F1 v270 (`0x00020114`) IDLE at sequence/run
  ID 1. No programming, new request, or module write was performed while
  applying the RTL repair.

- Shared F1 reset now reported complete. Post-reset module/FPGA captures saved
  under `build/diagnostic_archive/after-shared-reset-*`; all ten module reads
  succeeded, sampled controls unchanged. Our raw x4 bytes 3/5 remain FF/FF,
  but user reports CDR_LOL=FF and LOS=00. Reconcile exact module/address/display
  before interpreting alarms or issuing baseline 4. No new run or FPGA reload.
  Earlier pending-reset instructions below are historical.

- Await user-operated shared reset of **all F1 Fireflies**, not just F1_5.
  Pre-reset FPGA result/trace and all ten physical F1 device endpoints saved
  under `build/diagnostic_archive/before-shared-reset-*`; no read errors.
  Both x4 devices show `FF/FF`, outputs enabled, page zero. FPGA remains v270
  healthy IDLE/run 3; temperatures F1/F2 25.5/24.5 C. Agent performed no reset
  or new run. User confirms FF-page accesses are fresh reads; MCU-source
  review is not required. After reset confirmation, compare all module
  controls/alarms and FPGA state, then a clean baseline without reprogramming.

- Historical F1 state: v270 / 2.5.20 (`0x00020114`), healthy IDLE at
  sequence/run ID 3.
  Pulse characterization passed: exactly one lane-12 toggle request, two
  RXPRBSERR-active cycles on lane 12 only, zero lock losses, one cleanup,
  103 trace events/no overflow. Native longest/span 2; management error_seen
  already `0xF` during measurement and cannot timestamp this pulse. F1 26.0 C
  pre/post, power statuses clear. No fourth run or optical disable. Optical
  stage paused until FireFly `FF/FF` is resolved; individual/block reads agree,
  page zero, identity B0425040011201. Need authoritative map / MCU read path.
  Next sequence would be 4 after 3 / run ID 4 if unchanged. See
  `docs/v270-pulse-characterization.md` for evidence and hashes.

- Previous baseline gate (superseded as a resume point by run 3 above):
- F1 now runs v270 / 2.5.20, FW/HW `0x00020114`, healthy IDLE after
  request/response/run ID 2. Two 10-second four-lane external baselines passed
  with no reload: all lanes selected, zero errors/losses, one cleanup restart
  each, 103/108 retained trace events, no overflow. Both handshake phases
  exercised. No fault stimulus or third run. `docs/v270-hardware-baselines.md`
  records evidence and hashes. Next: lane-12 bounded pulse characterization,
  sequence 3 after 2 / expected run ID 3 if state unchanged. Resolve FireFly
  `FF/FF` before optical stimuli; qualification remains deferred.

- Source-stage follow-up: `docs/descriptor-transfer-repair.md` records the
  implemented extra request stages, latched accepted mode and publication mask
  check. Skew/integrated/core/Python regressions pass.
  V270 / 2.5.20 (`0x00020114`) now builds/audits successfully with all 16
  descriptor endpoints timed at 3.000 ns (worst slack +1.568 ns), not hidden
  by clock-group exceptions. Compressed, WNS +0.325 / WHS +0.001 ns, zero
  routing/DRC errors, correct GT sites and 100/325-MHz clocks. Build 11m14s;
  90.74% cell / 76.42% net reuse. See `docs/v270-build.md`
  for artifact hashes and remaining CDC/methodology limitations.

- Historical F1 v269 / 2.5.19, FW/HW `0x00020113`,
  request/response/run ID 1, engine IDLE. First 10-second external baseline
  **failed**: requested mask `0xF000` confirmed at MCU and AXI, but lane 12
  published unselected; summary `0x00030301`. Lanes 13–15 had zero errors/losses.
  No second v269 run or injection occurred; later replaced by audited v270.
- V269's 256-entry trace retained all 127 events, epoch 1, no overflow, stable
  readout. FD counted two completed restarts (acquisition plus cleanup), not
  the required single cleanup. V268's preceding clean run overflowed its
  64-entry trace at 107 events; do not confuse these version-specific records.
- `sim/tb_gt_lane_descriptor_skew.sv` reproduces start acknowledgement with
  stale selection after one extra descriptor capture cycle. Core launches
  active descriptor and start together; lane consumes separately synchronized
  values without an explicit bundled-data settling/acceptance guarantee.
  This is a demonstrated RTL defect consistent with, not definitive proof of,
  the hardware cause. Source repair status is summarized above.
- At the v270 gate, the two baseline prerequisites were satisfied and runtime-
  integrity thresholds remained deferred. V271 later accepted the 100-ms
  consecutive-error threshold; v272 freeze/build/audit has since passed. Earlier
  reset-phase regressions passed but did not cover this skew.
- Last F1 FPGA temperatures: 25.5 C preprogram and post-run 2. Supply status
  clear; negative regulator current readings are raw/unvalidated. FireFly was
  38 C afterward, byte 86 zero, alarm bytes 3/5 repeatedly `FF/FF` even after
  read-to-clear. Resolve this before interpreting optical stimuli. Do not
  confuse FPGA, FireFly and regulator temperatures; the historical `0x77`
  overtemperature was FPGA, not FireFly.
- Hardware access: `ssh -o ProxyJump=lnx4189 cms@apollo3010-1`; remote checkout
  `/home/cms/25G/cm_interface`, UART `/dev/ttyUL4`. Apollo does not share the
  local filesystem. Local API checkout: `/nfs/cms/tracktrigger/wittich/int_test/cm_interface`.
  Run XSDB on **lnx4189**, `connect -url TCP:lnx4189:3121`, not `-host`.
  Last chain: F1 target 1, running MicroBlaze 3, F2 target 4; re-enumerate before
  any write. Keep MCU I2C5 semaphore/mux discipline. Use JTAG SysMon via
  `scripts/read_hw_temperatures.tcl`; installed MCU rejects newer telemetry API.
- V269 incremental build/audit passed, compressed, WNS +0.122 / WHS +0.001 ns,
  zero routing/DRC errors. Build 10m57s versus v268 14m41s (different RTL, not a
  controlled benchmark), 82.08% cell / 65.44% net reuse and nine cached IP runs.
  Separate clean-build path is unexecuted. No global CDC or bus-skew signoff
  follows from that audit; the isolated target has no bus-skew constraints.
- Authoritative details: `docs/v269-hardware-baseline.md`,
  `docs/incremental-diagnostic-builds.md`, `docs/memory/build-state.md`.
  Version-prefixed raw evidence is under `build/diagnostic_archive/v269-run1-*`;
  Apollo originals are `/tmp/v269-diagnostic-20260912/`. Historical archives
  are immutable identities, not reproducible by rerunning old Tcl with new RTL.

The sections below retain earlier design/history context. Their older "next"
steps do not supersede this resume point. Golden IBERT, isolated diagnostics,
full-M3 v12 (unqualified), and historical v11 soak evidence remain distinct.

## Repository and sources

- Tool: Vivado 2023.2; part `xcvu13p-flga2577-2-e`; top `src/top.sv`.
- Board schematic: `/nfs/cms/tracktrigger/wittich/Cornell_CM_Rev3_HW/Schematic/6089-127-RevA_23Jan2025.pdf`.
- Canonical board XDC: `/nfs/cms/tracktrigger/wittich/Cornell_CM_Rev3_HW/Vivado/constraints/VU13P_pins.xdc`.
- Keep generated `build/` products out of Git. Reproduce builds with Tcl scripts.

## Stable design facts

- Both IBERT cores contain 14 GTY quads, 56 channels each, for 112 `GTYE4_CHANNEL` instances total.
- FireFly and FPGA-to-FPGA links use 25.78125 Gb/s from 322.265625-MHz REFCLK0. The 10-Gb/s AXI C2C lanes are excluded.
- FF3 is physically reversed at the wrapper boundary: schematic page 64 maps board lane 11 to GTY128 channel 0 and lane 0 to GTY130 channel 3. Reverse both 12-bit FF3 RX and TX segments while retaining board lane numbering in the XDC.
- FF6 RX lane 1 is the bonded `M48`/`M49` pair from schematic page 67. The canonical XDC's obsolete `N48`/`N49` assignments are commented out.
- The repository and canonical XDC have 520 matching shared active assignments; the FF6 bonded-pin correction is intentionally repository-only.
- In VHDL IBERT port maps, pack or unpack vectors outside the map and associate each formal once. Repeated slice associations cause Vivado Synth 8-5838.

## Clock architecture

- The board 200-MHz clock drives the frequency monitor, I2C, and SysMon logic.
- A dedicated `BUFGCE_DIV` divides the raw board clock by four. Its 50-MHz output drives the distributed IBERT debug hub and XSDB/DRP register fabric, matching the vendor example clock expectation.
- Keep the divider output with `(* KEEP = "TRUE" *)` because the debug hub is inserted through XDC after synthesis.
- A `MMCME4_BASE` with a 1300-MHz VCO generates `clk_100` and `clk_325` from
  the 200-MHz board clock. The routed clock report must show 10.000-ns and
  3.077-ns periods respectively.
- Do not hard-wire GTY `SDM0WIDTH` or `SDM0DATA`. IBERT drives these from XSDB registers for runtime QPLL fractional-N configuration; Vivado's generated-clock warnings are conservative consequences of dynamic controls.

## Management interfaces

- The generic I2C register slave uses 7-bit address `0x2B`. Registers are
  byte-addressed, little-endian 32-bit words.
- The MCU ABI is fixed: `r00`/`0x00` and `r01`/`0x04` are scratch registers;
  `r02`-`r38`/`0x08`-`0x98` contain the 37 clock readings in the README order;
  `r39`/`0x9C` is status.
- Status is `[31:16]=0x434D`, bit 15 measurement-valid, `[14:8]=37`, and
  `[7:0]=1`. A valid status word is `0x434DA501`.
- Frequency values are kHz and are never multiplied by two. A nominal
  322.265625-MHz reference clock therefore reads about `322266`.
- SysMon PMBus addresses are SLR0=`0x36`, SLR1=`0x34`, SLR2=`0x47`, and
  SLR3=`0x45`.
- Repository policy is that every new bitstream is compressed. The golden
  IBERT and Milestone 2 targets each set `BITSTREAM.GENERAL.COMPRESS=TRUE` in
  their target-specific XDC, and every bitstream-producing build script rejects
  a generated design if that property is not active.

## External board MCU integration

- The external board-MCU codebase is the public
  `apollo-lhc/cm_mcu` GitHub repository. Its primary runtime binary is built
  from `projects/cm_mcu` for the TI TM4C1290NCPDT using TivaWare and FreeRTOS.
  Do not confuse this firmware with the FPGA-resident MicroBlaze supervisor.
- On Cornell rev3, FPGA register traffic uses MCU I2C controller 5. Both FPGAs
  sit behind TCA9548A mux address `0x70`: channel 2 (`0x04`) selects F1 and
  channel 0 (`0x01`) selects F2. The FPGA generic register slave is then at
  address `0x2B` with a one-byte register address and little-endian data.
- Follow `clk_freq_fpga_cmd()` in
  `projects/cm_mcu/commands/ClockCommands.c` for I2C ownership: obtain the
  I2C5 software semaphore, select exactly one mux channel, retain the semaphore
  for the complete multi-register operation, clear the mux, and only then
  release the semaphore. Cleanup must clear/release on every error path.
- Use the existing interrupt-driven `apollo_i2c_ctl_reg_r/w()` functions from
  `I2CCommunication.c`; do not bypass their persistent per-bus buffers,
  FreeRTOS notification completion, bounded idle wait, or timeout handling
  with direct TivaWare I2C calls.
- `/nfs/cms/tracktrigger/wittich/apollo_setup.sh` currently selects
  `/nfs/cms/tracktrigger/wittich/arm-gnu-toolchain-14.2.rel1-x86_64-arm-none-eabi/bin`.
  The compiler reports Arm GNU Toolchain 14.2.Rel1, GCC 14.2.1.
- A repository-local `cm_mcu` adapter draft was retired on 2026-09-23. It was
  never integrated upstream and was limited to the old Milestone-3 lanes
  12--15. Current host-side board access uses the pinned `cm_interface`
  checkout; retain the semaphore, mux-selection, commit-order, and run-ID
  coherency requirements above in any future external-MCU implementation.

## HDL-first migration architecture

- The experimental Milestone 2.5.1 target is a separate quad-124-only image
  with hardware/firmware identity `0x00020101`. It stages TX PRBS enable ahead
  of RX checker enable, qualifies a continuously locked and sampled-error-free
  millisecond, and resets acquisition counts before measurement. This mode is
  parameterized off for preserved v2.5 and full Milestone 3 until board tests
  prove or reject the hypothesis.
- Reproduce it with `scripts/build_milestone251_firmware.sh`,
  `scripts/build_milestone251_bitstream.tcl`, and
  `scripts/audit_milestone251_routed.tcl`. Hardware acceptance uses only
  `scripts/milestone251_acceptance.py`; keep that family separate from both
  historical-v2.5 and full-M3 scripts.
- The isolated Milestone 2.5.2 target is hardware/firmware `0x00020102`. It
  retains staged TX-before-RX enable but changes state 21 to a fixed 1-ms
  observation window. It retains sampled-error and sampled-unlock masks plus
  the maximum clean streak, clears the native counters, and always advances
  to measurement unless the enclosing operation timeout/platform checks fail.
  Only this target sets `REQUIRE_ERROR_FREE_QUALIFICATION=0`; existing targets
  retain the clean-gate default.
- Reproduce 2.5.2 with `scripts/build_milestone252_firmware.sh`,
  `scripts/build_milestone252_bitstream.tcl`, and
  `scripts/audit_milestone252_routed.tcl`. Hardware acceptance uses
  `scripts/milestone252_acceptance.py`, with
  `scripts/milestone252_platform_diagnostics.py` for non-destructive rereads.
  The routed image, audit, and complete five-job F1 board acceptance matrix
  pass. Every selected lane reported zero errors and zero lock losses in the
  first, repeat, four-lane external, PMA-loopback, and post-PMA external jobs.
  The post-run acquisition diagnostic fields currently clear in IDLE, so their
  printed zeros are not retained acquisition evidence.
- Milestone 2.5.3 is the diagnostic-lifetime-only follow-up, version
  `0x00020103`. It preserves fixed-window evidence through IDLE and clears it
  only when the next stable running mask is accepted. Its simulations, clean
  isolated build, independent routed audit, and focused one-lane F1 check pass.
  The hardware observation retained a full clean 200,000-cycle window with no
  sampled errors or unlocks, followed by a zero-error ten-second measurement.
  This is the accepted baseline to carry into full M3.

- Keep `src/top.sv` and the current 112-lane standalone IBERT build as the
  golden diagnosis and recovery target.
- The opt-in synthetic engine is composed of `gt_test_engine_core`, 112
  `gt_lane_engine` instances, `axi_lite_gt_test_engine`, and
  `gt_test_hardware_shell`.
- AXI descriptor registers contain opcode, PRBS selection, duration, timeout,
  and a 112-bit lane mask. A single doorbell launches the job; acquisition does
  not require CPU polling.
- Result publication uses two hardware-owned 112-by-256-bit banks. The active
  bank is hidden and the published bank remains immutable until the next
  completed atomic swap.
- I2C bytes `0xA0`-`0xFF` form the MCU/CPU mailbox. Firmware must validate and
  translate mailbox requests into the executable AXI descriptor and then wait
  for the completion interrupt.
- Synthetic RX clocks share the management clock, while Milestone 3 lanes
  12-15 use the managed quad's RX user clock. Their 256-bit snapshots cross
  through four `xpm_cdc_handshake` instances; a lane acknowledges stop only
  after management-domain capture. Control toggles and GT status use explicit
  two-flop synchronization.
- Milestone 2 adds a separate Tcl-generated 200-MHz MicroBlaze subsystem with
  32 KiB local BRAM, MDM/JTAG, embedded freestanding firmware, and the
  synthetic engine at `0x44A00000`. Because there is exactly one level
  interrupt source, it connects directly to MicroBlaze and no AXI interrupt
  controller is instantiated.
- The single engine interrupt is level-sensitive and uses standard MicroBlaze
  interrupt mode with the fixed vector at `0x10`. Low-latency vectored mode is
  explicitly disabled because this supervisor has no need for per-source
  hardware vectors.
- MicroBlaze discrete ports are enabled because the `sleep` instruction waits
  on the separate `Wakeup` input, not on `Interrupt` alone. `Wakeup[0]` is the
  engine interrupt and `Wakeup[1]` is MDM `Dbg_Wakeup`; the same engine level
  therefore wakes the sleeping processor and then enters the standard ISR.
- MicroBlaze uses no caches, MMU, UART, timer, or external memory. It retains a
  barrel shifter and MSR/interrupt instructions, uses software multiply, and
  exposes one 32-bit AXI4-Lite master. These choices keep it a deterministic,
  small supervisor while HDL owns acquisition timing and result storage.
- Vivado configures this MicroBlaze little-endian. The freestanding firmware
  must be compiled with `-mlittle-endian`; its build script checks the ELF
  header before it can be embedded. A big-endian ELF is not executable by this
  subsystem even if Vivado accepts it for BRAM initialization.
- Firmware polls only for a new MCU mailbox sequence while idle. After one
  descriptor and doorbell write it sleeps until the completion interrupt; it
  does not poll engine state during acquisition. Interrupts are masked across
  the completion-check/`sleep` boundary; the independent level-sensitive
  `Wakeup` input releases the CPU before firmware enables and services the
  pending ISR, preventing a lost-wakeup race for very short jobs.
- The Milestone 2 target drives both active-high board RGB LED triplets with
  the same status: pre-firmware blue heartbeat, solid blue while busy, green
  for firmware-alive/healthy idle, and red for a failed or rejected idle
  result. Green is gated by the firmware-version AXI write and therefore proves
  that MicroBlaze executed the embedded supervisor.
- The Milestone 2 image has passed its board I2C and MicroBlaze-halted
  completion tests. Managed quad 124 is therefore the next migration stage;
  its four FireFly 5 lanes must remain exclusive to either IBERT or the native
  GT wrapper in any one build.
- Milestone 3 acceptance includes staged quad-124 initialization,
  internal/external PRBS, targeted error and lock-loss injection, abort,
  timeout, CPU-halted completion, and one-hour, 12-hour, and 24-hour soaks.
  The managed mask is exactly global lanes 12-15 (`0x0000F000` in the low
  word); hardware must reject any descriptor selecting the other 108 lanes.
- Descriptor control bit 16 selects an HDL-generated 1-ms duration/timeout
  timebase. It allows one uninterrupted job of about 49.7 days while retaining
  200-MHz cycle mode for short tests and preserving CPU-independent timing.
  MCU automation may sequence and log jobs but must not own BER timing,
  counter acquisition, or silently retry failures.
- The isolated Milestone 2.5 target is `gt_test_milestone25_top`. It enables
  only physical quad 124 (`GTYE4_CHANNEL_X0Y16`-`X0Y19`) and instantiates no
  IBERT cores or other GT transmitters. The full `gt_test_milestone3_top`
  target uses the same four-channel 25.78125-Gb/s GT Wizard on `lf_r0_af` and
  leaves the other 108 lanes under IBERT. The validated isolated M2.5 and
  hardware-tested full-M3 artifact is `0x00020004`; the later historical
  full-M3 v12 development candidate is `0x0002000C`. It preserves the v11/2.5.3
  fixed acquisition observation and retained diagnostics, and adds native
  per-lane `RXCDRLOCK` to runtime lock qualification without changing the MCU
  ABI. The managed mask is exactly low-word
  `0x0000F000` and all other lane-mask words zero.
- The quad controller performs reset hold and bounded power/QPLL/user-clock/
  reset-done qualification. An intentional runtime RX reset enters bounded RX
  requalification without dropping `quad_ready`; all other qualified losses
  remain fatal. Platform readiness is required at the AXI doorbell. AXI
  `0x070` exposes state/ready/fault plus an eight-bit latched fault reason.
- Native TX PRBS error injection uses W1-toggle AXI offsets `0x060`-`0x06C`;
  hardware masks writes so only managed lanes can change.
- Near-end PMA loopback at 25.78125 Gb/s selects `LOOPBACK=010` and performs
  the bounded `GTRXRESET`/`RXPMARESET` sequence. External-path mode retains
  `LOOPBACK=000` and keeps the already-live RX datapath out of reset. The quad
  supervisor qualifies expected RX-status transitions from the ARM interval
  through selected-lane lock in either mode, and both paths clear native PRBS
  counters once more after lock before measurement. At stop, the
  controller reads exact native
  `RX_PRBS_ERR_CNT` lower/upper words through DRP `0x25E`/`0x25F` for each
  selected lane; it no longer interprets `RXPRBSERR` assertion cycles as bit
  errors.
- The 2026-08-27 clean Milestone 3 build passes routed timing with WNS
  `+0.138 ns` and WHS `+0.008 ns`, has zero routing errors, passes all four
  bus-skew constraints, and is compressed. It contains 52 left-IBERT lanes,
  four exclusively managed quad-124 lanes, and 56 right-IBERT lanes. It is a
  board smoke-test candidate, not yet hardware-accepted.
- The final isolated Milestone 2.5 `0x00020004` image passed both external
  optical-loopback and near-end PMA-loopback one-second, four-lane PRBS31
  smoke tests with aggregate `0x00040401`, zero lane errors or lock losses,
  and healthy final `C8=0`.
- Qualification update (2026-09-02):
  `docs/evidence/legacy/Table.xlsx` records a
  fresh golden-IBERT Quad 124 external PRBS31 control with no internal
  loopback, locked PLLs, zero errors, and about `1.072e12` bits on each of
  `MGT_X0Y16`-`X0Y19`. A fresh preserved-v2.5 run made immediately afterward
  completed but saturated all four native error counters in one second.
  Therefore the current failure is reproducible in v2.5 and is not solely a
  v2.5-to-v10 regression; compare golden-IBERT and managed-controller PRBS
  acquisition sequences before changing the post-lock reset logic.
- The full Milestone 3 integration smoke test passed on 2026-08-27. The
  managed four-lane run returned matching response/run sequence 1, matching
  firmware/hardware summary `0x00040401`, and healthy final `C8=0`. Lane 12
  independently reported zero errors, zero lock losses, about 25.78 billion
  tested bits, and a normal stop. The other 108 IBERT-owned channels operated
  as before. Longer fault campaigns and soaks remain deferred qualification.
- CLI copy/paste write commands omit redundant leading zeroes; `i2cwr` pads
  values to the explicitly requested byte width.
- The one-hour data run completed on 2026-08-27 with matching request/run
  sequence 2, matching summaries `0x00040401`, and final `C8=0`. Lanes 12-15
  each recorded 92,810,902,916,320 tested bits, zero errors, zero lock losses,
  no saturation, and exactly 1,160,136,286,454 valid RX cycles. This gives a
  zero-error one-sided 95% BER upper bound of about `3.23e-14` per lane. The
  associated F1 AVTT-current and FPGA-temperature checks were normal.
- The five-minute lane-12 targeted-error test passed on 2026-08-27. XSDB
  toggled only AXI injection bit 12 while the engine was in `ST_RUN`; lane 12
  reported exactly one error and lanes 13-15 reported zero. All lanes had zero
  lock losses, no saturation, and identical internally consistent bit/cycle
  counts. Aggregate `0x01030401` and final `C8=0` confirmed one expected lane
  failure, three passes, four selected lanes, and a normal stop. The other 108
  IBERT-owned channels operated as before after the injection test.
- The explicit-abort test passed on 2026-08-27. Request/run sequence 4 was
  configured for five minutes and aborted through AXI doorbell bit 1 after
  about 62.06 seconds. Firmware/hardware summaries were `0x00040402`, final
  `C8=0`, and all four lanes had zero errors, zero lock losses, no saturation,
  and identical partial records: 1,599,903,348,640 tested bits and
  19,998,791,858 valid RX cycles. This proves synchronized stop, atomic partial
  publication, PMA cleanup, and healthy idle recovery after operator abort.
- The automatic-timeout test passed on 2026-08-27. A five-minute request with
  a one-minute timeout completed as sequence 5 with matching aggregate
  `0x00040403` and final `C8=0`. All lanes had zero errors, zero lock losses,
  and no saturation. Lanes 12, 14, and 15 recorded 19,335,605,203 valid cycles;
  lane 13 recorded one additional cycle and exactly 80 additional tested bits.
  Every record satisfied `tested_bits = valid_cycles * 80`, and the measured
  interval was 60.000 seconds at the observed RX clock.
- The Milestone 3 CPU-independence test passed on 2026-08-31. MicroBlaze was
  halted in its wait loop after launching MCU request sequence 6 and remained
  halted past the five-minute hardware completion. Following an FPGA reload,
  the independent hardware run counter correctly published first run `F8=1`
  with `FC=0x00040401` and retained interrupt status `C8=0x00004000`, while
  CPU-owned `F0=F4=0` remained untouched. Lanes 12-15 each reported
  7,734,239,847,600 tested bits, 96,677,998,095 valid cycles, zero errors and
  lock losses, no saturation, and exact 80-bit-per-cycle accounting. After
  XSDB resume, firmware acknowledged sequence 6 with `F4=0x00040401` and
  cleared `C8`; the hardware run ID and summary did not change.
- The first 12-hour external-path launch and a follow-up 60-second external
  smoke both failed immediately after an FPGA reload on 2026-08-31. The first
  attempt published request sequence 7, hardware run ID 2, summary
  `0x04000404`, mailbox state `C8=0x00010000`, and XSDB platform status
  `0xE1208085`; neither run entered `ST_RUN`. The external path had skipped
  the initial RX datapath reset that the passing PMA path performs.
- Full-M3 candidate `0x00020005` applied a bounded initial RX reset to both
  external and PMA-loopback acquisitions, preserves `LOOPBACK=000` for the
  external path, and retains the first PRBS-controller fault stage. Both
  controller unit simulations pass. Its routed build failed setup timing with
  WNS `-0.687 ns`, TNS `-942.105 ns`, and 3,745 failing `clk_200` endpoints;
  it must not be programmed.
- Candidate `0x00020006` retained the external reset fix and compile-time
  specializes the 112-lane architecture: full engines exist for managed mask
  bits, while IBERT-owned lanes use deterministic unselected protocol stubs.
  Expanding the mask in later milestones automatically restores full engines.
  Its implementation passed, and its first 60-second external smoke entered
  and completed `ST_RUN` normally. Lane 13 passed, while lanes 12, 14, and 15
  saturated their native PRBS error counters even though all four lanes were
  locked at stop with no lock-loss flags and identical measurement lengths.
  The controller reset those counters before lock acquisition and did not
  clear acquisition errors before starting the timed interval.
- Candidate `0x00020007` adds a second selected-lane PRBS-counter reset after
  all selected lanes lock and before acquisition-ready starts the measurement
  clock. Its 2026-09-01 full build and dedicated routed audit pass timing,
  routing, DRC, bus skew, compression, GT ownership/site, and managed-GT
  property checks. The 60-second external smoke is its hardware acceptance
  gate; only after that passes should the 12-hour external soak be restarted.
- Candidate `0x00020007` then timed out in external `ST_LOCK_WAIT` before the
  post-lock reset. Candidate `0x00020008` extends the bounded acquisition wait
  to ten seconds. It exposes live diagnostics at AXI `0x084`-`0x08C` and
  persistent first-fault snapshots at `0x090`-`0x09C`. I2C selector `0xFE`
  mirrors platform status plus these seven words through `0xD0`-`0xEC`,
  preserving per-lane lock history, reset/DRP qualifiers, quad qualification,
  stage, and elapsed cycles without changing the clock-monitor ABI.
  Engine, quad-controller, and PRBS-controller state values are externally
  decoded ABI fields. Keep `fsm_encoding="none"` on all three state registers;
  otherwise Vivado may legally recode them as optimization fanout changes.
- Candidate `0x00020008` then completed a 60-second external run normally but
  returned two passes and two failures: lanes 12 and 15 saturated while lanes
  13 and 14 had zero errors. Single-lane ten-second runs reproduced saturation
  on 12 and 15 with correct selection, lock, and healthy quad qualifiers. The
  all-lane diagnostic also captured partial running mask `0x7`. Candidate
  `0x00020009` removes external `GTRXRESET`, qualifies the supervisor directly
  from the engine ARM state, waits for a stable running vector, and excludes
  normal cleanup from persistent lock-loss history. PMA reset behavior and
  the post-lock counter reset remain intact.
- Candidate `0x00020009` passed its clean Vivado 2023.2.2 implementation and
  independent routed audit on 2026-09-01. Timing, routing, all four bus-skew
  constraints, compression, 112-channel ownership, managed quad-124 sites,
  golden managed-GT properties, and 100/325-MHz clock generation pass. Routed
  DRC has zero errors and only the established generated-debug/IP and
  generic-I2C warnings. The bitstream SHA-256 is
  `ded0954bf9c7bfadfac5d2ad3305bb9b38ffe5dc340aad4d29ccf9027cb1742d`.
  Its first lane-12 hardware launch nevertheless remained in ARM because the
  new stable-mask filter initialized its counter but did not increment it
  while the synchronized mask remained unchanged.
- Candidate `0x0002000A` adds the missing stable-mask counter increment and a
  bounded PRBS-controller testbench watchdog. The observed v9 diagnostics
  (`running=locked=0x1`, `selected=0`, controller IDLE, engine ARM, healthy
  quad) exactly match this deterministic pre-acquisition failure. Firmware,
  RTL compilation, and elaboration pass. Its clean Vivado 2023.2.2 build and
  independent routed audit passed on 2026-09-02: WNS `+0.238 ns`, WHS
  `+0.009 ns`, pulse-width slack `+0.247 ns`, all 785,339 routable nets fully
  routed, all four bus-skew constraints met with worst slack `+19.578 ns`,
  zero DRC errors, correct 100/325-MHz clocks, compression, GT ownership/sites,
  and golden managed-GT RX properties. Bitstream SHA-256 is
  `fa4042fd1def68935e34e5c4d282d5db7416cc1182518b3a46c4e2f5fb40d268`.
  It is ready for the lane-12 external diagnostic, followed by the all-lane
  60-second smoke, but is not yet hardware-accepted. Its first lane-12 run
  proved the ARM-progress fix and completed normally, but returned one native
  PRBS error with zero lock losses, no saturation, and exact 80-bit-per-cycle
  accounting. Repeat that test without reprogramming before advancing; a
  repeatable exact one count would point to the post-lock counter-reset to
  measurement boundary.
- Candidate v12 (`0x0002000C`) preserves v11 acquisition behavior and adds
  native per-lane `RXCDRLOCK` to measurement-time lock qualification. Its
  simulations, clean Vivado 2023.2.2 build, and independent routed audit pass:
  WNS `+0.141 ns`, WHS `+0.009 ns`, zero routing errors, all four bus-skew
  constraints met with worst slack `+19.437 ns`, exact 52+4+56 channel
  ownership, correct 100/325-MHz monitor clocks, and four routed CDR-lock
  synchronizer pairs. The 69,787,395-byte compressed versioned image is
  `gt_test_milestone3_v12.bit`, SHA-256
  `35e8ba4ec565c9972e72e3ebf61ee842fd446d2b51d35650f1d9ec2b76ca180f`.
  One post-reload ten-second PMA smoke and its following 60-second external
  smoke passed on F1 with zero errors and lock losses. Separate fresh/restart
  attempts failed acquisition in `LOCK_WAIT`, including a post-reload PMA
  attempt; every failure was preserved without a silent retry. After a later
  explicit reload, PMA and external gates passed again and the intended
  FireFly stimulus reached RUN. The module reported isolated RX0/TX0 LOS and
  RX0 CDR LOL, and lane 12 alone saturated its error counter, but native FPGA
  `RXCDRLOCK` remained asserted and the lane recorded zero lock losses. V12 is
  therefore build- and routed-audit-accepted, but not hardware-qualified.
- Candidate v11 (`0x0002000B`) promoted the isolated 2.5.3 behavior accepted on F1:
  staged TX-before-RX control, a fixed 200,000-cycle (1-ms) acquisition
  observation, a native-counter reset after the observation, and diagnostic
  retention through IDLE until the next stable running mask is accepted.
  Its clean full-image build and independent routed audit passed on
  2026-09-02: WNS `+0.250 ns`, WHS `+0.009 ns`, zero routing errors, all four
  bus-skew constraints met, exact 112-channel ownership, and correct
  100/325-MHz clocks. The versioned artifact is
  `gt_test_milestone3_v11.bit`, SHA-256
  `396e891f1df5ed079d892b0d59b5dbd35fef86bbda3877d05eb692c33da42449`.
  F1 short hardware acceptance passed on 2026-09-02: both the ten-second
  lane-12 external diagnostic and the four-lane 60-second external smoke had
  zero measured errors and zero lock losses. The four-lane result was
  `0x00040401` with `BER95 < 1.939e-12` per lane. Retained acquisition error
  masks (`0x1` and `0xF`) captured startup transients that were successfully
  excluded from measurement by the post-observation counter reset. The
  12-hour external soak passed on F1 as request sequence `4`, after sequence
  `3`, and completed at `2026-09-03T06:24:05+00:00`. Every managed lane had
  zero errors and zero lock losses over 1,113,730,526,168,800 tested bits
  (`BER95 < 2.694e-15`). The final response sequence was `4`, stable hardware
  run ID was `3`, response/summary was `0x00040401`, and the engine returned to
  healthy IDLE. The complete log is
  `docs/evidence/legacy/milestone3_12hour_soak_20260902_182351.log`. Final F1 AVTT current
  and FPGA temperature remain to be appended to the test record.
- `scripts/run_milestone3_12hour_soak.sh` is the unattended soak wrapper. It
  is POSIX `sh` and BusyBox `ash` compatible, must be executed rather than
  sourced, writes stdout/stderr to both screen and a timestamped log, checks
  status every 30 minutes for 12 hours, and collects final results. Its default
  request/previous sequences are `4`/`3`; the first three optional positional
  arguments override request sequence, previous sequence, and log path.
- `scripts/run_milestone3_24hour_qualification.sh` is the separate unattended
  extended-qualification wrapper. It is also POSIX `sh`/BusyBox `ash`
  compatible, checks status every 30 minutes for 24 hours, logs to screen and
  file, and collects final results. Its continuation defaults are request
  sequence `5` after `4`; without reprogramming, require hardware run ID `4`.
- The unattended 24-hour v11 external qualification passed. Final results in
  `docs/evidence/legacy/24hour.txt`, captured on 2026-09-10, show matching request/response sequence
  `5`, stable hardware run ID `4`, response/summary `0x00040401`, healthy IDLE,
  and zero errors or lock losses on lanes 12-15. Lanes 12-13 tested
  2,227,461,058,375,760 bits each and lanes 14-15 tested
  2,227,461,058,375,680 bits each, giving `BER95 < 1.347e-15` per lane. The SSH
  connection died, so no half-hour watcher output was retained. The exact
  completion timestamp, final F1 AVTT current, and FPGA temperature remain to
  be appended. At that point, the remaining campaign work was targeted
  measurement-time error injection, forced single-lane lock-loss isolation,
  abort/timeout, and CPU-halted completion; current outcomes follow.
- On 2026-09-11, v11 passed targeted lane-12 measurement-time error injection
  as sequence 6/run ID 5 with exactly one lane-12 error, three clean adjacent
  lanes, zero lock losses, and summary `0x01030401`. Explicit abort passed as
  sequence 7/run ID 6 with summary `0x00040402`; automatic timeout passed as
  sequence 8/run ID 7 with summary `0x00040403`. Both published coherent clean
  partial records. The next CPU-halted-test launch, sequence 9/run ID 8, failed
  before RUN with summary `0x04000404`: retained `LOCK_WAIT` diagnostics had
  selected/running mask `0xF` but locked/ever-locked mask `0xB`, isolating the
  missing acquisition to lane 14. Quad power/QPLL/clocks/reset qualifiers,
  monitored reference clocks, and F1 AVTT/CC PMBus status were healthy. The
  failure was preserved and not retried. F1 was then explicitly reloaded with
  the same audited v11 image, and a fresh post-reload CPU-halted test passed as
  sequence 1/run ID 1. Hardware published `0x00040401` while MicroBlaze was
  stopped; firmware acknowledged the same result after resume without a
  second run. Post-reload sequences 4 and 5 then disabled only physical F1
  FireFly-5 channel 0/global lane 12 for one and ten seconds. Both produced
  isolated lane-12 error saturation with lanes 13-15 clean, proving physical
  disturbance isolation, but `RXPRBSLOCKED` never deasserted and the lock-loss
  count stayed zero. The required lock-loss indication therefore failed, and
  v11 is not fully hardware-qualified. Sequence 6 repeated the ten-second
  disable using incorrect candidate alarm addresses. Sequence 7 used the
  correct read-to-clear bytes and captured LOS byte 3 `0x11` (RX0/TX0) and
  CDR-LOL byte 5 `0x01` (RX0) while disabled. The module therefore confirmed
  isolated physical loss, but v11 again recorded only lane-12 error saturation
  and zero FPGA lock losses.
- `scripts/read_fpga_frequencies.py` is a Python 3.6-compatible
  `cm_interface` utility that validates `r39` and reports the 37 direct-kHz
  clock values in the deployed `r02`-`r38` order for F1 or F2.

## Floorplanning and validation

- Vivado is not on the default non-interactive shell `PATH`. Before every
  Vivado build, simulation, or checkpoint audit, use the Cornell 2023.2 setup
  and explicitly export the network license server in the same shell:

  ```sh
  export XILINXD_LICENSE_FILE=2100@lnxlm.classe.cornell.edu
  source /nfs/opt/Xilinx/Vivado/2023.2/settings64.sh
  vivado -mode batch -source scripts/<script>.tcl
  ```

  `/home/wittich/.flexlmrc` records the same `XILINXD_LICENSE_FILE`, but do
  not rely on implicit FlexNet startup-file discovery in batch/agent shells.
  Keep the environment alive for the complete run and for any subsequently
  spawned synthesis/implementation processes. If checkout fails, capture the
  actual Vivado license error and verify reachability of
  `lnxlm.classe.cornell.edu:2100`; do not mistake it for an HDL/build failure.
  Agent sandbox networking cannot resolve the license hostname even when the
  variable is correct, so licensed Vivado synthesis/implementation must run in
  the approved external execution environment. Verify that environment first
  with:

  ```sh
  /lib64/ld-linux-x86-64.so.2 \
    /nfs/opt/Xilinx/Vivado/2023.2/bin/unwrapped/lnx64.o/lmutil \
    lmstat -a -c 2100@lnxlm.classe.cornell.edu
  ```

  Invoking `lmutil` directly can misleadingly report `No such file or
  directory` because it requests legacy interpreter
  `/lib64/ld-lsb-x86-64.so.3`; the explicit loader above is the verified
  workaround. On 2026-09-01 this reported both `xilinxd` and the server UP,
  with ten free Synthesis and Implementation seats. After that check, run the
  complete sourced Vivado command in the same external environment.
- Vendor `quad_pblock.tcl` paths are relative to each generated wrapper. `scripts/apply_ibert_floorplan.tcl` must source them under the correct left/right `current_instance` context.
- The pre-place hook requires exactly 14 pblocks for each core.
- `scripts/validate_synthesized_design.tcl` checks 14 left quads, 14 right quads, 112 channels, the debug divider/net, and corrected FF3/FF6 mappings.
- Primary commands are `vivado -mode batch -source scripts/create_project.tcl` and `vivado -mode batch -source scripts/build_bitstream.tcl`.
- If post-synthesis validation stops an otherwise completed synthesis run, use `scripts/continue_after_synthesis.tcl` to avoid repeating synthesis.
- Validate the HDL-first engine with
  `vivado -mode batch -source scripts/run_gt_test_engine_sim.tcl` and
  `vivado -mode batch -source scripts/synthesize_gt_test_engine.tcl`.
- Build Milestone 2 with `scripts/build_milestone2_firmware.sh`,
  `vivado -mode batch -source scripts/create_milestone2_project.tcl`, and
  `vivado -mode batch -source scripts/build_milestone2_bitstream.tcl`.
- Build Milestone 3 with `scripts/build_milestone3_firmware.sh` and
  `vivado -mode batch -source scripts/build_milestone3_bitstream.tcl`.
- Build the isolated Milestone 2.5 smoke image with the same firmware and
  `vivado -mode batch -source scripts/build_milestone25_bitstream.tcl`.
