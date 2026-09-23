# Critical review of the current lock-loss plan

Historical review of the 2.5.16-era plan; preserved below unchanged.
For the current 2026-09-12 resume point, see
[v269 baseline and descriptor-CDC finding](v269-hardware-baseline.md)
and [build state](memory/build-state.md). The reset-phase repair and
integrated tests were completed; a separate descriptor/start skew defect now
blocks further fault characterization. No qualification candidate is accepted.

The current plan is not ready for hardware qualification. It has found the
correct observable—sustained PRBS corruption—but then pivoted into increasingly
elaborate reset/restart machinery without resolving the acquisition mechanism.
More seriously, the current 2.5.16 recovery design contains a likely
deterministic repeated-request bug.

The latest 2.5.16 simulation, build, timing, and routed audit pass. There is no
preserved hardware result for 2.5.7–2.5.16, so none of those versions can yet be
called hardware failures or successes.

## Main findings

### 1. The plan is still solving “lock loss” with signals already proven not to indicate the loss

The golden experiment established that during the FireFly outage:

- `RXPRBSLOCKED` remained asserted.
- FPGA `RXCDRLOCK` remained asserted.
- `RXELECIDLE` remained inactive.
- RXUSRCLK remained present.
- Only sustained `RXPRBSERR` distinguished the outage.

That evidence is explicit in
[`milestone254-signal-loss-characterization.md`](milestone254-signal-loss-characterization.md#golden-ibert-control-2026-09-11).

But the current lane engine still increments `lock_loss_count` only on a falling
edge of `RXPRBSLOCKED && RXCDRLOCK` in
[`src/gt_lane_engine.sv`](../src/gt_lane_engine.sv). Therefore 2.5.16 still cannot
report the demonstrated FireFly loss as a lock-loss event. The restart work may
improve acquisition, but it does not yet fix the original runtime detection
requirement.

### 2. Full-quad recovery likely breaks every even-numbered request

`gt_lane_engine` uses toggle handshakes. On reset it forces `start_seen`,
`start_ack_toggle`, and the synchronized request state to zero; it only accepts
a command when the synchronized request differs from `start_seen`.

The new recovery policy deliberately resets lane engines during acquisition
recovery in
[`src/managed_quad124_lane_reset_policy.sv`](../src/managed_quad124_lane_reset_policy.sv).

That works when the held request toggle is `1`, as on the first request after
configuration: reset returns `start_seen` to `0`, and the held `1` is
rediscovered. It fails when the held toggle is `0`, as on the second request:
reset leaves both values at `0`, so no new start event is detected.

This is particularly concerning because the observed 2.5.6 failure was exactly
the second unique request, as recorded in
[`milestone256-signal-loss-characterization.md`](milestone256-signal-loss-characterization.md#version-256-restart-failure).

The fix is to separate protocol state from datapath state. A GT recovery must
not reset `start_seen`, acknowledgements, or snapshot-handshake phase.
Alternatively, replace the toggle with an explicit transaction epoch that can
be reissued after recovery.

### 3. The new test does not test that handshake

The lane-reset testbench only drives `quad_ready` and `acquisition_active`; it
never instantiates `gt_lane_engine`, never supplies a start toggle, and never
tests both toggle polarities. See
[`sim/tb_managed_quad124_lane_reset_policy.sv`](../sim/tb_managed_quad124_lane_reset_policy.sv).

It therefore proves only the reset output’s Boolean truth table. It does not
prove that a command survives recovery. The passing simulation in
The historical `vivado_719673.backup.log` result should not be interpreted
more broadly.

The test also keeps `rx_clk` free-running. The reset policy itself is clocked by
`rx_clk`; if a full-quad reset stops or disrupts that clock, it may be unable to
assert or release `lane_rx_reset`. That hardware-relevant case is absent from
simulation.

### 4. The forced-restart acceptance does not positively prove a restart occurred

The script attempts to sample restart states 23/24, but if it misses them, it
simply infers that a restart happened because the outage spanned the 100-ms
threshold. See
[`scripts/milestone259_forced_restart_acceptance.py`](../scripts/milestone259_forced_restart_acceptance.py).

There is no persistent restart count, cause, or completion record. A clean final
run could therefore pass without direct evidence of the intended internal
sequence. The forced test also insists on fresh sequence 1/run ID 1, exactly the
polarity that avoids the handshake bug.

Normal acceptance should require zero unexpected recoveries. Forced acceptance
should require a persistent count increment of exactly one, with cause and
completion status.

### 5. Recovery is masking the unresolved acquisition problem

The preserved evidence repeatedly shows managed acquisition failure with
healthy:

- power and QPLL;
- reference and user clocks;
- reset-done signals;
- optical loopback under golden IBERT.

Examples include v12, 2.5.4, and the second 2.5.6 request. Often only lane 15
ever locks. The plan has not explained that repeated lane pattern or why a
previously accepted 2.5.2 sequence later became unreliable. A full-quad restart
may be a useful bounded workaround, but it is not yet a root-cause result.

The next diagnostic should capture the actual control ordering around:

- start request and acknowledgement;
- `TXPRBSSEL` and `RXPRBSSEL`;
- checker enable;
- `RXPRBSCNTRESET`;
- GT reset inputs and reset-done outputs;
- per-lane `RXPRBSLOCKED` and `RXPRBSERR`.

A small transition trace buffer or ILA would provide much more information than
another numbered reset variant.

### 6. Candidate/version provenance has broken down

Candidates 2.5.7 through 2.5.16 all source the mutable
`create_milestone255_project.tcl` flow and current shared RTL; for example
[`scripts/create_milestone257_project.tcl`](../scripts/create_milestone257_project.tcl)
and
[`scripts/create_milestone266_project.tcl`](../scripts/create_milestone266_project.tcl).
At review time, the working tree contained 48 tracked changes and 136 untracked
files relative to the last commit.

Consequently, rebuilding “2.5.7” today would use today’s shared RTL, not
necessarily the RTL used for its original bitstream. The numbered Tcl file
identifies a version number, but does not preserve the implementation belonging
to that version.

README and build-state documentation stop at 2.5.6, while ten later candidates
have been generated. There are also no raw hardware logs for those candidates.
That violates the project’s intended separation of target/version artifacts and
makes retrospective comparison unreliable.

### 7. “Routed audit passed” is narrower than it sounds

The audit checks timing, routing errors, DRC errors, GT placement, selected
properties, compression, and clocks, then declares success. See
[`scripts/audit_milestone255_routed.tcl`](../scripts/audit_milestone255_routed.tcl).

However, the 2.5.16 routed CDC report still contains critical findings,
including 23 `CDC-10` and 44 `CDC-11` cases in
[`build/gt_test_milestone266_reports/cdc_routed.rpt`](../build/gt_test_milestone266_reports/cdc_routed.rpt).
Many may be established generated-IP findings, but the audit does not compare
them against the accepted baseline or prove that the new restart/reset crossings
introduce none.

## Recommended next plan

1. Do not program 2.5.16 yet.
2. Separate lane protocol reset from GT/datapath recovery reset.
3. Add an integrated simulation containing the engine core, real lane engines,
   PRBS controller, quad controller, and reset policy.
4. Test request 1 and request 2, recovery under both toggle polarities, RX-clock
   pause, post-capture restart, and the next command.
5. Add persistent restart count/cause diagnostics.
6. Define a data-integrity-loss event from sustained `RXPRBSERR`, with assertion
   and clean-recovery hysteresis. Do not label it physical CDR loss.
7. Run the deferred transient-error experiment to select the threshold.
8. Freeze one candidate with source, ELF, and bitstream hashes plus raw console
   logs.
9. Run fresh-clean, repeat-clean without reload, forced acquisition recovery,
   post-recovery clean, transient injection, and runtime FireFly-outage gates.

The key correction is conceptual: acquisition recovery and runtime loss
detection are separate problems. The present plan has combined them, and the
resulting reset machinery is now creating a new protocol hazard before the
original runtime detector has been fixed.
