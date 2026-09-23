# Runtime-integrity v272 design

Date: 2026-09-13. The design is frozen as isolated v272 / 2.5.22 with identity
`0x00020116`. Its complete simulation, matching firmware, compressed
incremental build, and independent routed audit pass. Its lane-data hardware
gate also passes, with the qualification caveat that both clean baselines
required a bounded acquisition recovery; see
[the hardware record](v272-hardware-gate.md). Frozen v271 /
2.5.21 and its evidence remain unchanged.

## Evidence and terminology

Golden and managed-GTY hardware showed that FireFly channel-0 LOS/CDR-LOL can
coexist with asserted FPGA `RXCDRLOCK`, asserted `RXPRBSLOCKED`, deasserted
`RXELECIDLE`, and an unchanged 322.260–322.261-MHz RXUSRCLK2. The useful FPGA
observation is sustained PRBS corruption. Isolated 2.5.6 measured lane 12 error
active for 8,870,131,729 of 9,667,809,834 RX cycles (`0.917491`) during a
ten-second optical outage; v271's deliberate transient occupied two RX cycles.

Accordingly, this source calls the condition **data-integrity loss**, never
optical LOS or CDR loss. The second condition is absence of the shared
RXUSRCLK2 fabric heartbeat. It proves that the Wizard's common quad clock is
not advancing; it is not a per-lane recovered-clock indication.

## Detector semantics

`gt_runtime_integrity_monitor.sv` is armed only by the engine's registered
`measurement_enable` and uses the controller's accepted, stable lane mask.
Defaults at the 200-MHz management clock are:

- assert a lane after 20,000,000 consecutive synchronized error-active samples
  (100 ms);
- clear its live indication after 200,000 consecutive clean samples (1 ms);
- assert missing shared RXUSRCLK2 after 20,000,000 management cycles without a
  divided-heartbeat edge (100 ms), and clear after four observed edges;
- count one saturating event when one or more new causes assert in a cycle;
- retain the union of implicated lanes and whether a clock event occurred until
  management reset.

The consecutive-error policy is now supported by the v271 hardware threshold
characterization. A 250.280-ms F1_5 channel-0 disable produced one uninterrupted
lane-12 error-active run of 3,133,090,464 RX cycles (about 9.72 seconds), while
the known injection control remains two cycles. The clean following run passed.
This supports the 100-ms threshold for v272; it does not measure the minimum
outage duration.

On a qualified event, the PRBS controller enters existing `ST_FAULT` and
retains diagnostic fault stage 27 (`ST_RUNTIME_INTEGRITY_FAULT`). The generic
engine then follows its tested platform-fault publication path; there is no
automatic retry or recovery. The native lock-loss counters retain their old
meaning and are not incremented by this detector.

## Selector `0xFD` ABI

Schema remains `0x52430001`. Capability bit 0 remains restart diagnostics;
bit 1 now identifies available integrity words. Historical/default-off targets
continue to publish capability `1` and zeros in words 6 and 7.

Word 6 is the saturating integrity-event count. Word 7 packs: fault bit 0,
live error lanes [4:1], live shared-clock fault bit 5, retained error lanes
[9:6], retained shared-clock fault bit 10, selected lanes [14:11], and monitor
enabled bit 15. Bits [31:16] are zero. `scripts/recovery_diagnostics.py`
decodes both the raw word and named fields.

## Simulation gate completed

`run_milestone3_unit_sim.tcl` passes with two new focused tests and an extended
full core/controller integration:

- a two-cycle transient does not assert;
- sustained corruption asserts the correct lane and respects clean hysteresis;
- missing heartbeat is a distinct retained event and recovery requires four
  edges;
- capability, event count, lane state, and fault stage 27 are retained;
- the full engine publishes the expected atomic failed result after a runtime
  integrity platform fault;
- all prior acquisition, restart, phase, paused-clock, descriptor, profile, and
  trace regressions still pass with historical targets default-disabled.

## Hardware threshold gate completed

V271 sequence 5 isolated the controlled disturbance to lane 12, recorded no
native lock losses, retained 104 trace events without overflow, and restored
FireFly byte 86 to zero. Sequence 6 then passed cleanly on all four lanes.
Evidence and limitations are in
[the v271 threshold characterization](v271-firefly-threshold-characterization.md).
The optical outage did not test missing shared RXUSRCLK2.

## Build/audit gate completed

The distinct v272 target enables the accepted detector policy only there. The
complete regression, firmware build, compressed incremental implementation,
and independent routed audit pass. The routed audit explicitly verifies all
ten detector synchronizer registers and their `ASYNC_REG` properties. Timing
is WNS +0.018/WHS +0.001 ns with zero routing or DRC errors. Existing unrelated
CDC/methodology findings and the absence of isolated-target bus-skew
constraints remain. Artifact identities are in [the v272 build record](v272-build.md).

## Hardware gate completed

The two nominal 10-second measurements were clean after one bounded acquisition
recovery each. With that caveat explicitly accepted, sequence 3 proved that
the known two-cycle lane-12 injection does not trip the detector. Sequence 4
disabled only FireFly-5 channel 0 for 0.250289 s and produced one retained
lane-12 integrity event, fault stage 27, and atomic failed publication while
lanes 13–15 and the shared-clock cause stayed clear. The output control was
restored. This passes the lane-data branch; missing shared RXUSRCLK2 remains
untested in hardware. V272 is not fully qualification-ready because of the
repeatable acquisition recovery. Its retained fault was later cleared only by
an explicitly authorized same-image reload; the existence of a hash-pinned
helper did not itself authorize that reload.

The subsequent v273 planned-startup diagnostic preserved this detector and
removed the nominal acquisition-recovery caveat in two consecutive clean runs.
Its watched two-cycle lane-12 pulse did not trip the detector, while a
250.304-ms F1_5 channel-0 disable retained exactly one lane-12 integrity event,
no shared-clock cause, and fault stage 27. All four synchronized
`RXPRBSLOCKED` inputs were asserted at the first-fault snapshot, then fell when
the retained fault disabled the checker. The quad stayed READY without a
Wizard reset. The final `0x280c`–`0x280f` lane publications are deterministic
platform-failure records, so their lock-loss marker is not a measured counter.
At the end of the v273 work, F1 retained the sequence/run-ID-5 platform fault.
The later v274 gate below supersedes that state. See
[the v273 record](v273-planned-startup-restart.md).

Isolated v274 / 2.5.24 now provides a separately identified, default-off
diagnostic hook that suppresses only the divided heartbeat at the monitor
input while physical RXUSRCLK2 continues. Its full simulation, compressed
build, independent routed audit, and explicit control-to-synchronizer fan-in
proof pass. Its unique clean baseline and controlled heartbeat hardware gate
also pass: sequence/run 2 retained one clock-only stage-27 event while the
physical managed clock remained 322.260 MHz and the quad stayed READY. The
evidence validates the missing-heartbeat detector branch through controlled
monitor injection, not actual physical clock disappearance. See
[the v274 build and test plan](v274-heartbeat-test.md).

Isolated v275 / 2.5.25 freezes the supported policy as a qualification
candidate: the detector and planned startup restart are enabled, while the
v274 heartbeat hook is explicitly disabled. Its full regression, compressed
build, independent audit, and physical-only heartbeat fan-in check pass. Two
unique consecutive 10-second F1 baselines then passed without acquisition
recovery, reload, or retry, with zero errors, lock losses, or integrity events.
The following unique uninterrupted 12-hour external soak also passed without
reload/retry: four equal 1,113,731,693,556,560-bit records, zero errors, native
lock losses, or saturation, normal completion, and healthy final IDLE. This
closes the clean-baseline and long-soak gates; it does not add evidence for
actual missing physical RXUSRCLK2 or optical/native loss. See
[the v275 record](v275-qualification-candidate.md).
