---
name: vivado-debug-implementation
description: Diagnose AMD Xilinx Vivado synthesis and implementation results. Use for DRC or methodology violations, placement and routing failures, congestion, high fanout, utilization, GT placement, pblocks, implementation warnings, routed-design inspection, and hardware-debug preparation.
---

# Debug Vivado implementation

## Workflow

1. Preserve the failing run and collect evidence before resetting anything.
2. Find the first causal error in `runme.log`; classify it as netlist, constraint, placement, routing, timing, DRC, licensing, or resource exhaustion.
3. Run the bundled implementation report suite on the latest completed stage.
4. Correlate DRC/methodology findings with utilization, hierarchy, clocking, congestion, high-fanout nets, pblocks, and physical primitive placement.
5. Make the smallest source-controlled RTL, XDC, IP, or Tcl fix.
6. Restart from the earliest invalidated stage and compare reports.
7. Before hardware use, verify the bitstream belongs to the intended part/build and review clocks, GT placement, DRCs, and timing.

Read [references/debug-playbook.md](references/debug-playbook.md) for failure-specific tactics.

## Helper

```sh
vivado -mode batch -source skills/vivado-debug-implementation/scripts/report-implementation-health.tcl \
  -tclargs build/vu13p_ibert_25g.xpr impl_1 build/reports/implementation
```

