# Isolated diagnostic v271 / 2.5.21 — build record

Firmware and hardware identity: `0x00020115`. This diagnostic target applies
the zero-elapsed-profile repair described in
[the v270 investigation](v270-profile-investigation.md). It remains separate
from full Milestone 3 and is not a qualification candidate. No hardware was
programmed or exercised during this build.

## Reproducible entry points

```sh
bash scripts/build_milestone271_firmware.sh
vivado -mode batch -source scripts/build_milestone271_bitstream.tcl
vivado -mode batch -source scripts/audit_milestone271_routed.tcl
```

Use the Cornell Vivado 2023.2 environment and license. Outputs are under
`build/firmware271`, `build/gt_test_milestone271`, `_reports`, and `_audit`.
The FPGA project is distinct from v270 and embeds only the matching v271 ELF.
The writer explicitly reported populating BRAM from
`firmware271/gt_test_milestone271.elf`.

Incremental implementation used the frozen v270 routed checkpoint, SHA-256
`866d9112343417449e2201a15d60d032f6ae395db85511b25fddf030c3e34400`.
Vivado could not reuse top-level synthesis after the RTL changes, so it ran a
fresh top synthesis while retaining all completed IP runs. Final routed reuse
was 90.68% of cells and 76.04% of nets. V270's hardware evidence is historical
context only and is not qualification evidence for v271.

## Repair and structural gates

`measurement_active` is a dedicated management-clock flop aligned with `RUN`.
The registered accepted-request toggle is the profile epoch. Each RX profile
may start and publish once per accepted epoch, retains its completed snapshot
through same-epoch post-run activity, and clears validity on the next accepted
epoch.

Synthesis requires exactly one `measurement_active_reg`, four
`measure_meta_reg` first stages, four `run_meta_reg` first stages, and the
expected active/completed epoch state. The routed build and independent audit
then prove that each of those eight profile first stages has exactly one
sequential source and no combinational fan-in. All 16 descriptor endpoints
retain an analyzed 3.000-ns requirement with nonnegative slack; worst slack is
+1.568 ns.

In v270 the eight ordinary lane/profile measurement crossings were CDC-10
because `state == RUN` was a combinational decode before their synchronizers.
In v271 they are CDC-11 registered fan-out crossings from
`measurement_active_reg`; the four new epoch crossings are also CDC-11 from
`start_req_toggle_reg`. Consequently CDC-10 falls from 31 to 23 and CDC-11
rises from 48 to 60. The direct-source structural audit is the acceptance
criterion for these intentional fan-outs. This does not waive or validate the
remaining unrelated CDC findings.

## Build and audit result — 2026-09-12

The full Milestone simulation suite, matching firmware build, incremental FPGA
implementation, build-time checks, and independent saved-checkpoint audit all
passed.

- Compressed bitstream: 32,339,028 bytes.
- Routed timing: WNS +0.018 ns, WHS +0.001 ns, WPWS +0.454 ns; no failing
  endpoints. Routing reports zero routing errors and routed DRC has zero errors
  (the existing incomplete generic-I2C buffer warning remains).
- Correct `xcvu13p-flga2577-2-e` part, four managed sites
  `GTYE4_CHANNEL_X0Y16`–`X0Y19`, golden RX properties, and 10.000/3.077-ns
  implemented monitor-clock periods passed.
- All 11 IPs are up-to-date. Synthesis reports five instances with FSM
  extraction disabled by the required encoding attributes.
- The isolated target has no bus-skew constraints. This is not bus-skew or
  global CDC signoff. Existing generated-IP, reset, debug, and other
  methodology findings remain; no constraint was relaxed to obtain closure.

Routed CDC category counts are CDC-1=1, CDC-3=71, CDC-6=26, CDC-7=1,
CDC-9=1, CDC-10=23, CDC-11=60, CDC-13=16, and CDC-15=39. The methodology
report retains TIMING-7=1 and TIMING-17=960 among the previously reviewed
findings. These reports must be read as a scoped audit, not a claim that the
whole design is CDC-clean.

## Artifact identities and next gate

- `build/gt_test_milestone271/gt_test_milestone271.runs/impl_1/gt_test_milestone271.bit`:
  `54b4d2cebe0b09422a9713a534c3100b8d6371ef8aac022d00943417c1e76f83`
- Same directory, `gt_test_milestone25_top_routed.dcp`:
  `b0e540051b786051ec898211ac3092ad2eac125af124c4e11b46a52b068361d4`
- `build/firmware271/gt_test_milestone271.elf`:
  `3235e58340f1f7624831a47e2db0453ca757809d08c536f3f588c828c939bd96`
- `src/gt_test_engine_core.sv`:
  `262a981646e390450799733092bbc9c98f39aca8eac20c458a39b5be8d4c2548`
- `src/gt_rx_error_profile.sv`:
  `62ef739a842bcc7799a2986ab0115794365d7fe77933e55baa93d2f15bb6b7e4`

That hardware gate subsequently passed: F1 was hash-verified and programmed,
confirmed `0x00020115`, and passed two unique clean four-lane external
baselines without reload or retry. The subsequent profile hardware gate also
passed: a lane-12 pulse was counted for two cycles, the complete result stayed
unchanged through about 158 seconds of IDLE, and clean sequence 4 replaced it.
F1 remains v271 healthy IDLE at sequence/run ID 4. See
[the baseline evidence](v271-hardware-baselines.md) and
[profile hardware evidence](v271-profile-hardware-gate.md). This does not
promote v271 to a qualification candidate.
The fixed-choice `board_program.py v271` path pins both hashes; matching
`milestone271_diagnostics.py` and `milestone271_characterize.py` wrappers are
the only v271 operator entry points used for this gate.
