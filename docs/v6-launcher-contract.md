# V6 fixed hardware launcher contract (completed gate)

The reviewed launcher was enabled and the scoped gate completed.  Final
identities are F1 `0x00020400` and F2 `0x00020403`; sequences 1–5 and runs
1–3 are consumed on both endpoints.  Do not replay any hardware stage.  See
`docs/v6-direct-quad-qualification.md` for evidence and final state.

Build entry points use the regular helper:

```
bash skills/vivado-build-project/scripts/run-vivado.sh scripts/build_direct_quad_v6_f1_bitstream.tcl
bash skills/vivado-build-project/scripts/run-vivado.sh scripts/build_direct_quad_v6_f2_bitstream.tcl
bash skills/vivado-build-project/scripts/run-vivado.sh scripts/audit_direct_quad_v6_f1_routed.tcl
bash skills/vivado-build-project/scripts/run-vivado.sh scripts/audit_direct_quad_v6_f2_routed.tcl
```

Each project clones the completed v5 supervisor IP/BD cache without modifying
the source project, replaces all application and GT sources, imports one of
the already generated v6 functional GT XCIs, and performs clean application
synthesis. Automatic incremental synthesis and implementation are disabled.
Completed synthesis and implementation checkpoints are retained. Existing
projects resume only unchanged synthesis; source changes require reviewed
artifact preservation and an explicit rebuild. Creation refuses overwrite.

Historical pre-enable requirement: no hardware-capable launcher was released
until endpoint simulation, independent routed audits, exact BIT/ELF SHA-256
pins, and site-specific target-enumeration guards passed review.  Those gates
subsequently passed and the fixed launcher was consumed.  Its presence is not
authorization to replay it or to extend existing programming choices.

The later fixed, non-overwriting hardware gates must enforce:

- F1 identity `0x00020400`, global lanes 60–63, mask words
  `0,F0000000,0,0`, monitored direct reference r12.
- F2 final identity `0x00020403`, global lanes 104–107, mask words
  `0,0,0,00000F00`, monitored direct reference r14.
- Physical mapping F1 60/61/62/63 to F2 107/106/105/104.
- Preserve current v5 snapshots first; site-specific audited programming is
  one-time, with exact completion marker and identity/clock verification.
- Fresh sequence 1/run 1: ten-second PMA at each site, TX sessions off.
  Both must pass before external gates; no silent reset/reload/retry.
- External gate: bounded independent TX sessions on both endpoints, fixed
  settle, overlapping ten-second RX windows. Preserve both publications
  before stopping either TX session; verify eight clean nonzero records,
  healthy IDLE and stable results after cleanup. Require actual observed RUN
  overlap rather than assuming two sequential submissions overlap.
- A repeat is a separately sequenced gate after successful cleanup. Maintain
  distinct mailbox sequence and measurement-run IDs; sessions consume only
  the former. No arbitrary durations/masks/commands/hosts or automatic retry.
- All MCU UART work serialized, software I2C5 semaphore held per transaction,
  exactly one FPGA mux selection, version/previous-state checks before writes.
- Failures preserve both endpoints, counters and diagnostics; cleanup may
  stop TX only if exact known state makes it safe. Lease expiry bounds a
  stranded transmitter; it is not authorization for a blind abort/reset.

These are script requirements, not a claim that the hardware gate has run.
MCU changes, optical stimuli, long BER qualification and all-channel expansion
remain outside this scoped v6 gate.

Static review caveats before the first build: the project clone removes only
named application constraints and the retired GT/native source families;
it must retain the supervisor BD/IP scoped constraints. The independent audit
does not add constraints and requires exactly one saved passing bus-skew
constraint. COMMON reference fan-in may terminate at the IBUFDS output in
Vivado; if so, establish the actual IBUFDS-to-port path explicitly from routed
evidence rather than weakening the local-reference requirement. These Tcl
flows have passed completeness checks, not a real Vivado implementation yet.
