# All-direct v10 build and hardware gate

Date: 2026-09-18

## Later authorized resume (historical addendum)

After the initial launcher failure and bounded lease expiry documented below,
an explicitly authorized asymmetric resume reached the external measurement.
F1 published a normal clean 54-lane run-2 result (`0x00363601`) and later
stopped cleanly at sequence 5. F2 failed at `CAPTURE_DONE`, returning
`0x36003604` with retained cleanup reason `0x20`; its retained snapshot had
Wizard, selected RX, and selected PMA reset-done low for selected mask `0xC`.
F2 remained in platform fault at sequence/ack 3, run 2. The launcher therefore
reported `F2 response/run failure`; no retry followed. Evidence is
`build/diagnostic_archive/all-direct-v10-external-resume-1789731954005232.log`.

V11 extended the intentional RX-change guard through capture completion and
allowed both external publications to complete cleanly, but exposed a distinct
stale Wizard-aggregate timeout during post-capture requalification. V12 made
that qualification per-lane and passed the complete scoped gate. See
`docs/direct-all-v12-hardware-gate.md`. This addendum supersedes the older
"no external measurement" resume point below without changing its record of
the first failed launcher attempt.

## Outcome

The symmetric all-direct v10 image, FW/HW identity `0x00020407`, is loaded on
both FPGA sites. Its clean compressed implementation and independent routed
audit pass. Each FPGA independently passed one fresh 10-second, all-56-lane
near-end PMA PRBS31 gate with zero errors and zero native lock losses.

The single authorized external attempt did not reach an RX measurement. F1
successfully established its bounded TX session, but the host launcher rejected
the correct new active/applied status bit pattern. F2 TX was never started and
neither endpoint received a measurement request. This is a launcher failure,
not a direct-link BER result. No retry, reload, or reset followed.

## V10 changes

V9 could acknowledge a TX-session request before every TX-domain control had
actually applied PRBS31. V10 adds one applied acknowledgement per managed quad,
synchronizes it back to management, and requires the aggregate acknowledgement
before accepting an external RX request. The fourteen acknowledgements are
aggregated through the existing four physical SLR groups so there is no direct
fourteen-way cross-SLR timing path. Firmware waits for active plus applied before
acknowledging a start, and waits for both to clear before acknowledging a stop.

The direct target also enables RX requalification after PMA cleanup and retains
the bounded post-cleanup IDLE guard. Historical targets keep their existing
policy.

## Simulation, implementation, and audit

The following regressions pass:

- full managed-engine unit simulation;
- dual-endpoint window simulation;
- FireFly TX-session simulation;
- all-direct engine simulation;
- all-direct SLR-group aggregate simulation; and
- 23 Python firmware/launcher/programming contract tests.

The first v10 incremental implementation exposed a real fourteen-way
cross-SLR applied-acknowledgement path and failed timing. After adding the
physical SLR-group pipeline, an implementation reusing the v9 placement still
failed because of localized congestion. Both failures are preserved and were
not promoted. A clean, non-incremental implementation from the corrected
synthesis closed timing and generated the candidate.

Signoff results:

- WNS `+0.084 ns`, TNS `0`;
- WHS `+0.010 ns`, THS `0`;
- zero unrouted or partially routed nets;
- zero routed DRC errors;
- all fourteen 3-ns bus-skew constraints met, worst slack `+1.592 ns`;
- all 56 channel primitives match the golden IBERT property reference;
- all 14 dedicated common REFCLK routes are present; and
- all 112 common-QPLL0-to-channel connections are exact.

The focused routed inspection also found all 14 cleanup controllers, 14
retained IDLE guards, 56 lane cleanup acknowledgements, 14 TX-domain request
pairs, and 14 management-domain applied-acknowledgement pairs.

Artifact SHA-256 values:

- bitstream: `220e27906cb3433527420615b9e3fa61a26cf2954c365596394cb6e4f615f458`;
- routed DCP: `09e3e226f9aeaf0716f3a444f47d8eb4412d466ad4f3233eae1064db8e51b185`;
- firmware ELF: `c4893050ae26e28ad09b1bd85f7dbce106812400d50dc658052a53fe6917a151`.

Principal logs:

- `build/logs/run_milestone3_unit_sim-20260918T001628Z.log`;
- `build/logs/run_dual_endpoint_window_sim-20260918T001903Z.log`;
- `build/logs/run_firefly1_v5_session_sim-20260918T001916Z.log`;
- `build/logs/run_direct_all_v7_engine_sim-20260918T001934Z.log`;
- `build/logs/run_direct_all_v7_quad_aggregate_sim-20260918T010011Z.log`;
- `build/logs/run_direct_all_v10_clean_impl-20260918T012923Z.log`;
- `build/logs/inspect_direct_all_v7_cleanup_structure-20260918T014642Z.log`;
- `build/logs/audit_direct_all_v7_routed-20260918T014735Z.log`.

## Hardware record

Both sites were programmed once through the fixed, hash-pinned choices
`direct_all_v10_f1` and `direct_all_v10_f2`. Fresh preflight found matching
FW/HW identity, sequence/run 0, healthy IDLE, valid required clocks, and no
retained fault.

F1 PMA sequence/run 1 passed all 56 lanes with summary `0x00383801`. Per-lane
records contained approximately 257,808,193,280 tested bits, zero errors, and
zero native lock losses. F2 remained fresh. F2 then passed its own sequence/run
1 with the same summary and approximately 257,808,196,080 tested bits per lane;
F1's publication remained unchanged. Both PMA requests are consumed.

Evidence:

- `build/diagnostic_archive/firefly1-v10-F1-program-1789729485955455.log`;
- `build/diagnostic_archive/firefly1-v10-F2-program-1789729623282929.log`;
- `build/diagnostic_archive/all-direct-v10-pma-f1-1789729694588506.log`;
- `build/diagnostic_archive/all-direct-v10-pma-f2-1789729726746331.log`.

## External launcher failure and final state

F1 accepted TX-session sequence 2 with a 180-second lease and returned success.
V10 mailbox state was `0x00320000`: capability bit 20, session-active bit 17,
and the new applied/ready bit 21. The launcher still expected the old exact
active state `0x00120000`, raised `F1 state/session mismatch`, and entered its
fail-closed cleanup path. Because that old cleanup predicate could not prove
the new state safe, it issued no stop command and relied on the already-bounded
lease. F2 remained at sequence/run 1; neither sequence-3 RX request occurred.

The launcher now requires both active and ready, rejects active-without-ready,
and has a regression test. The corrected bundle uses the fresh namespace
`/tmp/all-direct-v10r1-20260918`; deploying it did not touch hardware and does
not authorize another gate.

The final read-only snapshot proved automatic lease expiry and no retained
fault:

- F1: sequence/ack 2, run 1, IDLE, state `0x00140000` (capability plus expiry
  latch), clean PMA summary `0x00383801` retained;
- F2: sequence/ack/run 1, IDLE, state `0x00100000`, clean PMA summary retained.

Failure and final-state evidence:

- `build/diagnostic_archive/all-direct-v10-external-1789729763630531.log`;
- `build/diagnostic_archive/all-direct-v10-status-1789729969184330.log`.

F1 sequence 2 and both PMA sequence/run 1 requests are consumed. A future
external gate needs an explicitly reviewed asymmetric resume sequence; it must
not reuse the consumed `external` sentinel or assume both endpoints have the
same predecessor sequence. Do not reload, reset, replay PMA, or start another
external request without explicit authorization.
