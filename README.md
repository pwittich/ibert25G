# VU13P 25.78125-Gb/s IBERT

Reproducible Vivado 2023.2 project for exercising the FireFly and direct
FPGA-to-FPGA GTY links on the Apollo Cornell rev3 dual-VU13P board. The same
bitstream is intended for either FPGA site because the relevant pinout and
clocking are identical at this level.

## Quick start

The build requires Vivado 2023.2 with support for UltraScale+ devices:

```sh
vivado -mode batch -source scripts/create_project.tcl
```

This creates `build/vu13p_ibert_25g.xpr`. To generate the bitstream directly:

```sh
vivado -mode batch -source scripts/build_bitstream.tcl
```

Generated projects, IP products, reports, and run directories are ignored by
Git. Review `report_ip_status`, synthesis and implementation warnings, DRCs,
timing, and implemented GT placement before programming hardware.

## Configuration

- Device: `xcvu13p-flga2577-2-e`
- Line rate: 25.78125 Gb/s
- GT reference clocks: REFCLK0, 322.265625 MHz
- FireFly: 56 TX/RX lanes in GTY quads 121-134
- FPGA-to-FPGA: 56 TX/RX lanes in GTY quads 221-234
- Quad-L AXI C2C links are intentionally excluded; that interface operates at 10 Gb/s.
- Top level: `src/top.sv` (SystemVerilog).
- Four `SYSMONE4` monitors, explicitly placed one per SLR, sharing the board's
  dedicated SysMon I2C pair. Default 7-bit addresses are SLR0=`0x30`,
  SLR1=`0x31`, SLR2=`0x32`, and SLR3=`0x33`.

The four addresses are deliberately visible in the `sysmon_i2c_ssi` instance
in `src/top.sv` so they can be changed easily. Address bit 2 must remain zero
for I2C mode; setting it selects PMBus behavior in `SYSMONE4`.

## Repository layout

| Path | Purpose |
|---|---|
| `src/top.sv` | SystemVerilog top level, address settings, and register map |
| `src/ibert_top.vhd` | Physical-lane packing for the two IBERT wrappers |
| `src/ibert_ultrascale_gty_*.vhd` | Structural wrappers for the generated IBERT IP |
| `src/clock_*.sv` | Input buffering and frequency measurement |
| `src/i2c_register_slave.sv` | Secondary I2C register slave |
| `src/sysmon_i2c_ssi.sv` | Four SLR-local SysMon instances and shared I2C wiring |
| `ip/` | Vivado IBERT XCI configurations |
| `constraints/` | Board pins, IP timing, SysMon placement, and CDC constraints |
| `scripts/` | Reproducible project creation and bitstream build |

## Generic I2C clock monitor

The secondary board I2C pins (`V36`/`J32`) host a separate 7-bit slave at
`0x42`. Its address is set on the `i2c_register_slave` instance in `src/top.sv`.
Registers are byte addressed; multi-byte values are little endian. A write of
the register address followed by data writes consecutive bytes. A write of the
register address followed by a repeated-start read reads consecutive bytes.

| Byte address | Size | Access | Description |
|---:|---:|---|---|
| `0x00` | 4 | R/W | Debug scratch register |
| `0x04` | 4 | R | ID/status: `[31:16]=0x434D`, bit 15 valid, `[14:8]=37`, `[7:0]=1` |
| `0x08 + 4*n` | 4 | R | Clock `n` frequency in kHz |

The 100-ms measurement window uses the board's 200-MHz oscillator as its
absolute reference. Entry 0 consequently reports the configured nominal
200,000 kHz; all other entries are measured relative to it. Missing or stopped
clocks report zero after the next completed window.

| n | Clock | n | Clock |
|---:|---|---:|---|
| 0 | `clk_200` (nominal reference) | 19 | `lf_r1_r` |
| 1 | `lf_x12_r0_clk` | 20 | `lf_r1_u` |
| 2 | `lf_x4_r0_clk` | 21 | `lf_r1_w` |
| 3 | `rt_x12_r0_clk` | 22 | `lf_r1_y` |
| 4 | `rt_x4_r0_clk` | 23 | `rt_r0_n` |
| 5 | `tcds40_clk` | 24 | `rt_r0_p` |
| 6 | `lhc_clk` | 25 | `rt_r0_b` |
| 7 | `lf_r0_ab` | 26 | `rt_r0_e` |
| 8 | `lf_r1_ab` | 27 | `rt_r0_g` |
| 9 | `rt_r0_l` | 28 | `rt_r0_i` |
| 10 | `rt_r1_l` | 29 | `rt_r1_n` |
| 11 | `lf_r0_ad` | 30 | `rt_r1_p` |
| 12 | `lf_r0_af` | 31 | `rt_r1_b` |
| 13 | `lf_r0_r` | 32 | `rt_r1_e` |
| 14 | `lf_r0_u` | 33 | `rt_r1_g` |
| 15 | `lf_r0_w` | 34 | `rt_r1_i` |
| 16 | `lf_r0_y` | 35 | left IBERT control clock |
| 17 | `lf_r1_ad` | 36 | right IBERT control clock |
| 18 | `lf_r1_af` |  |  |

## Required board setup

Program every REFCLK0 synthesizer output used below to 322.265625 MHz before
starting IBERT scans. REFCLK1 is not used by this image.

| Link group | GTY quads | Physical REFCLK0 input |
|---|---:|---|
| FireFly 1 | 121-123 | quad 122 / `lf_r0_ad` |
| FireFly 5 | 124 | quad 124 / `lf_r0_af` |
| FireFly 2 | 125-127 | quad 126 / `lf_r0_r` |
| FireFly 3 | 128-130 | quad 129 / `lf_r0_u` |
| FireFly 6 | 131 | quad 131 / `lf_r0_w` |
| FireFly 4 | 132-134 | quad 133 / `lf_r0_y` |
| FPGA-FPGA M/N/O | 221-223 | quad 222 / `rt_r0_n` |
| FPGA-FPGA P | 224 | quad 224 / `rt_r0_p` |
| FPGA-FPGA A/B/C | 225-227 | quad 226 / `rt_r0_b` |
| FPGA-FPGA D/E/F | 228-230 | quad 229 / `rt_r0_e` |
| FPGA-FPGA G | 231 | quad 231 / `rt_r0_g` |
| FPGA-FPGA H/I/J | 232-234 | quad 233 / `rt_r0_i` |

## Source and provenance

The pin assignments are a restricted extraction of the upstream
`configs/Cornell_rev3_p2_VU13p-1-SM_USP/src/top_pins.xdc` file. The two IBERT
XCI configurations and their structural wrappers derive from the upstream
`Cornell_rev3_p2_VU13p-1-SM_USP_heaters_TF` reference implementation. The
top-level mapping was rewritten for the rev3 FireFly numbering in the supplied
constraint file.

The VHDL integration wrapper deliberately packs each IBERT vector into an
intermediate signal before the port map. Do not replace this with multiple
slice associations of the same formal; Vivado reports Synth 8-5838 for that
construct.

This archive was assembled without Vivado installed in its creation
environment. A clean Vivado 2023.2 batch build is therefore the authoritative
validation step.
