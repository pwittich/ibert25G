# Build playbook

## Repository profile

- Vivado: 2023.2 with UltraScale+ device support
- Part: `xcvu13p-flga2577-2-e`
- Top: `src/top.sv`, module `top`
- Build entry points: `scripts/create_project.tcl`, `scripts/build_bitstream.tcl`
- Resume after valid synthesis: `scripts/continue_after_synthesis.tcl`
- Generated output: `build/` only; never commit it
- Expected bitstream: `build/vu13p_ibert_25g.runs/impl_1/top.bit`

## Decision guide

- Project absent or source/IP list changed: recreate the project.
- Synthesis failed: inspect `synth_1/runme.log`, fix the first causal error, rerun synthesis.
- Post-synthesis validation failed: correct the source or validation expectation; retain the checkpoint only when it still represents the intended design.
- Synthesis valid and implementation failed: use the continuation flow rather than rebuilding synthesis.
- Constraints or pre-place hook changed: reset and rerun implementation from the earliest affected step.
- Part, IP configuration, source set, compile order, or synthesis option changed: rebuild synthesis.

## Required sign-off evidence

Review `report_ip_status`, synthesis and implementation warnings, methodology and DRC reports, setup and hold timing, unconstrained paths, clock frequencies and interactions, utilization, congestion, and all 112 `GTYE4_CHANNEL` placements.

The 28 GTY quads use 25.78125 Gb/s lanes and 322.265625-MHz REFCLK0 inputs. Do not add the separate 10-Gb/s AXI C2C lanes. Preserve the lane and reference-clock order in `README.md` and the XDC files.

