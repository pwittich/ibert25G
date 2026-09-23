---
name: vivado-manage-ip
description: Inspect, create, configure, generate, lock-check, upgrade, and reproduce AMD Xilinx Vivado IP. Use for XCI files, generated targets, IP output products, VLNV/version issues, locked IP, upgrade planning, synthesis checkpoints, vendor wrappers, and report_ip_status diagnostics.
---

# Manage Vivado IP

## Workflow

1. Read `AGENTS.md`, the project-creation Tcl, the XCI files, and any hand-maintained wrapper before editing IP.
2. Run the bundled health report against the generated project.
3. Treat the XCI as the source-controlled IP configuration and generated output products as disposable.
4. Make the smallest configuration change. Prefer Tcl (`create_ip`, `set_property -dict`, `generate_target`) when adding new IP.
5. Upgrade only when requested or required by the selected Vivado release. Review changed parameters before accepting an upgrade.
6. Regenerate targets, recreate the project, synthesize, and inspect IP status and warnings.

Read [references/ip-playbook.md](references/ip-playbook.md) before modifying IBERT or generated wrappers.

## Safety rules

- Do not hand-edit generated HDL or XCI XML unless no supported Tcl route exists.
- If a generated wrapper must change, keep the patch minimal and document why it cannot be regenerated.
- Do not silently accept locked IP, missing output products, or a part mismatch.
- Preserve repository-local IP paths and deterministic generation.

## Helper

```sh
vivado -mode batch -source skills/vivado-manage-ip/scripts/report-ip-health.tcl \
  -tclargs build/vu13p_ibert_25g.xpr build/reports/ip
```

