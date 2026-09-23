# V272 runtime-integrity hardware gate

Date: 2026-09-13. F1 was explicitly programmed once with the audited isolated
v272 / 2.5.22 bitstream (`0x00020116`), SHA-256
`7ca91032b55f3e71a97dd27678ab5b1bf9b00cbd0d105646cdcdc0666147215d`.
The helper also verified the matching ELF hash. The JTAG chain contained F1
target 1, its running MicroBlaze target 3, and F2 target 4.

## Preserved preflight

Before programming, the complete v271 sequence/run-ID-6 publication was saved.
It remained healthy IDLE with summary `0x00040401`, four zero-error profiles,
one cleanup record, and no trace overflow.

After programming, v272 reported matching firmware/hardware `0x00020116`,
IDLE, zero request/response/run IDs, selector-`0xFD` capabilities `3`, zero
restart and integrity counters, PRBS-controller IDLE, and quad ready. The raw
snapshot was preserved even though the generic decoder correctly rejected the
empty run-ID-0 profile pages as incomplete.

Required clocks were present: `clk_100=100.000 MHz`, `clk_325=325.000 MHz`,
and managed RXUSRCLK2 `322.260 MHz`. Both F1AVTT/CC pages had zero status words.
F1 was 25.5 C, F2 was 24.0 C, and FireFly outputs were enabled. Raw FireFly
alarm bytes retained the familiar `FF/FF` behavior and were not interpreted as
live LOS/CDR state.

## Sequence 1 result

One unique 10-second four-lane external request was issued as sequence 1. It
completed at run ID 1 with matching response sequence, summary/response
`0x00040401`, and healthy IDLE.

- All lanes 12–15 were selected/locked and recorded zero errors and zero native
  lock losses.
- Each lane recorded 3,222,603,262 valid cycles and a consistent tested-bit
  count. Native profiles recorded 3,222,603,261 elapsed cycles, zero errors,
  and no saturation.
- Selector `0xFD` retained zero runtime-integrity events and no retained data
  or shared-clock cause.
- Trace epoch 1 retained 145 events without overflow.

The online validator rejected the run because restart requested/accepted/
completed counters advanced from 0 to 2, rather than the required single
cleanup. The trace shows the additional event before measurement: after the
fixed acquisition observation, state 25 (`ST_EXTERNAL_FAILURE_QUALIFY`) did
not obtain its required continuous clean interval within 100 ms and entered
state 23 (`ST_QUAD_RESTART_REQUEST`) at trace tick 20,350,715. The bounded full-
quad restart completed, acquisition then succeeded, the measurement was clean,
and the second restart was the ordinary post-run cause-3 cleanup. The retained
last-event record is therefore cleanup and cannot alone identify the earlier
event; the trace supplies that ordering.

## Explicit continuation and sequence 2

The user explicitly directed continuation with sequence 1 retained as a
recovered baseline. One unique sequence-2 10-second four-lane external request
was therefore submitted without a reload. It again completed with summary and
response `0x00040401`, matching run ID 2, healthy IDLE, four equal complete
profiles, zero errors, zero native lock losses, and zero integrity events.
Trace epoch 2 retained 147 events without overflow.

Sequence 2 repeated the startup behavior. Restart counters advanced from 2 to
4: one bounded full-quad acquisition recovery and one ordinary cleanup. The
trace again records state 25 entering state 23 before measurement, at tick
20,399,471. Thus the sequence-1 event was not merely a fresh-program anomaly.

## Explicit stimulus continuation

The user explicitly directed the gate to proceed while retaining both results
as recovered, rather than no-recovery, baselines. No reload or reset occurred.

Sequence 3 applied one watched two-cycle lane-12 error pulse during RUN. The
watcher verified the exact v272 identity, prior sequence/run ID 2, sequence 3
in RUN, and mask `0xF000`, then made exactly one `0 -> 0x1000 -> 0` toggle.
The run completed at sequence/run ID 3 with summary `0x01030401`. Lane 12
recorded exactly two error-active cycles (profile indices 121,328,755–756),
lanes 13–15 remained clean, and every native lock-loss count remained zero.
Selector `0xFD` retained zero integrity events. This passes the intended
short-transient non-trip control. Trace epoch 3 retained 140 events without
overflow. The known acquisition recovery recurred, so the legacy validator's
restart-delta check still rejected the run; offline checks of the stimulus and
published result passed.

Sequence 4 then disabled only F1_5 channel 0 for 0.250289 s during measurement.
The run ended at sequence/run ID 4 with response/summary `0x04000404` and the
retained platform-fault state `C8=0x00010000`. Fault stage 27 and one runtime-
integrity event were retained. The retained error-lane mask was lane 12 only;
the retained shared-clock cause was clear. Lane 12 recorded 32,226,040
consecutive error-active cycles in 133,462,772 elapsed cycles, from index
101,236,732 through 133,462,771. Lanes 13–15 remained clean and all native
lock-loss counts stayed zero. The shared RXUSRCLK2 monitor remained about
322.260 MHz, so this exercised the lane-data branch, not the missing-clock
branch. Trace epoch 4 retained 91 events without overflow. FireFly byte 86 was
restored to `00`.

One attempted sequence-4 launch was rejected locally during preflight because
the first validator incorrectly expected the measurement-only monitor-enable
bit to be asserted in IDLE. It submitted no request and made no FireFly write;
the rejected snapshot is preserved separately. The check was corrected before
the unique sequence-4 request.

## Outcome and current state

The v272 runtime-integrity detector passes the tested lane-12 hardware gate:
the known two-cycle pulse does not trip it, while a controlled 250-ms
lane-local corruption does trip it through fault stage 27 with the correct
retained lane cause and without a false shared-clock cause. This is not an
optical LOS or native CDR-loss claim, and missing shared RXUSRCLK2 has not been
tested in hardware.

V272 is not fully qualification-ready because both nominal baselines required
one bounded acquisition full-quad recovery before otherwise clean measurement.
At completion of this gate, F1 remained on the exact audited v272 image in the
retained platform-fault state at request/response/run ID 4. No reload or reset
immediately followed. Post-test required
clocks, module control restoration, regulator status, and temperatures were
healthy; final FPGA temperatures were F1 26.0 C and F2 25.0 C. Any next action
required an explicit reset/reload decision.

## Subsequent startup investigation

The retained fault was later cleared by one explicitly authorized reload of the
same hash-pinned v272 image. One fresh clean sequence/run-ID-1 request reproduced
the acquisition recovery: all native lock/reset/clock qualifiers were healthy,
all four lanes were observed error-active, and the aggregate selected-lane
error indication had zero clean cycles during the 100-ms window. The full-quad
restart then recovered and the 10-second measurement was clean. No retry was
issued. F1 now remains v272 healthy IDLE at request/response/run ID 1. See
[the startup-recovery investigation](v272-startup-recovery-investigation.md).

## Evidence identities

- `build/diagnostic_archive/v271-pre-v272-program.json`:
  `81f615bbc894306c481203c69f56bd7a6607b915dbbc84c99e1af19200a8fabd`
- `build/diagnostic_archive/v272-post-program.json`:
  `c72e284070bb771d7eca703af9a33127d7f20bd1b7149a2a0a95932e7e85bd18`
- `build/diagnostic_archive/v272-run1-clean.json`:
  `ecf4992fca41f2abe0ae62f2876a1f34b6c5c5e2f4a09e8e46db7c32cc4e4357`
- `build/diagnostic_archive/v272-run2-clean.json`:
  `1eaf68dbcf0f998418435e170108a0dc0978f429f5f358af695536e85cb93aec`
- `build/diagnostic_archive/v272-run3-pulse.json`:
  `664e8c2b887e1cd702f898a95dd5c18c35afb50e4c85e583297a204cdb025304`
- `build/v272-run3-xsdb.log`:
  `4c883b2c19bd253cd04b1cf94304c60ff2b16a62c799096fa24541b3a6629113`
- `build/diagnostic_archive/v272-run4-preflight-rejected.json`:
  `aadfe1d6c6d57c04a7be0da79e282608c7f2796ce47a2a3a783caa86cfdbaa65`
- `build/diagnostic_archive/v272-run4-firefly250ms.json`:
  `1395d17c41081e319db9ffeb54debb09396274d60c00a423214a5c2adaded7e7`

Apollo originals are under `/tmp/v272-diagnostic-20260913/`. Generated raw
evidence remains under `build/` and is not committed.
