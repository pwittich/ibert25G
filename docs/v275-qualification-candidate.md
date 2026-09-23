# Isolated v275 / 2.5.25 qualification candidate

Date: 2026-09-13 through 2026-09-14. Firmware and hardware identity are `0x00020119`. V275
freezes the hardware-supported policy: v272's 100-ms runtime-integrity
detector and v273's one planned coordinated startup restart. The v274
heartbeat test hook is explicitly disabled. Historical targets remain
unchanged.

## Build and independent audit

The complete simulation regression and matching firmware build pass. The
compressed implementation used the exact audited v273 routed checkpoint,
SHA-256
`b31c17fbb6825aa650ffaa8f2e1f5775b1e5dae429fcb50a6f0f6be64a56e6ae`,
as its incremental implementation reference. Synthesis correctly used the
default full flow after rejecting incremental synthesis for the changed
top-level identity/configuration. Routed reuse was 92.07% of cells and 80.56%
of nets.

The build-time checks and an independent saved-checkpoint audit pass:

- sign-off WNS/WHS are +0.009/+0.001 ns, with no failing endpoints;
- routing has zero errors and routed DRC has zero errors, with the familiar
  single `RPBF-3` generic-I2C buffer warning;
- the managed channels occupy `GTYE4_CHANNEL_X0Y16`-`X0Y19`, retain the golden
  RX properties, and all 11 IPs are up to date;
- implemented `clk_100_raw`/`clk_325_raw` periods are 10.000/3.077 ns;
- all 16 descriptor endpoints meet their 3.000-ns bound, worst slack +1.568 ns;
- profile measurement/epoch inputs have direct registered sources, all ten
  runtime-integrity synchronizers retain `ASYNC_REG`, and the heartbeat
  synchronizer fan-in contains the physical RX-clock divider but no diagnostic
  control;
- synthesis reports five state registers with FSM extraction disabled by the
  user attribute.

The incremental router emitted `[Route 35-4475]` for incomplete guidance on
three global clocks. It rerouted them successfully; final routing has zero
failed nets and independent sign-off passes. Routed CDC counts exactly match
v273: CDC-1=1, CDC-3=72, CDC-6=26, CDC-7=1, CDC-9=1, CDC-10=23, CDC-11=64,
CDC-13=16, and CDC-15=39. The methodology summary also exactly matches v273.
These reviewed generated-IP/reset/debug and other findings remain caveats; the
design is not globally CDC-clean. The isolated target has no bus-skew
constraints.

Artifact identities:

- compressed bitstream, 32,339,648 bytes:
  `92cf91bbfd2214f0349cb6155c527eddf198268a03585d25fbe715e84d90d08e`;
- routed DCP, 14,899,340 bytes:
  `c433e0a32de055e889d081c8f36bdd751af47cbdca18179bd6a511071b86f4a1`;
- matching ELF:
  `b72ac12cfa79d4e43d3b119eff74f1da7fa8b77b925a31618caa4576f5a58adf`.

Reproducible entry points are `scripts/build_milestone275_firmware.sh`,
`scripts/build_milestone275_bitstream.tcl`, and
`scripts/audit_milestone275_routed.tcl`.

## Initial F1 hardware gate

After a serialized preflight preserved the v274 retained fault, F1 was
programmed once through the fixed hash-pinned helper. The fresh mailbox showed
exact FW/HW identity `0x00020119`, healthy IDLE, and request/response/run ID 0.
There was no reset, retry, or second reload.

Two unique consecutive 10-second four-lane external baselines passed:

- sequence/run 1: four equal 3,222,603,336-cycle profiles, zero errors and
  native lock losses, two restarts (planned cause 4 and cleanup cause 3), zero
  integrity events, and 125 trace events without overflow;
- sequence/run 2: profiles of 3,222,603,267-268 cycles, zero errors and native
  lock losses, the same two expected restarts, zero integrity events, and 125
  trace events without overflow.

Both runs had exact request/response/run-ID progression and final healthy
IDLE. Managed RXUSRCLK2 was 322.262 MHz before/after both runs and F1_5 was
38 C. The final published records contain four passes and approximately
257.8 billion tested bits per lane. Post-gate board clocks were
100.000/325.000 MHz, managed RX was 322.262 MHz, output-control bytes were
zero, and both regulator status words were clear.

The raw evidence is immutable:

- `build/diagnostic_archive/v275-clean1.json`:
  `e351e35eab3ab0d90f077164bc220afe5f7b3916f3365123d0e2a3488f0e5b1d`;
- `build/diagnostic_archive/v275-clean2.json`:
  `bb5cdd661a57f26bff3fcd83cbc4758628ad645bc9ddbe207c3ee0da370ed7c0`.

After these short gates F1 remained on v275, healthy IDLE at
request/response/run ID 2. Module bytes 3/5 returned FF/FF in the final IDLE
read despite clean data and plausible RX power; retain the existing
module/address/state interpretation caveat and do not call this optical LOS or
CDR loss.

## Sequence-3 12-hour external soak

The fixed 12-hour helper submitted unique sequence 3 once at approximately
2026-09-13 16:20 EDT, without an FPGA reload. Its descriptor is external
PRBS31, lanes 12-15, duration 43,200,000 ms. The engine reached RUN with
request sequence 3 while response sequence and published run ID correctly
remained 2.

The first launcher version then incorrectly expected the published run ID to
advance immediately on entry to RUN. It therefore returned failure after the
hardware run had already started. The start log was preserved and the request
was not retried. The wrapper was corrected and offline-tested to require run ID
2 while RUN and run ID 3 only after publication. A hash-verified redeployment
followed by its read-only status operation confirmed the original run remains
active. Evidence:

- `build/diagnostic_archive/v275-soak3-start.log`:
  `f94f5cc2f5e03af021987d7592395ee4f038fbf3f4fd179161a7fb97099aa803`;
- `build/diagnostic_archive/v275-soak3-status-1789330926.log`:
  `bd1214f6749325a37b282e2b2aadd1b0c327539acd7bf81a4908f0a255963344`.

The uninterrupted run completed normally. Completion was first observed at
2026-09-14 04:20:43 EDT: engine IDLE, matching request/response sequence 3,
normal four-lane summary/response `0x00040401`, and hardware run ID 3. The
fixed `results` validator independently reread a stable run-ID-3 bank and
passed all four atomic lane records:

- lanes 12-15 each recorded 13,921,646,169,457 valid cycles and
  1,113,731,693,556,560 tested bits, with exact 80-bit-per-cycle accounting;
- every lane was selected and locked at stop, with zero errors, zero native
  lock losses, and no error/bit-count saturation;
- the per-lane 95% zero-error BER upper bound is `2.694e-15`.

Immutable completion evidence:

- `build/diagnostic_archive/v275-soak3-status-1789374043.log`:
  `715e18ce000088e9e444b9f2f729e45008115b25b09f0d1bc3ade5579185c753`;
- `build/diagnostic_archive/v275-soak3-results.log`:
  `b2f1e00bf9b00102c286abfee646d424a8421837010030922bd788019a2db422`.

Serialized post-run telemetry found F1 FPGA temperature 24.5 C. F1AVTT/CC
PMBus page 0 reported 11.984375-V input, 1.2060546875-V output, raw/unvalidated
output current -0.6494140625 A, regulator temperature 32.0625 C, and zero
status; page 1 was also fault-free. All 37 clock readings were valid,
including `clk_100=100.000 MHz`, `clk_325=325.000 MHz`, and managed
RXUSRCLK2 `322.262 MHz`. The post-run FireFly snapshot again returned bytes
3/5 `FF/FF`; this remains an interpretation caveat, not evidence of LOS or CDR
loss.

F1 remains on v275 in healthy IDLE at request/response/run ID 3. Sequence 3,
its `start`, and the non-overwriting `results` operation are consumed; do not
invoke either again. V275 has passed its short clean gates and uninterrupted
12-hour external soak without reload or retry. It remains an initial
qualification candidate rather than a fully qualified image: actual missing
physical RXUSRCLK2 and optical/native loss remain outside this evidence.
