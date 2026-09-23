# Isolated diagnostic v274 / 2.5.24 — heartbeat-monitor test hook

Date: 2026-09-13. Firmware and hardware identity are `0x00020118`. V274 is a
diagnostic fork of v273. It preserves the planned external-startup restart and
runtime-integrity policy, and adds one default-off test hook that can suppress
only the signal presented to the shared-RXUSRCLK2 heartbeat monitor.

This target does **not** stop RXUSRCLK2, reset the GT Wizard, disturb the
physical quad clock, or claim optical LOS/CDR loss. It tests the detector's
missing-heartbeat branch through controlled monitor-input suppression. An
actual missing physical RXUSRCLK2 remains outside the evidence boundary.

## Implementation

With `INTEGRITY_HEARTBEAT_TEST_HOOK=1`, global-lane-15's existing error-toggle
bit gates `rx_clock_heartbeat_divider[15]` before the runtime monitor's normal
two-register synchronizer. The GT clock and the separately reported managed
RX clock remain live. Toggling the control to assert and restore suppression
also generates one lane-15 TX-error pulse at each edge; each isolated pulse is
far below the 100-ms consecutive lane-data threshold.

Selector `0xFD` capability bit 2 advertises the hook. V274 therefore expects
capabilities `0x7`; historical targets retain the parameter default of zero.

The complete Vivado unit regression passed before the build, including the
missing-heartbeat timeout, recovery, atomic platform-fault publication,
two-cycle lane-data non-trip control, controller shutdown behavior, and exact
synthetic platform-failure records. Decoder tests pass with capability bit 2.

## Build and independent audit

The first firmware invocation failed before compilation because the batch
shell did not have `mb-gcc` on `PATH`; the empty directory is preserved as
`build/firmware274.failed-missing-path`. Loading the Cornell Vivado 2023.2
environment and rerunning the fixed firmware helper produced the matching
ELF. No partial firmware was reused.

The build used the exact v273 routed checkpoint (SHA-256
`b31c17fbb6825aa650ffaa8f2e1f5775b1e5dae429fcb50a6f0f6be64a56e6ae`).
Vivado rejected incremental synthesis because the design changed and completed
a normal synthesis instead; implementation then used incremental placement and
routing. Final reuse was 93.40% of cells and 82.18% of nets.

The compressed implementation and independent routed audit pass:

- sign-off WNS/WHS are `+0.009/+0.001 ns`, with zero failing setup, hold, or
  pulse-width endpoints;
- routing has zero errors, failed nets, partial nets, and overlaps;
- routed DRC has zero errors and the familiar single `RPBF-3` generic-I2C
  buffering warning;
- `clk_100_raw` and `clk_325_raw` are exactly 100.000 and 325.000 MHz;
- all 16 descriptor endpoints retain their 3.000-ns bounds; worst slack is
  `+1.568 ns`;
- the four managed channels occupy `GTYE4_CHANNEL_X0Y16`–`X0Y19` and retain
  the audited golden RX properties;
- compression, profile direct-source structure, runtime synchronizer count and
  `ASYNC_REG` properties all pass explicit checks;
- a v274-specific routed fan-in check proves
  `tx_error_inject_toggle_reg[15]` feeds the runtime monitor's
  `heartbeat_meta_reg` input cone.

The isolated target still has no bus-skew constraints. Existing generated-IP
and intentional CDC/methodology findings remain. The hook changes the heartbeat
crossing from one `CDC-3` direct synchronized path to one `CDC-10` path because
the deliberate test gate is combinational before the synchronizer; aggregate
counts consequently change from CDC-3 72 / CDC-10 23 in v273 to 71 / 24 in
v274. The two-stage synchronizer and 100-ms qualification remain intact. This
target must not be described as globally CDC-clean.

Artifact SHA-256 values:

- bitstream: `0dd18f901c69f43e51a80aeb5e9e0727b8842e9aa98f69565af3ee07f48ad80a`
- routed DCP: `c0912134431157db71c7dc1759a7ea02ed633e28875717d6dfc25f908c632693`
- ELF: `dc20fc8b37d19d393f031786df21313df5aee9dc82f21ef0c1102ee5e5b1d7b0`

## Hardware gate

The reviewed procedure ran once through the fixed helpers, without retry.
Serialized preflight captured the v273 retained sequence/run-ID-5 state,
322.260-MHz managed RX clock, FPGA temperatures 25.5/24.5 C, clear regulator
status, enabled F1_5 outputs, and current module alarms.

The hash-pinned v274 image was programmed through `board_program.py v274`. The
programmer output omitted its final completion banner and the first immediate
generic-port read returned one address-ack error. No reload was retried; a
serialized repeat confirmed exact v274 firmware/hardware, healthy IDLE, and
sequence/run ID 0. The Apollo bundle was then redeployed and hash-verified.

Exactly one clean 10-second sequence/run-ID-1 baseline passed. All four profiles
measured 3,222,603,314–3,222,603,315 cycles with zero errors. Integrity count
was zero; planned-startup cause 4 plus cleanup cause 3 completed; the trace held
121 events without overflow. Physical managed RX clock was 322.263/322.261 MHz
before/after and F1_5 temperature was 38 C before/after.

With that precondition satisfied, `board_v274.py heartbeat2` armed its XSDB
watcher against exact v274 IDLE sequence/run 1 before submitting sequence 2.
At 250 ms into RUN the watcher toggled only bit 15 at AXI `0x44a00060`. It
observed the platform fault 119 ms after starting the write and restored the
monitor input 6 ms later. Exactly two writes were made; no halt, reset, or
programming occurred in the watcher.

Sequence/run 2 published retained platform fault `0x04000404`, stage 27, one
integrity event, retained clock cause set, retained data lanes clear, selected
lanes `0xF`, and exact synthetic failure records. The quad was READY with no
fault/reset in both live and first-fault words. Managed RX clock was 322.260 MHz
both before and after. Lane 15's two toggle edges produced the expected
two-cycle profile pulse; lanes 12–14 were clean. The trace retained 73 events
without overflow.

Post-test serialized health recorded 322.261-MHz managed RX clock, clear
regulator status, FPGA temperatures 26.0/24.5 C, and enabled F1_5 outputs.
F1_5 module byte 3/5 read `FF/00` after the controller disabled the checker;
this is not detector evidence and is not called optical LOS/CDR loss.

F1 now runs v274 in retained sequence/run-ID-2 platform fault. No retry, later
request, reset, or reload occurred.

Evidence SHA-256 values:

- clean baseline JSON: `e3b02995437d9c2ea8eb702be5d58c36bb2fac16fd503acf4144e3dd89ebfa9c`
- heartbeat-gate JSON: `ebf1d22447e725dfe7d8300ea1c9dcbd8386ab0a4f96da4a8c976ab593b359c0`
- XSDB watcher log: `129ddc7cd712730053fd2cd4970cf6a4eede967917fc1a9629509211fff78612`

This validates the controlled heartbeat-monitor branch, not actual physical
RXUSRCLK2 disappearance and not optical/native lock loss.
