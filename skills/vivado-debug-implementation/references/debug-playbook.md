# Implementation debug playbook

## Evidence by failure class

- Synthesis: first error, inferred/removed logic, latch and multiple-driver warnings, clock inference, primitive counts.
- Opt/place: methodology and DRC reports, utilization by hierarchy, pblock capacity, clock-region/SLR pressure, fixed locations.
- Route: route status, congestion, high fanout, clock utilization, unrouted/conflicting nets.
- Timing: clock definitions and interactions, worst setup/hold paths, routing share, skew, uncertainty.
- Bitstream: implementation completion, write-bitstream DRCs, part identity, output path and timestamp.

## IBERT-specific checks

Expect two cores with 14 quads each and 112 `GTYE4_CHANNEL` primitives total. Inspect the pre-place pblock hook if placement cannot find or constrain the generated hierarchy. Confirm each GT channel and common occupies the documented quad and uses REFCLK0. Do not repair placement by changing logical lane order.

Use `scripts/validate_synthesized_design.tcl` after synthesis and `scripts/inspect_routed_ibert.tcl` for targeted routed checks. The latter is diagnostic; the clean Vivado 2023.2 batch build remains authoritative.

## Hardware handoff

Record source revision and dirty state, Vivado version, part, bitstream path, timing status, DRC status, IP status, reference-clock configuration, and any accepted warnings. Never program hardware solely because `top.bit` exists.

