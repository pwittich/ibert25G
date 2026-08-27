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
- Preserve the deployed I2C addresses: generic register slave `0x2B`; SysMon
  SLR0=`0x36`, SLR1=`0x34`, SLR2=`0x47`, and SLR3=`0x45`.
- Preserve the MCU register ABI documented in `README.md`: `r00` and `r01` are
  scratch registers, `r02`-`r38` are the 37 direct-kHz clock readings in the
  documented order, and `r39` is the `0x434D` status word. Do not apply x2
  scaling to GT monitor values.
- Generate `clk_100` and `clk_325` from the 200-MHz board clock with the
  1300-MHz-VCO MMCM configuration, and keep both in the monitor map.
- All new bitstreams must be compressed. Set
  `BITSTREAM.GENERAL.COMPRESS=TRUE` reproducibly in each target's Tcl or XDC,
  enforce it in bitstream-producing scripts, and keep the README and
  build-state memory current.
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
Confirm the implemented clock report contains 100.000 MHz and 325.000 MHz,
the route-status report has no routing errors, and all bus-skew constraints
are met.
