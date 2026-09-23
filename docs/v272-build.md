# Isolated diagnostic v272 / 2.5.22 — build record

Firmware and hardware identity: `0x00020116`. This target enables the
runtime-integrity detector documented in
[the v272 design](runtime-integrity-candidate-design.md). It remains
separate from full Milestone 3. No FPGA was programmed and no hardware test
was performed during this build.

## Reproducible entry points

```sh
bash scripts/build_milestone272_firmware.sh
vivado -mode batch -source scripts/build_milestone272_bitstream.tcl
vivado -mode batch -source scripts/audit_milestone272_routed.tcl
```

Use the Cornell Vivado 2023.2 environment and license. Outputs are under
`build/firmware272`, `build/gt_test_milestone272`, its report directory, and
`build/gt_test_milestone272_audit`. The project is distinct from v271, embeds
only the matching v272 ELF, and explicitly adds the new
`src/gt_runtime_integrity_monitor.sv` source when cloning the immutable v271
project structure.

Incremental implementation used the frozen v271 routed checkpoint, SHA-256
`b0e540051b786051ec898211ac3092ad2eac125af124c4e11b46a52b068361d4`.
Final routed reuse was 89.35% of cells and 75.33% of nets. The route log
contains `[Route 35-4475]` for two global-clock nets with incomplete
incremental placer guidance; final routing has zero errors and sign-off timing
passes.

## Functional and structural gates

The complete Milestone simulation regression passes with the detector enabled
only for v272. It covers the two-cycle non-trip control, sustained lane-local
PRBS corruption, missing shared-RXUSRCLK2 heartbeat, hysteresis/recovery,
retention, selector-`0xFD` publication, fault stage 27, and atomic failed-result
publication, along with all prior regressions.

Synthesis and routed structural checks confirm the version/configuration,
runtime-monitor state, four error synchronizer pairs, the heartbeat
synchronizer pair, retained state, and all ten synchronizer registers marked
`ASYNC_REG`. All eight profile measurement/epoch first stages retain direct
registered sources with no combinational fan-in. All 16 descriptor endpoints
retain a 3.000-ns analyzed bound; worst slack is +1.568 ns.

## Build and independent audit result — 2026-09-13

Firmware, compressed incremental implementation, build-time checks, and the
independent saved-checkpoint audit pass.

- Compressed bitstream: 32,325,392 bytes.
- Routed timing: WNS +0.018 ns, WHS +0.001 ns, WPWS +0.454 ns, with no failing
  endpoints.
- Routing reports zero errors. Routed DRC has zero errors and retains the one
  existing `RPBF-3` incomplete generic-I2C-buffer warning.
- The part is `xcvu13p-flga2577-2-e`; the managed channels occupy
  `GTYE4_CHANNEL_X0Y16`–`X0Y19`; golden RX properties and 10.000/3.077-ns
  implemented monitor-clock periods pass.
- All 11 IPs are current. Five state machines preserve extraction-disabled
  encoding attributes.
- The isolated target has no bus-skew constraints. This is not global CDC or
  bus-skew signoff.

Routed CDC counts are CDC-1=1, CDC-3=72, CDC-6=26, CDC-7=1, CDC-9=1,
CDC-10=23, CDC-11=64, CDC-13=16, and CDC-15=39. Relative to v271, the expected
new detector crossings add one CDC-3 heartbeat synchronizer and four CDC-11
PRBS-error synchronizers. The independent structural audit verifies their
two-stage registers and `ASYNC_REG` properties. Existing generated-IP, reset,
debug, and other CDC/methodology findings remain; do not describe the design
as globally CDC-clean.

## Artifact identities and next gate

- `build/gt_test_milestone272/gt_test_milestone272.runs/impl_1/gt_test_milestone272.bit`:
  `7ca91032b55f3e71a97dd27678ab5b1bf9b00cbd0d105646cdcdc0666147215d`
- Same directory, `gt_test_milestone25_top_routed.dcp`:
  `237986f4032c2753fa2d1a104b62a64e2145101f3fe37d4848252d004b0b31e9`
- `build/firmware272/gt_test_milestone272.elf`:
  `38187f08c33b02602623d7d25db136b70cfcac5611f9d7eeb1b786845daacf0c`
- `src/gt_runtime_integrity_monitor.sv`:
  `a030c2d74f572413151fde1cf217f0ff05a617dc84e3fd7e23285fe95448ffba`
- `src/gt_prbs_test_controller.sv`:
  `6fba6a06f5861f4c71869947bcfd387ac0ec437c522a3075df5462e9186b94df`
- `scripts/milestone272_config.tcl`:
  `c9fea6ae5743ef57ae9e0ae8ffba050aff89109169369a5e910c4dee720efd62`

The subsequent lane-data hardware gate passed: a two-cycle lane-12 pulse did
not trip, and a 0.250289-s controlled F1_5 channel-0 disable produced one
retained lane-12 integrity event through fault stage 27. Missing shared
RXUSRCLK2 was not tested. Both nominal clean baselines required one bounded
acquisition recovery, so v272 is not fully qualification-ready. See
[the v272 hardware record](v272-hardware-gate.md).
