# Isolated diagnostic v270 / 2.5.20 — build record

Firmware and hardware identity: `0x00020114`. This target combines the
[descriptor source repair](descriptor-transfer-repair.md) with explicit
descriptor timing constraints. It is not full Milestone 3 or a qualification
candidate. Hardware remained on v269 during the build; a subsequent
[v270 programming and two-baseline gate](v270-hardware-baselines.md) passed.

## Reproducible entry points

```sh
bash scripts/build_milestone270_firmware.sh
vivado -mode batch -source scripts/build_milestone270_bitstream.tcl
vivado -mode batch -source scripts/audit_milestone270_routed.tcl
```

Use the Cornell Vivado 2023.2 environment and license. Firmware and project
creation refuse existing destinations. New outputs live under
`build/firmware270`, `build/gt_test_milestone270`, `_reports` and `_audit`.
The firmware has 660 text bytes and 8 BSS bytes, passes little-endian/vector
checks, and hashes to
`0f91bee392bb1de414834cb03f6cd5f63a503cd8401b8365f599f81ac60677cf`.

Incremental reference: v269 routed checkpoint SHA-256
`68dfd31508e696cb30f7cbe06dea1eabe6f67b7d598c6454be0a315b66f4738f`.
Only implementation/IP reuse is intended; v269's failed hardware result is
not a functional qualification reference. Its archive/project is not reset.
Current RTL, matching firmware and the v270 board constraint file are rebound
in a separate project. Compression and golden GT/site/clock checks remain.

## Constraint intent and acceptance gate

`gt_test_milestone270_board.xdc` preserves the isolated board pin/clock mapping
but omits the quad-124 blanket asynchronous group. The source hook
`apply_descriptor_cdc.tcl` retains the prior directional exceptions for other
quad crossings while excluding all 16 selected/mode first-stage data pins.
Those paths receive `set_max_delay -datapath_only 3.000` from `clk_200`.
The bound is below the 3.103-ns RX period; compared with descriptor data, the
start request has two extra RX stages, budgeting one cycle of capture skew
plus one of synchronizer resolution. This is not arbitrary-delay immunity or
an MTBF calculation. Existing non-descriptor CDC caveats remain.

`check_descriptor_routed.tcl` requires a real analyzed path to each endpoint,
exactly 3.000-ns requirement and nonnegative slack. An overriding false path
or clock group causes failure. Independent audit repeats the check from the
saved checkpoint. Review ignored exceptions, ordinary setup/hold, CDC and
methodology before using the image; do not treat a missing timing path as a pass.

## Build and audit result — 2026-09-12

Firmware, incremental FPGA build and independent routed audit passed. The
build session ran 14:24:16–14:35:30 EDT (11m14s, including reports). Setup
retained all nine cached IP synthesis runs; top synthesis took 1m44s, placement
2m19s, routing 1m58s and bitstream writing 1m17s. Final cell/net reuse was
90.74%/76.42%. Different RTL/constraints make comparisons with earlier builds
observations, not controlled speed benchmarks.

- Compressed bitstream: 32,322,504 bytes. The writer explicitly populated BRAM
  from `firmware270/gt_test_milestone270.elf`.
- WNS +0.325 ns, WHS +0.001 ns, WPWS +0.454 ns; zero timing violations,
  routing errors or DRC errors. Expected four GT sites/golden RX properties
  and 100.000/325.000-MHz monitor clocks passed.
- All 16 descriptor endpoints have an analyzed 3.000-ns requirement; worst
  slack +1.568 ns. The saved-checkpoint audit independently repeated this
  check. CDC reports identify these paths as `Max Delay Datapath Only`.
- All 11 IPs are up-to-date. Synthesis retains the diagnostic FSM encodings
  (`FSM extraction disabled`); the synthesized trace/extra-stage gates pass.
- The isolated design has **no bus-skew constraints**. This is not bus-skew
  signoff or global CDC cleanliness.

Routed CDC category counts match v269: CDC-1=1, -3=71, -6=26, -7=1,
-9=1, -10=31, -11=48, -13=16, -15=39. Existing methodology findings remain,
including TIMING-7=1, TIMING-17=960 and eight TIMING-24 overridden XPM
handshake bounds. The ignored-exception report shows those prior non-descriptor
crossings now overridden by the replacement directional false paths; none of
the 16 descriptor bounds is ignored. Existing reset/debug exceptions also
remain. This narrow repair does not validate those other CDC structures.
The one additional methodology finding, XDCB-1, is a runtime-cost warning for
the 18,038-pin exclusion list, not a timing failure. Vivado also warns that
the pre-opt hook is outside `utils_1`; its checked-in source is archived and
both synth/implementation logs confirm it ran. No constraint was relaxed in
response to routing congestion.

## Frozen artifacts

Paths below are relative to `build/`; SHA-256:

- `gt_test_milestone270/gt_test_milestone270.runs/impl_1/gt_test_milestone270.bit`:
  `72f3a2fa5b97f30cd503631fa16af03715a165a1865d7278fd5a249874bdefe4`
- Same directory, `gt_test_milestone25_top_routed.dcp`:
  `866d9112343417449e2201a15d60d032f6ae395db85511b25fddf030c3e34400`
- `diagnostic_archive/v270-source-preimplementation.tar.gz` (source snapshot
  captured during implementation, before completion; includes pending-status docs):
  `b994b17428f5ac3cc6a2d8d89a28e3da2ec69e1472550a254c0003578c677b2f`
- `diagnostic_archive/v270-products.tar.gz` (ELF, bitstream, routed DCP,
  synthesis/implementation logs, build/audit logs and reports):
  `c40002b80d117f2beaea8124de30af6577cc053122a011378b6dd9275bec28f6`

Source regression evidence is recorded in
[descriptor-transfer-repair.md](descriptor-transfer-repair.md); all 15 Python
tests passed again during this build preparation. The build does not claim a
new hardware result. The failed v269 reference and archives were not changed.

## Subsequent hardware gate

No hardware access or programming occurred in this build. In the subsequent
authorized hardware step, F1 was programmed with these matching artifacts and
both clean four-lane baselines passed. It is now healthy IDLE at sequence/run
ID 3 after a subsequent [successful pulse test](v270-pulse-characterization.md);
see also [baseline evidence](v270-hardware-baselines.md).
No programming or test request is authorized by running these build scripts.
After acceptance, use only matching `milestone270_characterize.py` and
`milestone270_diagnostics.py` for this identity. Fresh temperature/power
preflight and two clean full-four-lane baseline gates precede fault stimuli;
the FireFly `FF/FF` alarm readback still requires investigation.
