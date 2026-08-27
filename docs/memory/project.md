# VU13P IBERT Project Memory

Last updated: 2026-08-27

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
- Repository policy is that every new bitstream is compressed. The golden
  IBERT and Milestone 2 targets each set `BITSTREAM.GENERAL.COMPRESS=TRUE` in
  their target-specific XDC, and every bitstream-producing build script rejects
  a generated design if that property is not active.

## External board MCU integration

- The external board-MCU codebase is the public
  `apollo-lhc/cm_mcu` GitHub repository. Its primary runtime binary is built
  from `projects/cm_mcu` for the TI TM4C1290NCPDT using TivaWare and FreeRTOS.
  Do not confuse this firmware with the FPGA-resident MicroBlaze supervisor.
- On Cornell rev3, FPGA register traffic uses MCU I2C controller 5. Both FPGAs
  sit behind TCA9548A mux address `0x70`: channel 2 (`0x04`) selects F1 and
  channel 0 (`0x01`) selects F2. The FPGA generic register slave is then at
  address `0x2B` with a one-byte register address and little-endian data.
- Follow `clk_freq_fpga_cmd()` in
  `projects/cm_mcu/commands/ClockCommands.c` for I2C ownership: obtain the
  I2C5 software semaphore, select exactly one mux channel, retain the semaphore
  for the complete multi-register operation, clear the mux, and only then
  release the semaphore. Cleanup must clear/release on every error path.
- Use the existing interrupt-driven `apollo_i2c_ctl_reg_r/w()` functions from
  `I2CCommunication.c`; do not bypass their persistent per-bus buffers,
  FreeRTOS notification completion, bounded idle wait, or timeout handling
  with direct TivaWare I2C calls.
- `/nfs/cms/tracktrigger/wittich/apollo_setup.sh` currently selects
  `/nfs/cms/tracktrigger/wittich/arm-gnu-toolchain-14.2.rel1-x86_64-arm-none-eabi/bin`.
  The compiler reports Arm GNU Toolchain 14.2.Rel1, GCC 14.2.1.
- MCU-side protocol definitions live in `mcu/gt_test_mcu_protocol.h`; the
  ready-to-copy `projects/cm_mcu` binding is in `mcu/cm_mcu/GTTestEngine.c`
  and `.h`. It holds the I2C5 semaphore across mux selection and all mailbox
  accesses, verifies every request field before committing sequence `0xA0`,
  and rejects a result collection if the run ID changes during lane reads.

## HDL-first migration architecture

- Keep `src/top.sv` and the current 112-lane standalone IBERT build as the
  golden diagnosis and recovery target.
- The opt-in synthetic engine is composed of `gt_test_engine_core`, 112
  `gt_lane_engine` instances, `axi_lite_gt_test_engine`, and
  `gt_test_hardware_shell`.
- AXI descriptor registers contain opcode, PRBS selection, duration, timeout,
  and a 112-bit lane mask. A single doorbell launches the job; acquisition does
  not require CPU polling.
- Result publication uses two hardware-owned 112-by-256-bit banks. The active
  bank is hidden and the published bank remains immutable until the next
  completed atomic swap.
- I2C bytes `0xA0`-`0xFF` form the MCU/CPU mailbox. Firmware must validate and
  translate mailbox requests into the executable AXI descriptor and then wait
  for the completion interrupt.
- Synthetic RX clocks share the management clock, while Milestone 3 lanes
  12-15 use the managed quad's RX user clock. Their 256-bit snapshots cross
  through four `xpm_cdc_handshake` instances; a lane acknowledges stop only
  after management-domain capture. Control toggles and GT status use explicit
  two-flop synchronization.
- Milestone 2 adds a separate Tcl-generated 200-MHz MicroBlaze subsystem with
  32 KiB local BRAM, MDM/JTAG, embedded freestanding firmware, and the
  synthetic engine at `0x44A00000`. Because there is exactly one level
  interrupt source, it connects directly to MicroBlaze and no AXI interrupt
  controller is instantiated.
- The single engine interrupt is level-sensitive and uses standard MicroBlaze
  interrupt mode with the fixed vector at `0x10`. Low-latency vectored mode is
  explicitly disabled because this supervisor has no need for per-source
  hardware vectors.
- MicroBlaze discrete ports are enabled because the `sleep` instruction waits
  on the separate `Wakeup` input, not on `Interrupt` alone. `Wakeup[0]` is the
  engine interrupt and `Wakeup[1]` is MDM `Dbg_Wakeup`; the same engine level
  therefore wakes the sleeping processor and then enters the standard ISR.
- MicroBlaze uses no caches, MMU, UART, timer, or external memory. It retains a
  barrel shifter and MSR/interrupt instructions, uses software multiply, and
  exposes one 32-bit AXI4-Lite master. These choices keep it a deterministic,
  small supervisor while HDL owns acquisition timing and result storage.
- Vivado configures this MicroBlaze little-endian. The freestanding firmware
  must be compiled with `-mlittle-endian`; its build script checks the ELF
  header before it can be embedded. A big-endian ELF is not executable by this
  subsystem even if Vivado accepts it for BRAM initialization.
- Firmware polls only for a new MCU mailbox sequence while idle. After one
  descriptor and doorbell write it sleeps until the completion interrupt; it
  does not poll engine state during acquisition. Interrupts are masked across
  the completion-check/`sleep` boundary; the independent level-sensitive
  `Wakeup` input releases the CPU before firmware enables and services the
  pending ISR, preventing a lost-wakeup race for very short jobs.
- The Milestone 2 target drives both active-high board RGB LED triplets with
  the same status: pre-firmware blue heartbeat, solid blue while busy, green
  for firmware-alive/healthy idle, and red for a failed or rejected idle
  result. Green is gated by the firmware-version AXI write and therefore proves
  that MicroBlaze executed the embedded supervisor.
- The Milestone 2 image has passed its board I2C and MicroBlaze-halted
  completion tests. Managed quad 124 is therefore the next migration stage;
  its four FireFly 5 lanes must remain exclusive to either IBERT or the native
  GT wrapper in any one build.
- Milestone 3 acceptance includes staged quad-124 initialization,
  internal/external PRBS, targeted error and lock-loss injection, abort,
  timeout, CPU-halted completion, and one-hour, 12-hour, and 24-hour soaks.
  The managed mask is exactly global lanes 12-15 (`0x0000F000` in the low
  word); hardware must reject any descriptor selecting the other 108 lanes.
- Descriptor control bit 16 selects an HDL-generated 1-ms duration/timeout
  timebase. It allows one uninterrupted job of about 49.7 days while retaining
  200-MHz cycle mode for short tests and preserving CPU-independent timing.
  MCU automation may sequence and log jobs but must not own BER timing,
  counter acquisition, or silently retry failures.
- The isolated Milestone 2.5 target is `gt_test_milestone25_top`. It enables
  only physical quad 124 (`GTYE4_CHANNEL_X0Y16`-`X0Y19`) and instantiates no
  IBERT cores or other GT transmitters. The full `gt_test_milestone3_top`
  target uses the same four-channel 25.78125-Gb/s GT Wizard on `lf_r0_af` and
  leaves the other 108 lanes under IBERT. The current hardware and firmware
  version is `0x00020004`; the managed mask is exactly low-word `0x0000F000`
  and all other lane-mask words zero.
- The quad controller performs reset hold and bounded power/QPLL/user-clock/
  reset-done qualification. An intentional runtime RX reset enters bounded RX
  requalification without dropping `quad_ready`; all other qualified losses
  remain fatal. Platform readiness is required at the AXI doorbell. AXI
  `0x070` exposes state/ready/fault plus an eight-bit latched fault reason.
- Native TX PRBS error injection uses W1-toggle AXI offsets `0x060`-`0x06C`;
  hardware masks writes so only managed lanes can change.
- Near-end PMA loopback at 25.78125 Gb/s is entered by asserting `GTRXRESET`
  with `LOOPBACK=000`, selecting `LOOPBACK=010`, then pulsing `RXPMARESET`.
  The quad supervisor qualifies expected RX-status transitions through the
  complete PMA reset and PRBS reacquisition interval; the qualification drops
  only after selected lanes lock. Measurement then begins. At stop, the
  controller reads exact native
  `RX_PRBS_ERR_CNT` lower/upper words through DRP `0x25E`/`0x25F` for each
  selected lane; it no longer interprets `RXPRBSERR` assertion cycles as bit
  errors.
- The 2026-08-27 clean Milestone 3 build passes routed timing with WNS
  `+0.138 ns` and WHS `+0.008 ns`, has zero routing errors, passes all four
  bus-skew constraints, and is compressed. It contains 52 left-IBERT lanes,
  four exclusively managed quad-124 lanes, and 56 right-IBERT lanes. It is a
  board smoke-test candidate, not yet hardware-accepted.
- The final isolated Milestone 2.5 `0x00020004` image passed both external
  optical-loopback and near-end PMA-loopback one-second, four-lane PRBS31
  smoke tests with aggregate `0x00040401`, zero lane errors or lock losses,
  and healthy final `C8=0`.
- The full Milestone 3 integration smoke test passed on 2026-08-27. The
  managed four-lane run returned matching response/run sequence 1, matching
  firmware/hardware summary `0x00040401`, and healthy final `C8=0`. Lane 12
  independently reported zero errors, zero lock losses, about 25.78 billion
  tested bits, and a normal stop. The other 108 IBERT-owned channels operated
  as before. Longer fault campaigns and soaks remain deferred qualification.

## Floorplanning and validation

- Vendor `quad_pblock.tcl` paths are relative to each generated wrapper. `scripts/apply_ibert_floorplan.tcl` must source them under the correct left/right `current_instance` context.
- The pre-place hook requires exactly 14 pblocks for each core.
- `scripts/validate_synthesized_design.tcl` checks 14 left quads, 14 right quads, 112 channels, the debug divider/net, and corrected FF3/FF6 mappings.
- Primary commands are `vivado -mode batch -source scripts/create_project.tcl` and `vivado -mode batch -source scripts/build_bitstream.tcl`.
- If post-synthesis validation stops an otherwise completed synthesis run, use `scripts/continue_after_synthesis.tcl` to avoid repeating synthesis.
- Validate the HDL-first engine with
  `vivado -mode batch -source scripts/run_gt_test_engine_sim.tcl` and
  `vivado -mode batch -source scripts/synthesize_gt_test_engine.tcl`.
- Build Milestone 2 with `scripts/build_milestone2_firmware.sh`,
  `vivado -mode batch -source scripts/create_milestone2_project.tcl`, and
  `vivado -mode batch -source scripts/build_milestone2_bitstream.tcl`.
- Build Milestone 3 with `scripts/build_milestone3_firmware.sh` and
  `vivado -mode batch -source scripts/build_milestone3_bitstream.tcl`.
- Build the isolated Milestone 2.5 smoke image with the same firmware and
  `vivado -mode batch -source scripts/build_milestone25_bitstream.tcl`.
- Validate the external-MCU structures and `cm_mcu` adapter with
  `sim/test_gt_test_mcu_protocol.c` and `sim/test_gt_test_cm_mcu.c`; compile the
  adapter with the Arm compiler selected by `apollo_setup.sh` and the real
  `cm_mcu`/pinned-FreeRTOS headers.
