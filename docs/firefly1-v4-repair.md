# FireFly-1 v4 diagnostic repair

Updated 2026-09-16. This is the isolated twelve-lane PMA-loopback target,
firmware/hardware `0x00020303`, not full-image or external-link qualification.

## Findings and evidence

V3's pre-RUN `0x0c000c04` result established a PRBS-controller fault, not a
measured RX-reset or native lock-loss failure. Its detailed FE words were
hardwired zero and its `0x2800` lane records were synthetic. Its polarity
hypothesis was not demonstrated; the proposed physical P/N swap was withdrawn.

V4 forwards the missing staged-acquisition/qualification parameters to all
three native controllers, preserves direct P/N wiring and zero polarity,
and exposes retained per-quad first-fault diagnostics through the existing FE
layout. The selected snapshot is the first faulting quad (lowest index for
simultaneous faults); the current FE layout does not identify that quad index.

Expanded methodology review rejected the first v4 bitstream
`727d63005cc97c45c87833749f48b6b9a9b87b333b2c362bad09c5a78b141ee5`:
the board-pin constraint override omitted reference-clock declarations.
Declaring the GT and monitor clocks exposed real timing failures in its
placement. It was not programmed. Its bit/DCP are retained under
`build/diagnostic_archive/firefly1-v4-before-clock-repair/`.

The subsequent clock-repaired revision passed independent audit:

- Bit SHA-256: `fe21094d2a204fade6b2eb957c47bbd074c2a6f917ec59a4c34fa5ca3cb1bfc4`.
- ELF SHA-256: `abe06ba6f83ca94b0748076092c9bd3a2763d338987edfa14eb1e73d64956ab2`.
- WNS/WHS +0.244/+0.010 ns, zero routing/DRC errors; compressed.
- Twelve channels X0Y4–X0Y15, commons X0Y1–X0Y3; golden RX properties.
- Three RX and three TX clocks; no TIMING-17/TIMING-26 findings.
- All 48 descriptor endpoints meet explicit 3-ns datapath bounds; three
  3-ns bus-skew bounds pass, worst slack +1.326 ns.
- Log: `build/logs/audit_firefly1_loopback_v4_bitstream-20260916T154547Z.log`.

That revision programmed with `PROGRAM_F1_COMPLETE` and matching fresh
identity, then failed its one fixed ten-second sequence/run 1. Summary
`0x05070c01`: lanes 0, 1, 5, 6, 9 saturated their native counters; the other
seven were clean. All recorded zero native lock losses. A subsequent retained
platform reason `0x20` captured RX reset-done low after publication, with
the PRBS controller already IDLE. The changing failing-lane subset does not
support the earlier fixed polarity-mask hypothesis.

Raw evidence is in `build/diagnostic_archive/`:

- `firefly1-v4-program-1789573609527798.log`
- `firefly1-v4-status-1789573667.log`
- `firefly1-v4-start-1789573673.log`
- `firefly1-v4-results-1789573694.log`

## PMA source repair

The controller's `applied_loopback` decode omitted RX_CHECKER_SETTLE (20),
ERROR_FREE_QUALIFY (21), and POST_LOCK_COUNTER_SETTLE (26), switching PMA
loopback off during acquisition/settling and back on afterward. A new
continuous-control assertion failed at state 20 with the old code:
`build/logs/run_milestone3_unit_sim-20260916T154909Z.log`.
Adding those three states preserves PMA loopback through capture.

Cleanup could accept a stale high reset-done before the short reset request
and control changes propagated through the Wizard. A delayed-status model
reproduced premature IDLE independently:
`build/logs/run_prbs_pma_regression-20260916T155023Z.log`.
The repair holds the intentional-reset guard for the existing bounded
post-capture settling interval (100 ms), then requires healthy synchronized
reset-done within the existing timeout. It does not mask measurement faults.
The focused regression passes with both fixes:
`build/logs/run_prbs_pma_regression-20260916T155136Z.log`.

The development replacement retains the v4 firmware/ABI but has a distinct
bit hash. `rebuild_firefly1_v4_pma_repair.tcl` archives the exact failed
bit/DCP/audit under `firefly1-v4-first-hardware-revision/` before resynthesis.
No earlier artifact is relabeled or accepted as the replacement. The user
explicitly authorized evidence-preserving repair/rebuild/retest continuation.

Full regression passes all thirteen self-checks; the replacement build and
independent audit pass:

- `build/logs/run_milestone3_unit_sim-20260916T155313Z.log`
- `build/logs/rebuild_firefly1_v4_pma_repair-20260916T155314Z.log`
- `build/logs/audit_firefly1_loopback_v4_bitstream-20260916T160438Z.log`

Replacement bit SHA-256:
`d54a0d71aa0f53ae3c0089875655b7951814535e78463ab35c93452b2b99240d`.
ELF is unchanged. Routed WNS/WHS +0.208/+0.010 ns; no routing/DRC errors,
48 descriptor bounds and three bus-skew bounds pass (worst skew slack
+1.368 ns), six native user clocks present, no TIMING-17/TIMING-26.
That replacement programmed with a completion marker and measured twelve
identical clean records: 257,808,261,600 bits / 3,222,603,270 cycles per lane,
zero errors/losses, summary `0x000c0c01`. However, final healthy IDLE failed:
retained reason `0x20`, PRBS controller already IDLE, RX reset-done low at
first fault. Evidence: `firefly1-v4-results-1789574820.log`, programming
`firefly1-v4-program-1789574733434964.log`, start `firefly1-v4-start-1789574803.log`.
This confirms the measurement repair, but not the complete hardware gate.

The fixed settling guard alone did not establish reset acknowledgement.
A regression with reset-done dropping after the guard interval reproduces
premature IDLE (`run_prbs_pma_regression-20260916T160816Z.log`). Cleanup now
requires a low observation from the Wizard and each selected lane, followed
by all healthy high levels, within the existing timeout. The clean-measurement
revision is preserved by `rebuild_firefly1_v4_reset_ack.tcl` under
`build/diagnostic_archive/firefly1-v4-clean-measurement-revision/`.
Programming is blocked pending the new simulation/build/audit and hash pin.
The first reset-acknowledgement build (`cd9c92cf2079cc728772427e62ff4667ba9e48cb2e912c28c8535d4027327d6c`)
met timing but FAILED the new structural audit: no acknowledgement registers
were found even by an unrestricted cleanup-name netlist search. It was not
programmed. Automatic incremental synthesis was used; a fresh synthesis with
reuse disabled is now testing whether that is the cause. Do not call the
incremental checkpoint a valid implementation of the handshake repair.
`rebuild_firefly1_v4_clean_synth.tcl` preserves it under
`firefly1-v4-rejected-incremental-reset-ack/`, checks the fresh synthesis for
all three Wizard acknowledgement registers, and only then permits implementation.
Current log: `build/logs/rebuild_firefly1_v4_clean_synth-20260916T162239Z.log`.
Clean synthesis passed the three-register structural gate and implementation
started, unlike the missing-register incremental result with identical source.
The v4 project now disables automatic incremental synthesis. The independent
routed audit still requires all three Wizard and twelve lane acknowledgements.
Evidence boundary: the missing-logic incremental finding also means the
earlier hardware cleanup failure cannot, by itself, establish that the intended
100-ms RTL guard was present and insufficient. The delayed-status regressions
prove the need for acknowledgement in the source model; fresh synthesis and
routed structure are required to establish what is actually tested in hardware.
The fixed launcher submits sequence 1 only
after replacement programming and verified fresh IDLE; it cannot retry a
consumed request on the retained failing image.

## Clean-synthesis artifact

The replacement passes full regression, compressed build, and independent
routed audit at WNS/WHS +0.206/+0.010 ns, no routing/DRC errors. All three
Wizard and twelve per-lane cleanup acknowledgement registers are present.
The audit additionally reconstructs bus-skew constraints from actual routed
descriptor drivers; all three pass, worst slack +1.212 ns. All 48 descriptor
datapath bounds pass and no TIMING-17/TIMING-26 findings remain.

- Bit SHA-256: `cc450c14786a2a00fca7ad844d47be7e5438d160590b463f8f2bd85ffc17443a`.
- ELF SHA-256: `abe06ba6f83ca94b0748076092c9bd3a2763d338987edfa14eb1e73d64956ab2`.
- Full regression: `build/logs/run_milestone3_unit_sim-20260916T160913Z.log`.
- Delayed/missing acknowledgement tests: `build/logs/run_prbs_pma_regression-20260916T160934Z.log`.
- Build: `build/logs/rebuild_firefly1_v4_clean_synth-20260916T162239Z.log`.
- Audit: `build/logs/audit_firefly1_loopback_v4_bitstream-20260916T163340Z.log`.

The programmer is pinned to this artifact. Hardware retest PASSED.
The collector observes beyond the fixed ten-second cleanup timeout, then
requires clean records, no retained fault, quad readiness, and controller IDLE.

Final sequence/run 1 returned `0x000c0c01`; all twelve lanes have zero errors
and native lock losses. Lanes 0–3 each recorded 257,808,256,480 bits /
3,222,603,206 cycles; lanes 4–11 each recorded 257,808,256,560 bits /
3,222,603,207 cycles. The independent RX clock domains differ by one cycle.
Final C8=0, FE platform=0x40, all retained fault words zero, live controller
IDLE, quad READY. Final F1 temperature 28.765625 C, AVTT 1.2001953125 V;
monitor status 0x434da501 and 100.000/325.000/FF1 322.260-MHz clocks healthy.

Final raw evidence under `build/diagnostic_archive/`:

- `firefly1-v4-program-1789576480591827.log` (completion marker present)
- `firefly1-v4-status-1789576539.log` (fresh identity/IDLE)
- `firefly1-v4-start-1789576546.log`
- `firefly1-v4-results-1789576567.log`

No further request/reload was performed after this passing gate. Keep the
consumed sequence and final healthy state intact. The build/debug skills
guided preservation of failed artifacts, targeted regression reproduction,
restart from the earliest invalidated stage, and independent routed checks.

## Remaining evidence limits

CDC unsafe/unknown crossings outside the descriptor repair remain. Inherited
native-IP max-delay overrides and monitor/I2C/debug methodology warnings are
not a completed CDC qualification. Implementation's 101 critical warnings
are 100 inactive non-FF1 TX-port LOC warnings and one unused q124 IP scope.
Internal PMA tests do not establish external optical behavior, LOS/CDR-loss
response, or long-term qualification. Existing x4-module FF/FF alarms were
preserved; no optical stimulus was applied.
