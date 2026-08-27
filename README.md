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

All bitstream targets default to compressed output. The golden `top.bit` sets
`BITSTREAM.GENERAL.COMPRESS` in `constraints/board_pins.xdc`; the separate
Milestone 2 target sets the same property in its target-specific XDC, and
Milestone 3 inherits the board constraint. Every bitstream build script rejects
output if compression is not enabled.

The generated IBERT `quad_pblock.tcl` files contain paths relative to each
generated-core wrapper. `scripts/apply_ibert_floorplan.tcl` is installed as a
pre-place hook so the encrypted vendor constraints execute in the correct
hierarchical context; the hook requires 14 pblocks from each core.

The board's 200-MHz oscillator clocks the frequency monitor, I2C, and SysMon
logic. A dedicated `BUFGCE_DIV` output divides it by four for the distributed
IBERT debug hub and XSDB/DRP register fabric, matching the vendor example's
50-MHz debug-clock configuration.

If synthesis completed but a post-synthesis validation stopped the build, reuse
that checkpoint instead of rebuilding it:

```sh
vivado -mode batch -source scripts/continue_after_synthesis.tcl
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
  dedicated SysMon PMBus pair. The 7-bit addresses are SLR0=`0x36`,
  SLR1=`0x34`, SLR2=`0x47`, and SLR3=`0x45`.

The four addresses are deliberately visible in the `sysmon_i2c_ssi` instance
in `src/top.sv` so they can be changed easily. Address bit 2 is set to select
PMBus behavior in `SYSMONE4`.

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

## HDL-first parallel-test migration shell

An opt-in Milestone 2 hardware target provides the first HDL-first migration
stage without changing the golden IBERT project or `src/top.sv`. It includes a
Tcl-generated MicroBlaze supervisor, embedded interrupt-driven firmware, an
AXI4-Lite job controller, 112 concurrent synthetic lane engines, explicit CDC
handshakes, atomic double-buffered result BRAM, one completion interrupt, and
the reserved `0xA0`-`0xFF` I2C mailbox at the existing generic-slave address
`0x2B`. Both FPGA RGB LED triplets show a pre-firmware blue heartbeat, solid
blue while busy, healthy-idle green, or idle fault red; green depends on an
AXI write made by the embedded C supervisor. See
[docs/gt-test-engine.md](docs/gt-test-engine.md) for the separate build
commands, register map, result format, validation evidence, and LED pinout.

Milestone 3 is a second opt-in target. It removes only FireFly 5 / physical
quad 124 from the left IBERT core, manages those four lanes through a native
GT Wizard and HDL quad/lane controllers, and leaves the other 108 lanes under
IBERT. It adds atomic XPM result handshakes, native PRBS/loopback/error
injection, fatal quad-fault completion, and a 1-ms hardware timebase for long
soaks. The build and first-board-test commands are in the same document; keep
the compressed golden IBERT image available as the recovery image.

## Generic I2C clock monitor

The secondary board I2C pins (`V36`/`J32`) host a separate 7-bit slave at
`0x2B`. Its address is set on the `i2c_register_slave` instance in `src/top.sv`.
Registers are byte addressed; multi-byte values are little endian. A write of
the register address followed by data writes consecutive bytes. A write of the
register address followed by a repeated-start read reads consecutive bytes.

The MCU names each aligned 32-bit location `rNN`, where `NN` is the decimal
word index and the I2C byte address is `4*NN`.

| MCU register | Byte address | Access | Value |
|---:|---:|---|---|
| `r00` | `0x00` | R/W | Debug scratch register 0 |
| `r01` | `0x04` | R/W | Debug scratch register 1 |
| `r02` | `0x08` | R | `clk_200_ext` frequency in kHz |
| `r03` | `0x0C` | R | `lhc_clk` frequency in kHz |
| `r04` | `0x10` | R | `tcds40_clk` frequency in kHz |
| `r05` | `0x14` | R | `rt_x4_r0_clk` frequency in kHz |
| `r06` | `0x18` | R | `rt_x12_r0_clk` frequency in kHz |
| `r07` | `0x1C` | R | `lf_x4_r0_clk` frequency in kHz |
| `r08` | `0x20` | R | `lf_x12_r0_clk` frequency in kHz |
| `r09` | `0x24` | R | Generated `clk_100` frequency in kHz |
| `r10` | `0x28` | R | Generated `clk_325` frequency in kHz |
| `r11` | `0x2C` | R | `rt_r0_p` frequency in kHz |
| `r12` | `0x30` | R | `rt_r0_n` frequency in kHz |
| `r13` | `0x34` | R | `rt_r0_l` frequency in kHz |
| `r14` | `0x38` | R | `rt_r0_i` frequency in kHz |
| `r15` | `0x3C` | R | `rt_r0_g` frequency in kHz |
| `r16` | `0x40` | R | `rt_r0_e` frequency in kHz |
| `r17` | `0x44` | R | `rt_r0_b` frequency in kHz |
| `r18` | `0x48` | R | `lf_r0_y` frequency in kHz |
| `r19` | `0x4C` | R | `lf_r0_w` frequency in kHz |
| `r20` | `0x50` | R | `lf_r0_u` frequency in kHz |
| `r21` | `0x54` | R | `lf_r0_r` frequency in kHz |
| `r22` | `0x58` | R | `lf_r0_af` frequency in kHz |
| `r23` | `0x5C` | R | `lf_r0_ad` frequency in kHz |
| `r24` | `0x60` | R | `lf_r0_ab` frequency in kHz |
| `r25` | `0x64` | R | `rt_r1_p` frequency in kHz |
| `r26` | `0x68` | R | `rt_r1_n` frequency in kHz |
| `r27` | `0x6C` | R | `rt_r1_l` frequency in kHz |
| `r28` | `0x70` | R | `rt_r1_i` frequency in kHz |
| `r29` | `0x74` | R | `rt_r1_g` frequency in kHz |
| `r30` | `0x78` | R | `rt_r1_e` frequency in kHz |
| `r31` | `0x7C` | R | `rt_r1_b` frequency in kHz |
| `r32` | `0x80` | R | `lf_r1_y` frequency in kHz |
| `r33` | `0x84` | R | `lf_r1_w` frequency in kHz |
| `r34` | `0x88` | R | `lf_r1_u` frequency in kHz |
| `r35` | `0x8C` | R | `lf_r1_r` frequency in kHz |
| `r36` | `0x90` | R | `lf_r1_af` frequency in kHz |
| `r37` | `0x94` | R | `lf_r1_ad` frequency in kHz |
| `r38` | `0x98` | R | `lf_r1_ab` frequency in kHz |
| `r39` | `0x9C` | R | ID/status word |

The status layout is `[31:16]=0x434D` (`CM`), bit 15=`measurement_valid`,
`[14:8]=37` monitored clocks, and `[7:0]=1` format version. Thus a completed
valid measurement reads `0x434DA501`. This word belongs at `r39`, not `r38`.

The 1-ms measurement window uses the board's 200-MHz oscillator as its
absolute reference. Entry 0 consequently reports the configured nominal
200,000 kHz; all other entries are measured relative to it. Missing or stopped
clocks report zero after the next completed window.

The 100- and 325-MHz monitor clocks are generated from `clk_200` by an MMCM
configured equivalently to a Clocking Wizard with a 1300-MHz VCO. GT monitor
values are reported directly; no additional multiply-by-two scaling is used.
For example, a 322.265625-MHz GT reference clock should read approximately
`322266`, not `644531`.

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
constraint file. The active package pins were cross-checked against the RevA
January 2025 schematic and canonical `VU13P_pins.xdc`: all 520 shared entries
match. FF6 RX lane 1 uses the schematic's bonded `M48`/`M49` pair; the canonical
XDC instead has obsolete `N48`/`N49` assignments commented out.

The VHDL integration wrapper deliberately packs each IBERT vector into an
intermediate signal before the port map. Do not replace this with multiple
slice associations of the same formal; Vivado reports Synth 8-5838 for that
construct.

FireFly 3 is the exception to the otherwise ascending lane packing. Schematic
page 64 maps lane 11 to GTY128 channel 0 and lane 0 to GTY130 channel 3, so its
12-bit RX and TX segments are reversed at the IBERT wrapper boundary. The
package-pin constraints retain the board's lane numbering.

A clean Vivado 2023.2 batch build remains the authoritative validation step.
