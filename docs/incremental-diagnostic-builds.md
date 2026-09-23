# Incremental isolated diagnostic builds

Latest build as of 2026-09-12: [v270 / 2.5.20](v270-build.md) passes build and
independent audit with the descriptor CDC repair and effective physical timing
bounds. It took 11m14s and reused 90.74% of cells / 76.42% of nets. Subsequent
[v270 hardware baselines](v270-hardware-baselines.md) both passed; F1 is now
v270/run 3, healthy IDLE after a subsequent
[lane-12 pulse pass](v270-pulse-characterization.md). The remaining sections
retain the v269 flow/history.

The v269 incremental build and routed audit passed,
but its first [hardware baseline](v269-hardware-baseline.md) failed. That
failure is archived unchanged. The commands below document build entry points, not a request
to overwrite existing artifacts or repeat the failed hardware test.

This opt-in development flow is separate from clean qualification builds. It
does not re-label archived products or bypass synthesis/implementation audits.
No generated files are committed.

## Entry points

With the Cornell Vivado 2023.2 environment loaded:

```sh
bash scripts/build_milestone269_firmware.sh
vivado -mode batch -source scripts/build_milestone269_bitstream.tcl \
  -log build/milestone269-incremental.log -journal build/milestone269-incremental.jou
vivado -mode batch -source scripts/audit_milestone269_routed.tcl
```

The fast entry uses `create_diagnostic_incremental.tcl`: it verifies the routed
reference SHA-256, part, isolated top, completed implementation and GT rates;
uses `save_project_as -include_local_ip_cache` into a new directory; retains
Vivado-owned BD/IP and completed out-of-context synthesis runs; rebinds current
hand-written RTL/XDC and the matching application ELF; resets top synthesis;
and sets `INCREMENTAL_CHECKPOINT` on the new implementation run. IP cache IDs
must match before/after the clone, and all run directories must belong to the
new project. The source project is never reset. Existing destinations cause
an error rather than being overwritten. Vendor `mb_bootloop*.elf` is retained.

For v269, the reference is the archived v268 routed checkpoint:
`build/gt_test_milestone268/gt_test_milestone268.runs/impl_1/gt_test_milestone25_top_routed.dcp`,
SHA-256 `45ac009b1791e88a6aead156ec236297f5c99d5c26875d4c36ee4d08332ef7d5`.
Keep the reference project, generated IP, cache and run products available;
the routed DCP alone is not enough for IP synthesis reuse.

Changing IP/BD configuration requires the clean creation flow; do not modify
Vivado-generated wrappers or force stale runs up-to-date. A future fast target
must explicitly identify its reference and matching firmware/generics.

An independent clean build writes a separate `gt_test_milestone269_clean`
project and `_clean` reports/products, leaving the fast result intact:

```sh
vivado -mode batch -source scripts/build_milestone269_clean_bitstream.tcl
vivado -mode batch -source scripts/audit_milestone269_clean_routed.tcl
```

Both use diagnostic version `0x00020113`; distinguish the actual products by
their hashes and build provenance. Neither is the eventual qualification
candidate. Both enforce compressed output and the existing timing, routing,
DRC, GT placement/properties and implemented-clock checks. Review CDC and
methodology findings separately; incremental reuse does not waive them.

## Measurements

The v268 clean logs recorded top synthesis 2m16s, placement 3m25s, routing
1m31s, and bitstream generation 1m16s, excluding project/IP setup and reports.
The corrected v269 fast setup took 11 seconds; all nine IP synthesis runs retained
completed/cached status and only top synthesis launched. Top synthesis took
1m49s. The corrected session ran 11:26:50–11:37:47 (10m57s), versus
v268's 08:55:57–09:10:38 (14m41s): 3m44s / 25.4% less wall time.
These are different RTL revisions, not a controlled same-source benchmark;
separate firmware, simulation and independent audit time are excluded.

| Stage | v268 clean | v269 incremental |
| --- | ---: | ---: |
| Top synthesis | 2m16s | 1m49s |
| Placement (complete command) | 3m25s | 2m54s |
| Routing | 1m31s | 1m18s |
| Write bitstream | 1m16s | 1m14s |

The final `gt_test_milestone269_reports/incremental_reuse.rpt` reports
82.08% cell reuse and 65.44% net reuse (initially 85.19% / 68.16%).
Unchanged-IP reuse avoids regeneration/synthesis; implementation still needs
optimization, timing analysis, reports and bitstream generation. Do not promise
the same speedup for another revision or treat reuse percentage as correctness.

The first attempt was stopped and preserved under
`build/gt_test_milestone269-trace-disabled/`: the old one-bit
`DIAGNOSTIC_TRACE` parameter truncated mode 2 to zero. All three real top/wrapper
declarations now use an integer, and both build paths check the synthesized
256-entry address/count registers before implementation. The corrected build
passed that gate and inferred distributed RAM for the recorder. The stopped
attempt is not a usable artifact and is excluded from build-time comparisons.

The initial helper's broad ELF-removal filter attempted to remove the
Vivado-owned boot-loop file and raised filemgmt 20-1679. Vivado refused it;
the reference and cloned boot-loop ELF both hash to
`16073fe6e1d271505124f6d828fca1159961a959df0896130ea62f83be147db4`.
The first two filters matched full paths, including a generated BD directory
containing `gt_test_milestone`; both attempts therefore logged the refused
removal. The helper now matches `gt_test_milestone*.elf` against file basenames
only. This final helper correction was made after the corrected run's setup;
its log preserves the executed version and warning. The current
project lists only firmware269 as its application ELF. The bitstream log
confirms BRAM INIT population from `build/firmware269/gt_test_milestone269.elf`.

## v269 diagnostic change

The v268 clean sequence 1/run ID 1 completed with zero errors and lock losses
on all four lanes, but its trace recorded 107 events and overflowed the
64-entry ring. `build/diagnostic_archive/run1-clean.json` and `.log` preserve
that failed instrumentation validation. No second run or fault stimulus was
issued on v268. See the subsequent v269 hardware result below.

V269 changes instrumentation only: `DIAGNOSTIC_TRACE=2` selects a 256-entry
ring, and a single write-port expression permits LUTRAM inference. Recovery
policy and the native-RX profiles are unchanged. Schema `54520002` has active
bit 19, overflow bit 18, count [17:9], next index [8:1] in metadata word 1.
Slots use selectors `80..BF` plus bank [1:0] at MCU byte `CD` (AXI selector
word bits [9:8]). A one-byte `CC` write selects bank zero; a four-byte
little-endian write sets both selector and bank. Normal lane, FD and FE reads
retain their original selection/readback. Dump all four banks before another
request, rejecting overflow or changing epochs.

Tests retain 180 events without loss, explicitly detect overflow at 300 events,
and verify all 256 slots' bank selection through AXI and MCU. Existing recovery
and two engine regressions pass; fifteen Python decoder/operator tests pass.
Build and independent routed audit passed. Hardware characterization remains
gated on preflight and clean baseline validation before applying a fault
stimulus. The subsequent [v269 hardware baseline](v269-hardware-baseline.md)
retained all 127 events without overflow but left lane 12 unselected despite
the four-lane descriptor. F1 is now v269/run 1; no further hardware test was
issued. Descriptor CDC repair/regression is the next gate.

## Audit and archived identity

Routed audit: WNS +0.122 ns, WHS +0.001 ns (narrow positive margin), WPWS
+0.454 ns; zero routing and DRC errors, compressed output, expected four
GTYE4_CHANNEL_X0Y16..19 sites/golden RX properties, and 100/325-MHz monitor
clocks. All 11 IPs are up-to-date. Synthesis explicitly retained FSM encodings.
The final audit completed independently in 1m45s, outside the build comparison.

Incremental routing logged Route 35-4475 (two clock nets with incomplete placer
guidance), and placement logged guided-BEL differences. These describe reuse
guidance, not the final routing state: the saved checkpoint has 29,930 fully
routed nets, zero routing errors and passing setup/hold/pulse-width checks.
This is accepted for this diagnostic artifact, not a waiver for future builds.
The refused boot-loop removal warning is dispositioned above.

CDC counts match v268 exactly: CDC-1/3/6/7/9/10/11/13/15 =
1/71/26/1/1/31/48/16/39. The previous endpoint/reset/observational-CDC review in
`recovery-items5-6.md` remains applicable; do not claim globally CDC-clean.
Routed methodology retains TIMING-7=1, TIMING-17=960 and LUTAR-1=6;
DRC retains RPBF-3=1 for I2C buffering. Bus-skew reports **no constraints**,
not a constrained bus-skew qualification pass.

SHA-256 identities (all generated products stay under ignored `build/`):

- Source archive `diagnostic_archive/v269-incremental-source.tar.gz`:
  `86ee7804070ad4f73e7015d3c043a80e9a6dea8639e4521402dead3a5a83cba0`.
  Includes the final basename-filter correction; executed setup is preserved
  verbatim in the build log, as described above.
- `firmware269/gt_test_milestone269.elf`:
  `bf75cc9c176b5f5c74a710b6ad5f44467324869babf9013b70247d1740308e9d`.
- `gt_test_milestone269/gt_test_milestone269.runs/impl_1/gt_test_milestone269.bit`:
  `24a8b973c7eac9546ce50c07d281eaf496edf4b27aa9c6a7052d20bcc462c07d`.
- Same directory, `gt_test_milestone25_top_routed.dcp`:
  `68dfd31508e696cb30f7cbe06dea1eabe6f67b7d598c6454be0a315b66f4738f`.
- Products, reports, build/audit logs and HDL test logs in
  `diagnostic_archive/v269-incremental-products.tar.gz`:
  `aa6f0606ac4e1a1a3ab22e249b426c7153a8f0d184c5a9baa35a0079d793349f`.

The reference v268 DCP hash was rechecked after completion and is unchanged.
The separate clean v269 flow is provided but has not been executed.
