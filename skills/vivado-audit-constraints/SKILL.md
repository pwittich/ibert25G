---
name: vivado-audit-constraints
description: Create, review, and audit AMD Xilinx Vivado XDC constraints. Use for clocks, generated clocks, I/O pins and standards, timing exceptions, CDC constraints, scoped constraints, GT locations, pblocks, constraint ordering, unconstrained endpoints, and methodology checks.
---

# Audit Vivado constraints

## Workflow

1. Read the board documentation, RTL clock structure, all XDC files, and project constraint order.
2. Open the synthesized or implemented design and run the bundled audit reports.
3. Verify primary/generated clocks at the real source objects and confirm their periods and relationships.
4. Review every timing exception by intent and coverage. Prefer object-specific constraints over broad wildcards.
5. Verify top-level ports have intended package pins, I/O standards, bank compatibility, and differential pairing.
6. Inspect CDC structures and distinguish safe synchronizers, handshakes, FIFOs, static configuration, and unsafe crossings.
7. Confirm GT channels, reference clocks, pblocks, and scoped vendor constraints preserve documented physical ordering.

Read [references/constraint-playbook.md](references/constraint-playbook.md) before editing XDC.

## Helper

```sh
vivado -mode batch -source skills/vivado-audit-constraints/scripts/audit-constraints.tcl \
  -tclargs build/vu13p_ibert_25g.xpr impl_1 build/reports/constraints
```

