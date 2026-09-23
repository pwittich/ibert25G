# Descriptor-transfer repair — source/simulation stage, 2026-09-12

At the source/simulation stage F1 remained the failed v269/run-1 artifact. No hardware access,
reprogramming, new firmware version or bitstream was performed in this stage.
The preserved [v269 evidence](v269-hardware-baseline.md) is unchanged.
Subsequent [v270 hardware baselines](v270-hardware-baselines.md) both passed;
F1 is now v270/run 3, healthy IDLE after the subsequent
[lane-12 pulse pass](v270-pulse-characterization.md). No optical stimulus was applied.

## Implemented

- Lane start and stop requests now traverse four RX capture stages, versus
  two for descriptor selection and PRBS mode. Start consumption therefore has
  two additional RX cycles of data settling. Stop uses the same depth to
  preserve ordering when abort arrives before start acknowledgement.
- The lane latches PRBS mode with selection at start acceptance. Recovery
  restores that accepted mode rather than a live descriptor synchronizer.
  GT recovery still preserves all protocol phases and capture stages; only
  protocol reset clears them. FSM encodings and public register maps remain.
- Publication compares the atomically transferred snapshot selection against
  the requested mask. A missing requested lane becomes the existing failed
  platform record (selected, loss flag/count 1, zero measured counts), and stop
  reason becomes 4. The loss field in this synthetic failure is **not** a
  measured physical lock-loss event. An unexpected selected lane also sets
  reason 4. Existing correctly selected measurement records are unchanged.
  This is a publication guard, not pre-acquisition descriptor-echo validation.

## Validation

`sim/tb_gt_lane_descriptor_transfer.sv` tests each selection/mode bit with one
and two extra first-stage capture cycles, both toggle polarities, selection
and deselection, 5↔2 PRBS mode changes, stopped RX clocks, recovery and early
stop. Its entry is `scripts/run_descriptor_transfer_sim.tcl`, also included
in the regular unit-suite entry. This models logical capture latency, not
analog metastability or arbitrary delay.

The integrated real-core/lane/XPM/PRBS/quad regression adds a malformed accepted
selection. It requires `0x01030404` (one failed, three passed, four requested,
platform stop), instead of v269's silent `0x00030301`. It also retains prior
normal, recovery, abort/timeout, saturation and missing-clock cases.

Nine existing unit/integrated tests and both core/MCU/AXI tests passed; all 15
Python tests passed. Logs: `build/descriptor-unit.log`,
`build/descriptor-core.log`; focused final test log:
`build/descriptor-transfer-final.log`. The first test elaboration rejected
bit-select force syntax; the test now forces a whole vector with only the
chosen bit delayed. No design workaround was made for that simulator issue.

## Physical build gate — completed for diagnostic v270

Two extra stages provide a **bounded settling budget**, not a general atomic
CDC guarantee. The required gate for a new diagnostic build was an
explicit source-to-descriptor-first-stage routing bound compatible with the
RX period, plus synchronizer-resolution allowance and verification that the
bound is actually analyzed. V269's CDC report marks these paths as `Asynch Clock Groups`;
a lower-priority max-delay constraint alone can be ignored. Review/narrow the
conflicting exceptions or use a properly constrained explicit payload handshake.
Do not claim the new source is physically CDC-qualified from simulation.

The [v270 build and independent audit](v270-build.md) now pass that narrow
gate: all 16 descriptor endpoints are analyzed at 3.000 ns, with worst slack
+1.568 ns. The conflicting quad clock group is replaced, not layered beneath
another exception. Existing non-descriptor CDC limitations remain documented;
this does not establish full hardware acceptance. V270 subsequently passed
the two clean baseline gates linked above, but remains diagnostic.

Keep the failed v269 reference and all historical products unchanged.
After authorization and fresh power/FPGA-temperature
preflight, require two clean four-lane baselines before fault stimuli. Resolve
the FireFly all-ones alarm readback separately. Runtime loss thresholds and
the eventual clean qualification candidate remain deferred.
