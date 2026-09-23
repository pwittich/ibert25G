# Recovery plan items 5–6: diagnostic capture and characterization

## Current status — 2026-09-12

This document retains the v268 instrumentation ABI and build review. Its clean
hardware baseline produced 107 events and overflowed the 64-entry trace.
The subsequent v269 256-entry recorder retained all 127 events, but its first
baseline unexpectedly omitted lane 12 despite requested mask `0xF000` and
performed an acquisition restart. Characterization remains incomplete.
That v269 failure is preserved; no second v269 run or fault stimulus followed.
See [v269 evidence and descriptor-CDC reproducer](v269-hardware-baseline.md)
and [incremental build provenance](incremental-diagnostic-builds.md).
[Source repair/regression](descriptor-transfer-repair.md) and the new
[v270 build/descriptor timing audit](v270-build.md) now pass. F1 runs v270,
healthy IDLE after [two clean baseline passes](v270-hardware-baselines.md).
The subsequent [lane-12 pulse test](v270-pulse-characterization.md) passed as
sequence/run ID 3. Optical tests await resolution of FireFly `FF/FF`. The
procedure below is historical planning context, not authorization to retry.

## Identity and scope

Isolated **v268 / 2.5.18**, firmware and hardware `0x00020112`, enables
`DIAGNOSTIC_TRACE=1` on the four-channel quad-124 image. It includes the
items 1–4 reset-phase fix and persistent restart diagnostics. It retains v267's
recovery settings; it does not add a measurement-time integrity detector,
change a detection threshold, or constitute the eventual qualification candidate.
Historical v267 products remain archived unchanged.

The prebuild source archive is
`build/diagnostic_archive/v268-diagnostic-source-prebuild.tar.gz`, SHA-256
`40d0712239994b99b8e0db3067095722931f77fe3f4a07b140f8d051f2662cde`.
It includes build sources, constraints, firmware, and the HDL regressions;
operator scripts developed afterward are separately identified with results.
Matching ELF SHA-256:
`ab70b4852798c9140166872e14401160dd386444075a26b87fd7aa99343b3785`.

## Diagnostic register map

All selectors use `CC`; eight little-endian words are read at `D0..EC`.
Normal lanes and `FD`/`FE` retain their previous interfaces. Serialize selector
access: no other operator or watch process may change it during a dump.

| Selector | Contents |
| --- | --- |
| `80..BF` | 64 physical transition-ring slots, 256 bits each |
| `F8..FB` | Frozen native-RX error profiles for lanes 12..15 |
| `FC` | Trace metadata |
| `FD` | Existing coherent persistent restart snapshot |
| `FE` | Existing live/first-fault platform diagnostics |

`FC` word 0 is schema `54520001`; word 1 contains active bit 15, overflow
bit 14, valid count [13:7], and next-write index [6:1]. Words 2/3 are epoch
and saturating event count. Remaining words are zero. The ring starts on the
acquisition rising edge, captures changed samples at the 200-MHz management
clock, and freezes on platform fault or engine/controller IDLE after cleanup.
The next acquisition starts a new epoch. Read only when frozen and require
identical metadata and run IDs before/after dumping. Full rings are chronological
starting at next-write index; overflow means early evidence was overwritten.

Each slot's words are: timestamp low/high (5-ns ticks from acquisition), quad
live diagnostics, masked acquisition diagnostics (`FF00001F`), PRBS live
diagnostics, synchronized control/status pins, actual PRBS selections, and
engine/handshake state. The engine word contains start ack [19:16], stop ack
[15:12], state [11:8], controls bit 7, measurement bit 6, acquisition bit 5,
start phase bit 4, and stop phase bit 3. The pins word packs reset-all [31],
lane-reset [30], counter-reset [29:26], RX-PMA-reset [25:22], datapath-reset
[21], TX-reset-done [20:17], RX-reset-done [16:13], CDR-lock [12:9],
PRBS-lock [8:5], sticky observed error [4:1], and checker-enable [0].
Selections are `{txprbssel[15:0], rxprbssel[15:0]}`.

These synchronized debug buses are observational, not atomic cross-domain
control transfers. Near-simultaneous asynchronous bit transitions may appear
on adjacent management cycles. Pulse timing must come from the RX profiles,
not inferred from management-domain error sampling. Continuously changing
qualification counters are excluded to avoid flooding the transition ring.

Each RX profile has schema `45520001`, elapsed cycles, error-active cycles,
maximum consecutive error-active cycles, first and last error cycle indices,
valid word (1 required), and reserved zero. Counters saturate at `FFFFFFFF`;
the operator limits measurements to 2–10 seconds and rejects saturation.
Profiles start after measurement-enable synchronization; they are diagnostic
windows, not replacements for the core's tested-bit accounting. An XPM
handshake transfers the complete frozen payload after measurement ends.
The next measurement clears validity. An absent RX clock can leave the
profile unavailable; it must not be interpreted as zero errors.

## Validation and hardware procedure

Nine unit/integrated HDL tests and the two existing core/MCU/AXI regressions
passed on 2026-09-12. The integrated regression checks every new selector
through AXI and MCU and verifies return to the existing pages. Fourteen Python
decoder/operator-validator tests passed. Logs: `build/trace-unit-selectors.log`,
`build/trace-core.log`. The v268 build/routed audit passed as recorded below;
its hardware trace overflow and v269 follow-up failure are summarized above.

1. Build the matching `268` firmware/bitstream, audit placement, properties,
   clocks, compression, routing, timing, and CDC/methodology deltas before
   programming. Preserve hashes and reports with the diagnostic artifact.
2. Preserve current results and verify FPGA temperature, AVTT, clocks and
   FireFly state. The first FPGA's JTAG SysMon reported **26.0 C** before this
build was loaded (`build/temperature-pre268.log`); the second reported
   24.5 C. The MCU firmware rejects the new MCU telemetry API. Do not confuse
   a FireFly/regulator temperature with FPGA temperature.
3. Program F1 only via XSDB on lnx4189 and verify both version words. Run two
   clean 10-second requests with distinct sequence/run IDs. Dump the complete
   frozen trace before the next request. Unexpected acquisition restart,
   corruption, fault, or incomplete handshakes stop further stimuli.
4. Characterize one separately logged lane-12 XSDB error injection, then short
   FireFly TX-disable intervals (initially 50, 100, 250 ms). Repeat successful
   trials with new sequences; never automatically retry a failed run. Record
   actual host write bounds, not just requested sleep duration. Preserve
   read-to-clear LOS/CDR-LOL flags with context and restore original byte 86.
5. Compare error-active count, longest consecutive run, first/last error span,
   native lock losses, clock continuity, adjacent-lane results, and restart
   events. Only then choose assertion/recovery hysteresis. Intermittent error
   activity may require window density rather than consecutive-high detection.

`milestone268_characterize.py` saves raw evidence before validation and requires
exact run/sequence matching, stable records, healthy final IDLE, no trace
overflow, and exactly one cause-3 cleanup restart. `external-pulse` does not
inject by itself: the XSDB command and time must be independently logged.
`milestone268_diagnostics.py` is a read-mostly dump utility, not a run launcher.
No threshold or runtime integrity qualification is claimed by either tool.

## Historical v268 synthesis CDC/methodology comparison

Against archived v267 synthesis, CDC-1=1 and CDC-13=16 are unchanged. CDC-10
increases 19→31, CDC-11 24→48, and one CDC-7 appears. Endpoint comparison
attributes these changes to the following explicit structures, not a new
runtime detector:

- Eight added async-assert/two-RX-edge-release reset synchronizers: four lane
  protocol resets and four profile resets. Their reset source is the existing
  power-on/MMCM-ready combination. Deassertion is synchronized locally.
- Four profile measurement-enable synchronizers, parallel to the existing
  lane measurement-enable crossings. They observe the same state decode and
  only delimit diagnostic windows; they cannot initiate recovery.
- The acquisition-only lane reset policy now asserts asynchronously to retain
  a reset pulse across a stopped RX clock, releasing on two RX edges. Its
  additional LUTAR-1 finding is intentional. While acquisition changes normally,
  quad-ready is high and masks that term; throughout restart acquisition is
  held active. No combinationally decoded assertion is used as protocol reset.
- The startup `initial_quad_ready_seen` latch has an async-clear CDC-7. It stays
  zero until ready passes two RX synchronizer stages after reset, so reset
  removal does not coincide with a qualifying set. It is startup-only and does
  not clear the preserved transaction phases on quad recovery.
- Added independent trace synchronizers cause sixteen new CDC-11 endpoints
  plus eight existing PRBS error/lock endpoints to be reclassified from CDC-3.
  The trace does not feed control back; cycle-level skew between observational
  paths is documented above. Native error counts use RX-local registers and
  an XPM payload handshake, not those independent sampled bits.

The existing unknown I2C diagnostic crossing, generated-GT primitive crossings,
one related-RX/TX-clock TIMING-7, and 960 unclocked unused-monitor TIMING-17
findings remain. None of this is a claim of global CDC cleanliness or a
qualification waiver. Frozen qualification still requires the later baseline
review; diagnostic interpretation must respect the stated sampling limits.

## Completed build/routed audit

The matching build and independent `audit_milestone268_routed.tcl` passed.
Routed WNS **+0.325 ns**, WHS **+0.010 ns**, WPWS **+0.454 ns**; no failing
timing endpoints, routing errors or DRC errors. Managed GT sites are exactly
X0Y16–X0Y19 with golden RX properties. Compression is TRUE; implemented monitor
clocks are 100.000 and 325.000 MHz. All eleven IPs report up-to-date.
The bus-skew report says **no bus skew constraints**, not a measured skew pass.
DRC retains the known single RPBF-3 generic-I2C buffering warning.

Routed CDC categories preserve the synthesis delta above (CDC-9 is one in
both routed builds). Routed LUTAR-1 is six versus five in v267: existing
power-on/MMCM reset combination, added lane-reset assertion, and generated
GT/CPU/debug reset logic. The reset endpoints have been reviewed as described
above, for this diagnostic experiment only. There is no global CDC signoff.

Synthesis ignored the trace's `ram_style="distributed"` attribute (64
Synth 8-7186 warnings) and implemented storage as registers. This affects
resource use, not the tested ring semantics: total design uses 33,126 registers
and 15,137 LUTs, each below 1% of the device. Do not claim LUTRAM inference.
Other warnings cover constant/reserved outputs, unused ports in the isolated
top/generated CPU subsystem, temporary-selector trimming, and automatic
DIFF_TERM translation. No FSM recoding warning was found; the explicit
`fsm_encoding="none"` attributes remain on engine, quad and PRBS state.

Archived bitstream SHA-256:
`a814c19d63d7ef46b2b203f0ee157ef7b72727517fa20a8a689edff1ab214f65`.
Products archive `v268-diagnostic-products.tar.gz`:
`d58a7de4b867bee51b7136f3af06cc0cf047df14c1054734d17e4df0df926224`.
Operator archive `v268-operator-scripts.tar.gz`:
`6fefbeb1e4778c9414716f02ef6391082028acfa49b4968d907f3b8a760b7c5f`.
All are under `build/diagnostic_archive/`; generated artifacts are not committed.
