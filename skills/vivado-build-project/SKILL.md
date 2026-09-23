---
name: vivado-build-project
description: Create, reproduce, resume, and validate AMD Xilinx Vivado project builds from Tcl. Use for project creation, synthesis, implementation, bitstream generation, build logs, checkpoints, run failures, clean rebuild decisions, and CI-style Vivado batch flows.
---

# Build a Vivado project

## Workflow

1. Read the repository `AGENTS.md`, `README.md`, and build Tcl before changing anything.
2. Keep project creation reproducible from source-controlled Tcl. Never commit generated project, run, cache, IP-output, checkpoint, or bitstream products.
3. Confirm the selected Vivado release and device part before launching a build.
4. Prefer the repository's existing entry points. In this repository run:
   - `vivado -mode batch -source scripts/create_project.tcl`
   - `vivado -mode batch -source scripts/build_bitstream.tcl`
5. Use `scripts/run-vivado.sh` to capture isolated logs under `build/logs/` when useful.
6. Inspect run status and the first real error in the run log; later failures are often cascading.
7. After implementation, verify IP status, DRCs, timing, clock definitions, utilization, GT placement, and the expected bitstream path.

Read [references/build-playbook.md](references/build-playbook.md) for build-state decisions and this project's required invariants.

## Change rules

- Edit source Tcl instead of the generated `.xpr` or run database.
- Use paths derived from `[info script]`; do not assume the caller's working directory.
- Fail Tcl flows explicitly when a run is incomplete or timing is not met.
- Preserve useful completed synthesis when implementation alone needs to be retried.
- Do not delete `build/` unless the user explicitly requests a clean rebuild.

## Helper

Run a checked-in flow with distinct journal and log files:

```sh
skills/vivado-build-project/scripts/run-vivado.sh scripts/create_project.tcl
skills/vivado-build-project/scripts/run-vivado.sh scripts/build_bitstream.tcl
```

