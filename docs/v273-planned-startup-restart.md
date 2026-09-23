# Isolated diagnostic v273 / 2.5.23 — planned startup restart

Date: 2026-09-13. Firmware and hardware identity are `0x00020117`. V273 is a
diagnostic fork of v272: it preserves the v272 runtime-integrity policy and
adds one default-off, v273-only coordinated full-quad restart after the stable
external lane mask and PRBS controls have been accepted. Historical targets,
including v272, retain their behavior.

The planned event is recorded as restart cause 4. It consumes the existing
one-recovery budget, so a bad post-restart acquisition faults at stage 25
instead of silently receiving a second restart. Ordinary post-run cleanup
remains cause 3; cause 2 remains reserved for the legacy reactive acquisition
recovery.

## Verification and build

The focused simulation verifies one cause-4 restart followed by clean
acquisition and verifies that a bad post-restart qualification faults without
a second restart. The complete Milestone simulation regression passes.

Matching firmware, compressed incremental implementation from the exact v272
routed checkpoint, build-time structural checks, and an independent routed-
checkpoint audit pass. The routed result has WNS/WHS +0.009/+0.001 ns, zero
routing errors, and zero DRC errors. The existing `RPBF-3` generic-I2C warning,
reviewed CDC/methodology findings, and absence of isolated-target bus-skew
constraints remain. All 16 descriptor endpoints meet their 3.000-ns bound
(worst slack +1.568 ns), profile measurement/epoch sources remain direct and
registered, and the runtime-integrity synchronizer structure passes audit.

- Compressed bitstream, 32,334,408 bytes, SHA-256
  `84a2d4db34f8ac4437dbec6f89fb2931f76f663a1846ba5b1e7d2075b08cfedf`.
- Routed DCP SHA-256
  `b31c17fbb6825aa650ffaa8f2e1f5775b1e5dae429fcb50a6f0f6be64a56e6ae`.
- Matching ELF SHA-256
  `e32976fabe1e7834fc34c14db21829b25741386278663869bb544c4721beb62b`.
- Incremental reference: exact v272 routed DCP SHA-256
  `237986f4032c2753fa2d1a104b62a64e2145101f3fe37d4848252d004b0b31e9`.

Reproducible entry points are
`scripts/build_milestone273_firmware.sh`,
`scripts/build_milestone273_bitstream.tcl`, and
`scripts/audit_milestone273_routed.tcl`. The one-time resume driver documents
continuation after the initial synthesis guard used the wrong instance name;
synthesis itself completed with zero errors and was not rerun.

## Hardware result

F1 was programmed once through the fixed, hash-pinned helper. Fresh FW/HW
identity was `0x00020117`, IDLE, with zero request/response/run IDs. Two unique
consecutive 10-second four-lane external requests then passed without reload,
retry, reset, or stimulus.

For both runs:

- request sequence, response sequence, and run ID advanced exactly once;
- restart counters advanced exactly twice: planned cause 4 followed by normal
  cleanup cause 3;
- the trace contains the planned state-1 to state-23 transition and no
  state-25 to state-23 reactive recovery;
- all four profiles are complete and nearly equal, with zero errors and zero
  native lock losses;
- the runtime-integrity event count remained zero and the trace did not
  overflow.

Run 1 retained 124 trace events and 3,222,603,319 profile cycles on lane 12
(3,222,603,320 on lanes 13–15). Run 2 retained 126 events and 3,222,603,296
cycles on every lane. Managed RXUSRCLK2 was 322.262/322.261 MHz around run 1
and 322.261/322.260 MHz around run 2. F1_5 was 38 C around run 1 and 37–38 C
around run 2. Post-run `clk_100`/`clk_325` were 100.000/325.000 MHz, managed
RXUSRCLK2 was 322.260 MHz, FireFly output-control bytes were `00`, and both
regulator status words were zero.

This is conclusive evidence for the narrow startup question: applying the
coordinated restart deliberately after controls consistently prevents the
100-ms all-lane checker-error condition that forced reactive cause-2 recovery
in v272.

## Runtime-integrity hardware gates

The first sequence-3 pulse launch did not deliver a stimulus. The fixed XSDB
watcher reached its first check only after the engine had entered RUN, rejected
the unexpected state, and exited without a write. Sequence 3 therefore
completed as another clean 10-second baseline. It had planned cause 4 plus
cleanup cause 3, zero errors and integrity events, and 126 trace events without
overflow. The sequence was preserved and was not reused or silently retried.

The launcher was then made race-free: it waits for the watcher to emit its
fixed `ARMED v273` acknowledgement before submitting the descriptor. Unique
sequence 4 passed the short-pulse gate. Exactly one write asserted lane 12's
injection control for the watched two cycles. Lane 12 recorded exactly two
error/profile cycles at profile cycles 110,804,087 and 110,804,088; lanes
13–15 stayed clean, the integrity count remained zero, and the run ended
healthy IDLE with planned cause 4 plus cleanup cause 3 and no reactive cause 2.
The trace retained 127 events without overflow.

Unique sequence 5 then disabled only F1_5 channel 0 for 250.304 ms and restored
FireFly byte 86 to zero. It correctly retained response/summary `0x04000404`,
fault stage 27, exactly one integrity event, lane 12 as the sole retained data
cause, and no shared-clock cause. Lane 12's completed profile contained one
32,226,039-cycle consecutive error interval ending at measurement stop; lanes
13–15 had zero profile errors. At the first-fault snapshot all four synchronized
`RXPRBSLOCKED` inputs were asserted. They later deasserted when the retained
PRBS-controller fault intentionally disabled the checker. The quad supervisor
remained READY: its reset-done, user-clock, QPLL, and power qualifiers stayed
healthy, and it did not assert the Wizard reset. The ordinary `0x280c`–`0x280f`
lane publications are deterministic management-domain platform-failure records;
their lock-loss flag and count of one are failure markers, not sampled lane
lock-loss counters. Sequence 5 therefore supplies no measured native lock-loss
count, rather than proving either zero or one loss. The trace retained 75 events
without overflow.
The full simulation regression now asserts this exact post-fault distinction:
checker shutdown may remove modeled `RXPRBSLOCKED`, the quad must remain READY
without asserting its global reset, and all selected lanes must receive the
defined synthetic platform-failure record. The regression passes. Its
fresh-start bookkeeping was also corrected to clear testbench-only run-ID
history across the deliberate management reset; no RTL behavior changed.
The v273 wrapper used the correct `0x00020117` identity and `V273` validation
label, but the shared validator's final success banner was still hard-coded as
`V272`; that presentation-only defect was corrected afterward to use the label
variable. It did not affect the fixed inputs, validation, or captured JSON.

These results pass the planned-startup question, short-transient rejection,
and sustained lane-data detector gate. They do not establish optical LOS/CDR
behavior, exercise missing RXUSRCLK2, or constitute full qualification. Raw
FireFly alarm bytes
remain subject to the known module/address/display reconciliation and are not
interpreted as LOS or CDR status here. V272 remains frozen and available as
the fallback.

At the end of the v273 work, hardware was in the retained sequence/run-ID-5
platform fault. The later explicitly authorized v274 gate supersedes that
state; see `docs/v274-heartbeat-test.md`.

The next qualification target should preserve v273's planned-startup policy.
Its remaining new detector gate is missing shared RXUSRCLK2, which requires a
separately reviewed stimulus that stops the monitored fabric clock without
mislabeling it as lane-local CDR or optical loss. Preparing or programming that
target must not implicitly clear the current retained evidence.

Generated evidence:

- `build/diagnostic_archive/v273-planned-startup-clean1.json`, SHA-256
  `da292f8c2c9fca0a2d7facd7334eb8374d78d12593ad3386c917483ee2290d68`.
- `build/diagnostic_archive/v273-planned-startup-clean2.json`, SHA-256
  `6d263e808d945c2bb50c8a141a1c0bfce6769099930ebb380872f52d70072e7a`.
- `build/diagnostic_archive/v273-run3-pulse.json`, the preserved clean
  no-stimulus run, SHA-256
  `815694c37d73ef1f79f69264faba93ed4ba702e91f2054e2813e92ea3b221272`.
- `build/v273-run3-xsdb.log`, the no-write refusal, SHA-256
  `5256f9d7ce4b6bf9d3bfe0f813d77248f9bcc7cb008a957e12320903834155c4`.
- `build/diagnostic_archive/v273-run4-pulse.json`, SHA-256
  `880faee1dfdbaf5dd9838597dde442a98548c51899f940c3047008d28ecb659f`.
- `build/v273-run4-xsdb.log`, SHA-256
  `f595ebe9339748d27f09aea4a9dd86f90299a306082d36ab317201f1174020a7`.
- `build/diagnostic_archive/v273-run5-firefly250ms.json`, SHA-256
  `fff46de9abb811f79f3836942bb74ddf9161fce499c1bc81e4dfc80bd35373f0`.

Apollo originals remain under `/tmp/v273-diagnostic-20260913/`. Generated
`build/` products are not committed.
