# AGENTS.md

## Scope

This repository builds a Vivado 2023.2 IBERT image for either VU13P site on
the Cornell rev3 board. Keep changes reproducible from Tcl; do not commit
generated `build/` products.

## Design rules

- Target `xcvu13p-flga2577-2-e` and keep `src/top.sv` as the top level.
- FireFly and FPGA-to-FPGA GTY lanes run at 25.78125 Gb/s from 322.265625-MHz
  REFCLK0 inputs. Do not add the 10-Gb/s AXI C2C lanes to these IBERT cores.
- Preserve the physical lane and reference-clock ordering documented in
  `README.md` and the XDC files.
- In VHDL port maps, associate each vector formal once. Pack or unpack signals
  outside the map; Vivado rejects repeated slice associations of one formal.
- Keep the four SysMon I2C addresses and generic I2C address visibly labeled
  in `src/top.sv`.
- Treat XCI and generated IBERT wrappers as Vivado-owned structure. Make the
  smallest necessary wrapper edits and document them.

## Validation

Run:

```sh
vivado -mode batch -source scripts/create_project.tcl
vivado -mode batch -source scripts/build_bitstream.tcl
```

Before programming hardware, review IP status, synthesis/implementation
warnings, DRCs, GT placement, timing, and all configured clock frequencies.
