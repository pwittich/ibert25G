---
name: vivado-analyze-timing
description: Analyze and close AMD Xilinx Vivado static timing. Use for setup/hold failures, WNS/TNS/WHS/THS, unconstrained paths, generated clocks, clock interactions, timing exceptions, path segmentation, pipelining, placement effects, and post-route timing sign-off.
---

# Analyze Vivado timing

## Workflow

1. Analyze the implemented checkpoint when available; use synthesized timing only for early feedback.
2. Run the bundled report suite and read `check_timing` before studying negative-slack paths.
3. Separate setup, hold, pulse-width, and unconstrained-path problems.
4. Group failures by clock pair, endpoint class, hierarchy, and common physical cause.
5. Validate clocks and exceptions before changing RTL. Never fix a real path by hiding it with a false path.
6. For genuine datapath failures, address architecture, fanout, placement, congestion, or pipelining according to the path evidence.
7. Rerun implementation and verify both maximum and minimum delay timing.

Read [references/timing-playbook.md](references/timing-playbook.md) for triage patterns.

## Helper

```sh
vivado -mode batch -source skills/vivado-analyze-timing/scripts/report-timing-health.tcl \
  -tclargs build/vu13p_ibert_25g.xpr impl_1 build/reports/timing
```

The helper exits with an error when setup or hold slack is negative, making it suitable for automated checks.

