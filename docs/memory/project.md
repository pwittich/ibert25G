# VU13P IBERT Project Memory

Last updated: 2026-08-24

## Repository and sources

- Tool: Vivado 2023.2; part `xcvu13p-flga2577-2-e`; top `src/top.sv`.
- Board schematic: `/nfs/cms/tracktrigger/wittich/Cornell_CM_Rev3_HW/Schematic/6089-127-RevA_23Jan2025.pdf`.
- Canonical board XDC: `/nfs/cms/tracktrigger/wittich/Cornell_CM_Rev3_HW/Vivado/constraints/VU13P_pins.xdc`.
- Keep generated `build/` products out of Git. Reproduce builds with Tcl scripts.

## Stable design facts

- Both IBERT cores contain 14 GTY quads, 56 channels each, for 112 `GTYE4_CHANNEL` instances total.
- FireFly and FPGA-to-FPGA links use 25.78125 Gb/s from 322.265625-MHz REFCLK0. The 10-Gb/s AXI C2C lanes are excluded.
- FF3 is physically reversed at the wrapper boundary: schematic page 64 maps board lane 11 to GTY128 channel 0 and lane 0 to GTY130 channel 3. Reverse both 12-bit FF3 RX and TX segments while retaining board lane numbering in the XDC.
- FF6 RX lane 1 is the bonded `M48`/`M49` pair from schematic page 67. The canonical XDC's obsolete `N48`/`N49` assignments are commented out.
- The repository and canonical XDC have 520 matching shared active assignments; the FF6 bonded-pin correction is intentionally repository-only.
- In VHDL IBERT port maps, pack or unpack vectors outside the map and associate each formal once. Repeated slice associations cause Vivado Synth 8-5838.

## Clock architecture

- The board 200-MHz clock drives the frequency monitor, I2C, and SysMon logic.
- A dedicated `BUFGCE_DIV` divides the raw board clock by four. Its 50-MHz output drives the distributed IBERT debug hub and XSDB/DRP register fabric, matching the vendor example clock expectation.
- Keep the divider output with `(* KEEP = "TRUE" *)` because the debug hub is inserted through XDC after synthesis.
- A `MMCME4_BASE` with a 1300-MHz VCO generates `clk_100` and `clk_325` from
  the 200-MHz board clock. The routed clock report must show 10.000-ns and
  3.077-ns periods respectively.
- Do not hard-wire GTY `SDM0WIDTH` or `SDM0DATA`. IBERT drives these from XSDB registers for runtime QPLL fractional-N configuration; Vivado's generated-clock warnings are conservative consequences of dynamic controls.

## Management interfaces

- The generic I2C register slave uses 7-bit address `0x2B`. Registers are
  byte-addressed, little-endian 32-bit words.
- The MCU ABI is fixed: `r00`/`0x00` and `r01`/`0x04` are scratch registers;
  `r02`-`r38`/`0x08`-`0x98` contain the 37 clock readings in the README order;
  `r39`/`0x9C` is status.
- Status is `[31:16]=0x434D`, bit 15 measurement-valid, `[14:8]=37`, and
  `[7:0]=1`. A valid status word is `0x434DA501`.
- Frequency values are kHz and are never multiplied by two. A nominal
  322.265625-MHz reference clock therefore reads about `322266`.
- SysMon PMBus addresses are SLR0=`0x36`, SLR1=`0x34`, SLR2=`0x47`, and
  SLR3=`0x45`.
- The current Tcl/XDC flow leaves bitstream compression disabled. If enabling
  it, set `BITSTREAM.GENERAL.COMPRESS` in a reproducible source file and update
  the documentation.

## Floorplanning and validation

- Vendor `quad_pblock.tcl` paths are relative to each generated wrapper. `scripts/apply_ibert_floorplan.tcl` must source them under the correct left/right `current_instance` context.
- The pre-place hook requires exactly 14 pblocks for each core.
- `scripts/validate_synthesized_design.tcl` checks 14 left quads, 14 right quads, 112 channels, the debug divider/net, and corrected FF3/FF6 mappings.
- Primary commands are `vivado -mode batch -source scripts/create_project.tcl` and `vivado -mode batch -source scripts/build_bitstream.tcl`.
- If post-synthesis validation stops an otherwise completed synthesis run, use `scripts/continue_after_synthesis.tcl` to avoid repeating synthesis.
