# V272 startup-recovery investigation

Date: 2026-09-13. After preserving the completed runtime-integrity gate, F1
was explicitly reloaded once with the same audited v272 / 2.5.22 image to clear
the retained platform fault. `scripts/board_program.py v272` verified the
bitstream SHA-256
`7ca91032b55f3e71a97dd27678ab5b1bf9b00cbd0d105646cdcdc0666147215d`.
Fresh firmware/hardware identity was `0x00020116`, engine state was IDLE, and
request/response/run IDs were zero.

Preflight was serialized through the approved project launchers. Required
clocks were present (`clk_100=100.000 MHz`, `clk_325=325.000 MHz`, managed
RXUSRCLK2 `322.261 MHz`), both regulator status words were zero, both FireFly
output-control bytes were `00`, and FPGA temperatures were F1 25.5 C/F2 24.0 C.
The reviewed Apollo copies of all diagnostic dependencies matched their local
SHA-256 identities before use.

## Single startup result

Exactly one fresh sequence-1, run-ID-1 10-second clean request was submitted.
It completed with matching response sequence, summary/response `0x00040401`,
healthy IDLE, four equal complete profiles, and zero measured errors or native
lock losses. The online validator stopped with the expected restart-delta
failure: requested/accepted/completed counters advanced from 0 to 2, comprising
one acquisition cause-2 full-quad recovery and ordinary cause-3 cleanup. No
retry or second request was issued.

Trace epoch 1 retained 139 records without overflow. On the first acquisition
attempt:

- all four synchronized native `RXPRBSLOCKED` bits, all four `RXCDRLOCK` bits,
  TX/RX reset-done, PMA-done, and the shared RX clock were asserted;
- the fixed 1-ms observation implicated all four lanes in PRBS-error activity;
- the aggregate selected-lane error indication never produced one clean
  management cycle during the following 100-ms qualification window, so the
  retained maximum clean streak is zero;
- state 25 (`ST_EXTERNAL_FAILURE_QUALIFY`) began at trace tick 337,938 and
  entered state 23 (`ST_QUAD_RESTART_REQUEST`) at tick 20,337,938, exactly the
  configured 20,000,000 management cycles later.

The trace does not prove that every lane was error-active on every cycle: it
proves that each lane was observed error-active and that their aggregate never
went clean. Native lock remained asserted throughout the failed qualification.
After the coordinated full-quad restart, the same selected mask reacquired,
passed the fixed observation and post-lock settling, and measured cleanly.

This reproduces the prior v272 behavior after a fresh FPGA reload and rules out
a one-time stale retained-fault state. It identifies an all-lane PRBS checker/
data-path startup condition while controls are applied to an already-running
external RX path. A simple longer settle or counter-reset delay is not supported
by the evidence because the condition persists for the full 100-ms window.

## Design decision required

The only demonstrated operation that clears the condition is the coordinated
full-quad restart after PRBS controls have been applied. Making that restart
mandatory would conflict with the current external-mode invariant that keeps
an already-live RX datapath out of reset. Do not implement that policy change
or relabel the bounded recovery as a clean baseline without an explicit design
decision. The alternative is to retain the present one-shot recovery and make
it an accepted, visible startup outcome rather than a qualification failure.

## Subsequent v273 diagnostic decision

The explicitly authorized v273 experiment implemented that restart as one
planned, visible cause-4 event after controls settled while leaving v272
unchanged. Two consecutive unique 10-second baselines passed with no reactive
cause-2 recovery. This resolves the narrow experiment in favor of the planned
startup behavior for the next candidate; v272 remains frozen as the fallback.
See [the v273 record](v273-planned-startup-restart.md).

F1 remains v272 healthy IDLE at request/response/run ID 1. Post-run required
clocks, output controls, regulator status, and temperatures were healthy; final
FPGA temperatures were F1 26.0 C/F2 24.0 C. No second run, stimulus, reset, or
reload followed.

Evidence:

- `build/diagnostic_archive/v272-postfault-reload-run1-startup.json`
  SHA-256 `d2a8a8338bbeb8eeac37a9bd4f503e5362dacf4afe93727f849d52203539292f`.
- Apollo original:
  `/tmp/v272-diagnostic-20260913/postfault-reload-run1-startup.json`.

Generated raw evidence remains under `build/` and is not committed.
