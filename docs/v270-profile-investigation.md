# V270 zero-elapsed profile: offline investigation

Date: 2026-09-12. The initial diagnosis made no production change. The
recommended source repair was subsequently authorized and implemented. No
hardware reads, run requests, programming, or validation-rule relaxation were
performed as part of the repair.

## Outcome

The leading explanation is a spurious post-run measurement pulse reaching
lane 12's profile synchronizer. The unmodified profile RTL can overwrite a
good completed snapshot with exactly the observed valid-but-zero-elapsed
record after a short input pulse. This mechanism is reproduced in simulation;
the physical cause of the saved hardware event is not conclusively proven.

The shared RTL is now repaired and its simulations pass. This does not alter
the interpretation of the frozen v270 failure and is not itself a versioned or
routed candidate.

## Evidence

The failed capture is `build/diagnostic_archive/v270-after-golden-run1-alarms.json`,
SHA-256 `b06aa231e78f5c1d84036b7ea834b5384f9e68ae44522f848c2b7b0849be9778`.
Lane 12's diagnostic words are `[45520001,0,0,0,0,0,1,0]` (hex schema).
Lanes 13–15 report 3,222,603,183 elapsed RX cycles. The normal lane-12 result
has 3,222,603,184 valid cycles, zero errors and no lock losses. Overview and
ordinary lane records were stable across the full dump. The profile pages
were read only once, so a one-off transport/readout defect is not excluded.

The investigated `src/gt_rx_error_profile.sv` matches the frozen v270 source
archive byte-for-byte (SHA-256
`9acfd371b80575df8f3153b4db88a1006e2f6f529993ad89f3c6435a75bf0c57`).

## Mechanism in the RTL

1. `gt_test_engine_core.sv:412` generates `measurement_enable` combinationally
   from `state == ST_RUN`, not from a dedicated management-clock register.
2. The state ABI uses RUN=2, STOP_WAIT=3, CAPTURE_WAIT=4, COPY=5, PUBLISH=6,
   IDLE=0. Multi-bit transitions such as PUBLISH (0110) to IDLE (0000) can
   transiently decode as RUN (0010) if state-output delays differ. STOP_WAIT
   to CAPTURE_WAIT is another potential hazard. This describes possible
   physical skew, not a pulse visible in zero-delay state-machine simulation.
3. `managed_quad124_wrapper.sv:181` gives all four profiles the same RX clock,
   reset and measurement source, but each has its own two-stage synchronizer.
   A sufficiently narrow pulse can be sampled by one lane and missed by
   another due to routing/skew/metastability. Independent logical clocks are
   not needed for this vulnerability.
4. `gt_rx_error_profile.sv:34` clears counters on every synchronized rising
   edge. It does not require a newly accepted run or protect an already
   completed profile from rearming.
5. With exactly one synchronized high cycle, the rising-edge branch clears
   elapsed; the counting branch never executes. The following falling edge
   publishes a correctly formatted zero-elapsed snapshot.
6. The XPM handshake can faithfully transfer that bad new snapshot. Management
   valid is set by receipt, not by positive elapsed or a matching run epoch.
   A narrow source pulse can also be missed by the management-side valid-clear
   logic, leaving the old valid flag asserted until the overwrite arrives.

The v270 routed audit explicitly records CDC-10, combinational logic before
the synchronizer, at all four `g_profile[n].profile/measure_meta_reg/D` pins:
`build/gt_test_milestone270_audit/cdc_routed.rpt:382`. These findings were
previously retained as diagnostic caveats; they cannot now be dismissed as
harmless based solely on the use of two synchronizer stages.

The saved transition trace shows a normal 2,000,000,000-management-cycle RUN,
followed by STOP_WAIT, CAPTURE_WAIT, COPY, PUBLISH, IDLE. At ticks
2000865767/2000865768 it records PUBLISH/IDLE, with no second synchronous RUN.
This is consistent with normal operation and cannot exclude a sub-cycle glitch.

## Offline reproducer

Diagnostic-only files (not production changes):

- `build/tb_profile_pulse_probe.sv`
- `build/run_profile_pulse_probe.tcl`
- `build/profile-pulse-probe.log`

The test uses the unmodified profile module and the Vivado 2023.2 XPM library.
A normal 100-cycle input window first produces elapsed=99, valid=1. After
allowing the handshake to complete, a 0.4-ns pulse is placed across one RX
edge. The resulting profile is exactly:

```text
00000000 00000001 00000000 00000000 00000000 00000000 00000000 45520001
```

Simulation reports `PASS: short post-run input pulse reproduces exact profile signature`.
This is an injected-input mechanism test, not a routed timing simulation,
metastability model, four-lane asymmetry proof, or reconstruction of the
precise hardware pulse width. It demonstrates that the existing profiler is
vulnerable to this signature; it does not rule out readout corruption.

The existing `tb_gt_diagnostic_capture.sv` exercises normal bursts, retention
and a second clean window, but not narrow post-run pulses or multi-bit state
decode hazards. Passing that test does not cover this failure mechanism.

## Implemented repair

- `gt_test_engine_core.sv` replaces the combinational `state == ST_RUN`
  measurement decode with `measurement_active`, a dedicated management-clock
  flop. It is asserted on the successful ARM-to-RUN transition and cleared on
  every normal, timeout, abort, platform-fault, or defensive exit from RUN.
  Simulation asserts that its externally visible value remains cycle-aligned
  with the RUN state; this does not add a measurement cycle.
- The already registered accepted-request toggle is exported as
  `measurement_run_toggle`. It changes once at descriptor acceptance, long
  before the post-acquisition measurement window, and is synchronized beside
  the measurement level in each RX profile.
- `gt_rx_error_profile.sv` records active and completed epochs. It can accept
  and publish one window per epoch; after completion, another measurement edge
  with the same epoch is ignored. Completed data remains valid until a new
  accepted-request toggle, rather than being cleared by the measurement level.
- The Python validator and the profile schema are unchanged. The repair does
  not make zero elapsed look valid and does not rely on suppressing a bad
  snapshot after it has been generated.

## Validation

`vivado -mode batch -source scripts/run_milestone3_unit_sim.tcl` passes all
controller, recovery, lane-reset, lane-toggle, integrated-engine, diagnostic,
and descriptor-transfer tests. The integrated regression requires exactly one
measurement epoch, start, and stop for each accepted request, covers both
toggle phases, abort, timeout, recovery, RX-clock loss, and checks measurement
alignment with RUN.

The focused diagnostic regression now places a 0.4-ns same-epoch pulse across
an RX rising edge after a valid completion. It verifies the complete 256-bit
profile stays unchanged, then toggles to the next epoch, pauses the RX clock,
and verifies a clean opposite-phase run replaces the prior profile normally.
The selected changed hierarchy (`gt_rx_error_profile`, managed wrapper, core,
AXI wrapper, shell, and Milestone top) also passes `xvlog` analysis.

Post-repair SHA-256 identities are:

- `src/gt_test_engine_core.sv`:
  `262a981646e390450799733092bbc9c98f39aca8eac20c458a39b5be8d4c2548`
- `src/gt_rx_error_profile.sv`:
  `62ef739a842bcc7799a2986ab0115794365d7fe77933e55baa93d2f15bb6b7e4`

That implementation gate is now complete as isolated v271 / 2.5.21
(`0x00020115`). Its compressed build and independent routed audit pass; all
profile measurement/epoch first stages have direct registered sources with no
combinational fan-in. See [the v271 build record](v271-build.md). Do not rebuild
or relabel v270 from these changed sources. F1 remains v270 IDLE at sequence/
run ID 1 until a new hardware step is explicitly authorized.
