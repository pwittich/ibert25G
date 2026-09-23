# Recovery plan items 1–4

Status note (2026-09-12): the reset-phase changes and listed regressions below
remain completed historical work, not complete CDC signoff. Subsequent v269
hardware and a focused simulation exposed a separate descriptor/start capture
skew defect. That fix is not yet implemented; see
[current evidence and next gate](v269-hardware-baseline.md).

## Diagnostic archive

The pre-change v2.5.17 (`0x00020111`) state is archived as an **unqualified
diagnostic artifact** under `build/diagnostic_archive/`. Generated products are
not committed. The source archive contains the complete working tree except
`build/`, `.git/`, and `xsim.dir/`; `v267-source-members.txt` lists its members.
The products archive includes the ELF, compressed bitstream, routed checkpoint,
synthesis/implementation logs, reports, audit reports, and unit-simulation tree.
Git base: `57204d09342934f53ee4234a39488c993c3d05c3`; the archive, not that commit
alone, identifies the dirty source state. Rebuilding a numbered historical Tcl
entry with current shared RTL does not reproduce its archived implementation.

SHA-256:

| Artifact | Hash |
| --- | --- |
| Source archive | `0c9358f9646f558f551c357f7253b9589bac2c60098c25dab5d3ce8d17544afb` |
| Products archive | `a78cf05c148651b4c5e75c3ac3ebf5aa27c5c0fbf3cabcd0e07f85f4a21c13b3` |
| v267 bitstream | `0617dc11bcc9aa5120a7aff5f68d5318af20c9c27b74da0f710a8d0a4b1192ab` |
| v267 ELF | `1be0f4958a06fffe51a3f8946b88ea02cdb6433602fea5cbae230a26f19f9908` |

The archived build reported WNS +0.681 ns, WHS +0.010 ns, WPWS +0.454 ns,
compression, zero routing/DRC errors, and correct GT sites/properties. Its
bus-skew report says **no bus skew constraints**. CDC/methodology findings were
reported but not compared against an accepted baseline; this is not CDC
qualification. The seven then-existing unit tests passed.

Session history reports F1 programmed with v267 before qualification was paused,
with no v267 test request issued. Programming was not followed by mailbox version
verification. Earlier v265/v266 observations exist in conversation/tool output,
but raw hardware log files were not found in the repository: they must not be
represented as independently archived acceptance evidence. In particular, the
v265 thermal shutdown is invalid test evidence, and v266's reported first clean
result followed by second-request acquisition failure motivated the phase fix.
No hardware actions are part of items 1–4.

## Protocol reset contract

`gt_lane_engine.protocol_reset` is distinct from `rx_reset`. Only management
reset, synchronized into the lane domain, clears protocol state. GT recovery
holds start/stop phases, descriptor ownership, pending snapshot and payload,
pending stop, and counters for selected, unselected, running and stopped lanes.
After recovery it reapplies PRBS controls only for a running selected lane.
The reset policy asserts asynchronously and releases after two RX edges, so a
recovery pulse remains visible even if RX clock stops throughout that pulse.

The direct lane regression must pass before integrated recovery results are
accepted. It covers both toggle phases, unselected lanes, pending snapshots,
clock pause, and subsequent commands.

## Integrated simulation

`sim/tb_gt_recovery_system.sv` instantiates the real engine core, lane engines,
XPM snapshot handshakes, PRBS controller, quad controller, and reset policy.
The physical GT is modeled with delayed reset-done, PRBS-control-dependent lock,
and an RX clock that pauses during reset. Reduced timing parameters accelerate
simulation without changing production constants. CPU register transport is
modeled explicitly; this does not execute or qualify MicroBlaze firmware.

The sequence includes consecutive clean requests, missing-lock and sustained-
error acquisition recovery under opposite toggle phases, clock pause through
recovery, post-capture restart, next-command checks, measurement abort/timeout,
and a permanent-clock-failure case. Expected outcomes include exactly one
publication/run-ID increment per request, response-sequence transport, complete
lane snapshots, retained restart evidence, and healthy IDLE after recoverable
cases. Permanent failure must terminate with failed records in the management
domain and retained failure status, rather than claim healthy IDLE.

## Persistent recovery page

Selector `0xFD` captures the following eight words atomically in mgmt_clk.
Re-select it to refresh. Reads remain frozen until the next selection; serialize
selector access between operators. AXI selector aliases are `0x03C`/`0x0CC`;
MCU selector is `0xCC`. Existing `0xFE` contents and lane records are preserved.

| MCU byte / AXI result offset | Field |
| --- | --- |
| D0 / 040 | Schema `0x52430001` |
| D4 / 044 | Capabilities: bit 0 restart records, bit 1 integrity detector |
| D8 / 048 | Saturating restart request count |
| DC / 04C | Saturating completed-restart count |
| E0 / 050 | Cause [7:0], status [15:8], selected quad lanes [19:16] |
| E4 / 054 | Saturating supervisor-accepted count |
| E8 / 058 | Reserved integrity-event count; unavailable when capability 1=0 |
| EC / 05C | Reserved integrity state; unavailable when capability 1=0 |

Causes: 1 missing acquisition lock, 2 sustained acquisition corruption,
3 post-capture cleanup, 255 unexpected caller. Status: 0 no event, 1 requested,
2 supervisor accepted, 3 supervisor readiness returned, 4 failed/timed out.
Completion records **quad restart completion**, not successful PRBS acquisition.
Counts and last-event fields survive subsequent requests and IDLE, clearing
only on management reset. Post-capture cleanup is counted separately by cause;
an acquisition-plus-cleanup run has two requested/completed restarts.

Integrity slots deliberately advertise unavailable until the detector is
characterized and implemented in later plan steps. Zero in an unavailable slot
must never be interpreted as a clean measurement.

Future forced-recovery acceptance must compare before/after records, reject
saturated counters, require the expected request/acceptance/completion deltas,
and inspect cause/status before post-capture cleanup overwrites the last event.
Elapsed outage duration alone is insufficient evidence.

## Validation record

Run `scripts/run_milestone3_unit_sim.tcl` and
`scripts/run_gt_test_engine_sim.tcl` with Vivado 2023.2. Validation results are
recorded below. These source changes have no new bitstream or
hardware qualification identity; the frozen qualification candidate comes later.

Completed 2026-09-12 with Vivado/XSim 2023.2.2:

- Eight unit/integrated HDL testbenches passed, including all nine integrated
  request scenarios, exact cause/count checks before cleanup, all four lane
  records, atomic publication, frozen little-endian MCU reads, saturation and
  management-reset clearing.
- Both existing engine testbenches passed: the 112-lane synthetic/AXI/I2C suite
  and the Milestone-3 managed-mask/XPM/timebase/platform-fault suite.
- Five Python decoder/acceptance-helper tests passed via
  `python3 -m unittest discover -s sim -p test_recovery_diagnostics.py`.
  Missing completions, wrong cause/status, extra restarts, reset/decreasing
  counts, saturation and unknown schema are rejected. Unavailable integrity
  fields decode as `None`.
- `git diff --check` passed. No hardware action or bitstream build was performed.

During development, port wiring and testbench startup/scheduling mistakes were
corrected. XPM-based simulations raised an XSim startup exception inside the
sandbox; the same compiled simulation ran outside it. Final suites ran in that
working environment. The near-saturation test initially sampled a continuous
diagnostic assignment in the same delta cycle as a testbench deposit; allowing
the assignment to settle fixed the test, without an RTL counter change.

Final raw validation archive: `build/diagnostic_archive/items1-4-validation.tar.gz`,
SHA-256 `016fc7e1b3438156dfeb1241096947156c47cc143d2d0920e41029bf419bb667`.
It contains both final command logs/journals and simulation trees.
`build/items1-4-unit.log` SHA-256:
`2801a1058100a5f758d6453742045a2c65f16a3e415ff9b38a814fab39ccdfd7`.
`build/items1-4-core.log` SHA-256:
`bfc9ad5ce23d700b75c2ca45fc6ee3f385c214736529b02a1f7070f1007809f5`.

The physical GT model verifies digital control/protocol behavior, not actual
GT acquisition physics or the unexplained historical lane pattern. Tracing,
transient characterization, integrity detection, source freeze, physical
implementation/CDC review and hardware qualification remain later plan steps.
