# IP playbook

## Normal lifecycle

1. Import or create the IP from checked-in configuration.
2. Confirm the project part and IP VLNV.
3. Run `report_ip_status` and stop on locked cores.
4. Generate all required targets.
5. Export IP user files only as a build step.
6. Rebuild synthesis and verify warnings, instantiated primitive counts, and interface widths.

## This repository

The two checked-in IBERT XCI configurations under `ip/` are Vivado-owned structure. They target GTY lanes at 25.78125 Gb/s using 322.265625-MHz REFCLK0. The 10-Gb/s AXI C2C lanes must remain outside these cores.

The generated IBERT `quad_pblock.tcl` files depend on wrapper-relative hierarchy. `scripts/configure_ibert_floorplan.tcl` disables automatic sourcing and installs `scripts/apply_ibert_floorplan.tcl` as a pre-place hook. Preserve this mechanism and the requirement for 14 pblocks per core.

The VHDL wrappers pack vectors outside port maps because Vivado rejects repeated slice associations of a vector formal. Preserve that structure.

## Upgrade review

Before upgrading, record the current VLNV, configuration properties, generated target state, and synthesis behavior. After upgrading, diff the XCI, check line rate/reference clocks and enabled quads, regenerate, and repeat synthesis plus GT primitive-count validation.

