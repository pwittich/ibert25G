# VU13P IBERT Build State

Last updated: 2026-08-26

## Last validated implementation

The clean documented batch flow was revalidated on 2026-08-25 and wrote a
valid bitstream. That previously generated artifact is uncompressed; source
policy now requires compression for its next build. Routing had 800,029 fully routed nets and no
failed, unrouted, partially routed, or overlapping nets.

- Overall setup: WNS `+0.258 ns`, TNS `0`, no failing endpoints.
- Overall hold: WHS `+0.009 ns`, THS `0`.
- Pulse width: WPWS `+0.251 ns`, TPWS `0`.
- Routed clock report: `clk_200` 200.000 MHz, `clk_100_raw` 100.000 MHz,
  `clk_325_raw` 325.000 MHz, and `ibert_debug_clk_50` 50.000 MHz.
- The overall worst setup path is an IBERT RX/TX user-clock relationship, not the 200-MHz or debug network.
- Bitstream: `build/vu13p_ibert_25g.runs/impl_1/top.bit`.
- Bitstream SHA-256: `e6f49cef8ff91381ca2470c9b4860e90d13ea5ed98e48562ff14288365541e83`.
- Timing report: `build/vu13p_ibert_25g.runs/impl_1/top_timing_summary_routed.rpt`.
- All four reported bus-skew constraints pass; the smallest slack is
  `+19.250 ns`.

## HDL-first synthetic test-engine state

The first opt-in HDL-first migration target is implemented separately from the
golden `top` target. The golden project, generated IBERT wrappers, and 112-lane
IBERT ownership are unchanged.

- `gt_test_engine_core` accepts one AXI descriptor and controls 112 concurrent
  lane engines through toggle/acknowledge CDC handshakes.
- Per-lane snapshots contain status, 64-bit error and tested-bit counters,
  lock-loss count, and 64-bit valid-cycle time.
- Two 112-by-256-bit result banks infer as eight `RAMB36E2`; publication is an
  atomic bank swap followed by one completion interrupt.
- The generic-I2C mailbox occupies `0xA0`-`0xFF` at slave address `0x2B` and
  does not reassign the deployed `0x00`-`0x9F` monitor ABI. Those lower
  addresses read zero in the standalone synthetic top; the golden image still
  provides the operational clock-monitor registers.
- Synthetic simulation passes all-112-lane completion with the AXI master idle
  after the doorbell, immutable published results, isolated error/lock-loss
  injection, abort, timeout, bad-command rejection, and one interrupt.
- Out-of-context synthesis completes with zero errors, critical warnings, or
  warnings and infers eight `RAMB36E2` blocks.
- The separate Milestone 2 target now includes a Tcl-generated 200-MHz
  MicroBlaze, 32 KiB local BRAM, MDM/JTAG, 564-byte freestanding firmware, AXI
  test engine, direct level interrupt, and I2C mailbox. Version `0x00010002`
  has no AXI interrupt controller and drives the engine level into both
  `Interrupt` and the discrete `Wakeup[0]`; MDM `Dbg_Wakeup` drives
  `Wakeup[1]`.
- MicroBlaze uses no caches/MMU and sleeps after one descriptor/doorbell write;
  the ISR publishes the already-snapshotted hardware result without polling
  engine status during acquisition. Its interrupt-masked check/`sleep`
  sequence relies on the independent level-sensitive `Wakeup` input and closes
  the lost-wakeup race for jobs that finish at the sleep boundary.
- Both active-high RGB triplets are implemented and pin-checked. They show a
  blue heartbeat before the firmware-version AXI write, solid blue while a
  job is active, green for healthy idle, and red for an idle fault. The F1
  blue/green/red pins are `A30`/`A29`/`A28`; F2 uses
  `BL27`/`BL28`/`BL30`.
- The version `0x00010002` clean Milestone 2 implementation completed with WNS
  `+0.579 ns`, TNS `0`, WHS `+0.009 ns`, THS `0`, and 200.000-MHz `clk_200`.
- Milestone 2 route status has 84,087 fully routed nets and zero routing
  errors. Routed DRC has zero violations. CDC contains only eleven informational
  `CDC-3` entries for properly synchronized MDM/JTAG crossings; there are no
  CDC warnings or critical warnings. There are no bus-skew constraints in the
  synthetic target.
- Vivado reports all ten generated subsystem IP instances up-to-date with no
  changes required.
- Integrated synthesis uses 36,303 CLB LUTs, 52,655 CLB registers, and 16
  `RAMB36E2` blocks: eight result-bank blocks plus eight MicroBlaze local-memory
  blocks. Vectorless power estimates 3.503 W with medium confidence.
- Milestone 2 bitstream:
  `build/gt_test_milestone2/gt_test_milestone2.runs/impl_1/gt_test_milestone2_top.bit`.
- Milestone 2 bitstream SHA-256:
  `41e559b11fe2e058dc61addef32da321d24c4bb0d95d657bddaedf0d211f6f6a`.
- Supervisor ELF SHA-256:
  `23e2d3f5b286050c7170e80cae4b61ea4e472cc320105717260968e6eb9d02be`.
  The stable load-image SHA-256 is
  `c6067effe3753d9c52660c2b73e906a6e887c0baa1c46d8f5500df53b6b264d2`;
  those are the bytes initialized into processor BRAM. The firmware build uses
  explicitly named object files so random compiler temporary names cannot
  perturb the ELF symbol-table hash.
- The first board smoke test of the superseded bitstream
  `44ceb1cb5d1592305ad70f265e69a2776bc97a3ace02efee641a12ecee2c9197`
  read the hardware-owned version at `0xC4` correctly as `0x00010000`, but
  left the CPU-owned firmware version at `0xC0` as zero. Inspection of the
  implemented MMI showed a little-endian MicroBlaze while the embedded ELF was
  big-endian. The firmware now builds with `-mlittle-endian`, and the build
  rejects any ELF whose header does not match. The first little-endian
  replacement, SHA-256
  `e76121b45c71763efed0bc1265b00650a92a73cc4d21cdea81219a53eb3b9607`,
  passed a clean implementation. Its board smoke-test rerun passed on
  2026-08-25: both the CPU-owned firmware version at `0xC0` and the
  hardware-owned version at `0xC4` read `0x00010000`, and the RGB status
  settled immediately to healthy-idle green. The pre-firmware blue interval
  was shorter than was visually apparent, which is expected when firmware
  starts normally.
- The current Milestone 2 bitstream above is compressed, is 32,079,859 bytes,
  and passed the build-script check for
  `BITSTREAM.GENERAL.COMPRESS=TRUE`. Repository policy requires every new
  bitstream to be compressed; both target-specific XDC files set the property,
  and every bitstream-producing script checks it. The next clean golden IBERT
  run will also produce a compressed image.
- The RTL simulation proves completion with no AXI traffic after the doorbell,
  and basic board I2C/MicroBlaze startup now passes. The first mailbox-launched
  board job completed fully in HDL (`0xF8=0x00000001`,
  `0xFC=0x00707001`) but the CPU response remained zero at `0xF0`/`0xF4`.
  Inspection found Vivado automation had selected low-latency vectored mode
  while the freestanding firmware supplied a standard fixed `0x10` vector.
  Reading `0xC8=0x00004000` confirmed the engine interrupt remained pending
  and the ISR had not entered. A subsequent standard-mode AXI-controller board
  image still left the interrupt pending. Version `0x00010001` removed the
  controller, drove the single level interrupt directly into MicroBlaze in
  standard fixed-vector mode, and removed firmware controller initialization
  and acknowledgement. Its clean build passed timing, routing, DRC, CDC, and
  compression checks, and board reads of `0xC0=0xC4=0x00010001` proved the
  intended firmware and hardware were loaded. Nevertheless, `0xC8` remained
  `0x00004000`: MicroBlaze `sleep` waits for the separate `Wakeup` input, not
  `Interrupt` alone, and discrete ports had been disabled. Version
  `0x00010002` enables those ports and connects the engine interrupt to both
  inputs so the event wakes the pipeline before the fixed-vector ISR runs. The
  descriptor readback from that test also showed `B4=0x0000000F` and
  `BC=0x0000FFFF`, exactly explaining the atomic 84-lane summary
  (32 + 4 + 32 + 16); mask readback is now required before committing `A0`.
  The corrected version `0x00010002` board rerun passed on 2026-08-25:
  request/response sequence `0xF0=0x00000001`, CPU response
  `0xF4=0x00707001`, hardware run ID `0xF8=0x00000001`, and atomic hardware
  summary `0xFC=0x00707001`; the final state read was
  `0xC8=0x00000000`. This proves that MicroBlaze woke, serviced and cleared the
  completion interrupt, returned the engine to fault-free idle, and published
  the already-completed 112-lane result.
- The MDM halt-after-launch acceptance test passed on 2026-08-25. While
  MicroBlaze was halted during request sequence 2, the CPU-owned response
  remained `0xF0=0x00000001`, while hardware independently advanced to
  `0xF8=0x00000002`, published `0xFC=0x00707001`, and held the completion
  interrupt at `0xC8=0x00004000`. After `con`, firmware serviced that pending
  interrupt and produced `0xF0=0x00000002`, `0xF4=0x00707001`, with the
  hardware result unchanged and `0xC8=0x00000000`. This proves acquisition,
  timing, atomic publication, and result retention do not depend on CPU
  execution after launch. Milestone 2 hardware acceptance is complete; no
  physical GT is controlled by the test engine yet.

## Milestone 3 managed-quad build state

The current clean Milestone 3 implementation passed on 2026-08-27. This target
removes only FireFly 5 / physical quad 124 from the left IBERT core, leaves the
other 108 channels under the two reduced IBERT cores, and assigns managed
global lanes 12-15 to `GTYE4_CHANNEL_X0Y16`-`X0Y19`.

- The first routed attempt was rejected because WNS was `-0.195 ns` on a
  native `RXPRBSERR`-to-64-bit-counter path. The lane engine now registers the
  16-bit GT error bus before accumulator arithmetic and defers stop snapshot
  capture by one RX clock so the final pre-stop sample remains included.
- The clean rebuild passed authoritative routed timing with WNS `+0.138 ns`,
  TNS `0`, WHS `+0.008 ns`, THS `0`, WPWS `+0.248 ns`, and no failing
  endpoints.
- Route status has 864,171 fully routed nets and zero routing errors, failed
  nets, unrouted nets, partially routed nets, or node overlaps.
- All four bus-skew constraints pass; the smallest slack is `+19.515 ns`.
  Implemented primary clock periods report 200.000 MHz, 100.000 MHz,
  325.000 MHz, and the 50.000-MHz IBERT debug clock. The managed RX and TX
  user clocks report a 3.103-ns period.
- Utilization is 355,795 CLB LUTs, 606,588 CLB registers, 556 `RAMB36E2`, all
  112 `GTYE4_CHANNEL` sites, and 28 `GTYE4_COMMON` sites. The 112 channels are
  52 left-IBERT, 56 right-IBERT, and four managed quad-124 channels.
- Routed DRC contains no errors. Its five warnings are three generated
  debug-hub `PDCN-1569` findings, one generic-I2C `RPBF-3` bidirectional-port
  finding, and one generated debug/IBERT `RTSTAT-10` no-routable-load finding;
  the remaining 648 entries are generated-IBERT DSP power advisories.
- The detailed CDC report is not globally clean. It contains `CDC-3=17342`,
  `CDC-6=240`, `CDC-9=327`, `CDC-10=22`, `CDC-11=44`, `CDC-13=4`, and
  `CDC-15=17830`.
  The four 256-bit result transfers appear as XPM handshake synchronizers and
  the payload is no longer reported as a direct crossing. The critical
  findings are generated GT Wizard reset/status structures plus repeated
  two-flop start/stop and stable-descriptor controls; retain them for explicit
  review instead of describing this image as CDC-clean.
- Vectorless power is 76.864 W with medium confidence, including 70.496 W
  dynamic and 6.368 W static, at an estimated 60.1 C junction. Vivado warns
  that reset activity makes this estimate less accurate; board power and
  thermal monitoring are required during soak testing.
- The compressed bitstream is 71,214,671 bytes at
  `build/gt_test_milestone3/gt_test_milestone3.runs/impl_1/gt_test_milestone3_top.bit`.
  SHA-256 is
  `2adde4672dc227ad62c90f46b0c3b3e4013c1fb768eea7fb05f1260305582f5a`.
  Its matching 1,613-byte probes file is `gt_test_milestone3_top.ltx`.
- The embedded 1,376-byte supervisor ELF SHA-256 is
  `214010627452480da52f4352ceea545fd4678db57c343b56502b39b0149cf23f`.
  Consolidated reports are in `build/gt_test_milestone3_reports`.
- This clean image is eligible for the staged board smoke tests and soak plan;
  its shortened Milestone 3 hardware integration smoke test passed on
  2026-08-27. The managed quad returned aggregate `0x00040401`, matching
  response/run sequence 1, and final `C8=0`; lane 12 had zero errors and lock
  losses over about 25.78 billion bits. The other 108 IBERT-owned channels
  operated as before. The golden IBERT image remains the comparison and
  recovery image, and the longer soak/fault campaign remains deferred.
- After that hardware gate, the deferred comment-only SystemVerilog pass added
  architectural documentation to the handwritten AXI adapter, lane/core
  controllers, quad/PRBS controllers, managed wrapper, IBERT integration, and
  Milestone 3 top. No generated GT/IBERT structure or executable HDL statement
  was intentionally changed. Both engine simulations and both Milestone 3
  controller unit simulations passed, and `xvlog` parsed all commented modules.

## Isolated Milestone 2.5 smoke build

The corrected, uniquely versioned isolated build completed on 2026-08-26.
This is now the next hardware smoke candidate, ahead of another full
Milestone 3 implementation.

- `gt_test_milestone25_top` instantiates only the managed quad-124 GT Wizard;
  there are no IBERT cores and no other GT transmitter outputs. Implemented
  utilization confirms four `GTYE4_CHANNEL` cells at `X0Y16`-`X0Y19`, one
  `GTYE4_COMMON` at `X0Y4`, and only six ordinary output buffers for the LEDs.
- Hardware and firmware versions are `0x00020004`. The controller implements
  the high-rate near-end PMA loopback reset sequence, waits for PRBS lock, and
  reads exact 32-bit native `RX_PRBS_ERR_CNT` values through DRP `0x25E` and
  `0x25F`. Unit simulation covers reset ordering, external-loopback bypass,
  lock acquisition, DRP word assembly, and cleanup.
- The isolated target keeps all deployed clock-monitor and I2C/SysMon ABI
  ports. Its target XDC explicitly declares all twelve 322.265625-MHz REFCLK0
  inputs because the full IBERT timing XDCs are intentionally absent.
- The authoritative routed timing report has WNS `+0.434 ns`, TNS `0`, WHS
  `+0.010 ns`, THS `0`, WPWS `+0.454 ns`, and no failing endpoints. It reports
  200.000, 100.000, and 325.000 MHz plus the managed RX/TX and REFCLK clocks at
  322.269 MHz after Vivado's 1-ps period rounding.
- Route status contains 103,160 fully routed nets and zero routing errors.
  There are no bus-skew constraints in this isolated target. Routed DRC has no
  errors and one existing `RPBF-3` warning on incomplete bidirectional
  buffering for `i2c_scl_f_generic`.
- Methodology and CDC are not globally clean. The methodology report retains
  one related-RX/TX-clock `TIMING-7` finding and 1,000 `TIMING-17` findings on
  monitor counters driven by clock-monitor inputs that have no timing clock.
  CDC critical entries are predominantly generated GT Wizard reset/status
  structures; the explicit application synchronizers and four XPM result
  handshakes remain visible. These findings were reviewed, not silently called
  clean.
- Vectorless power is 6.868 W at medium confidence (3.790 W dynamic, 3.079 W
  static, estimated 28.1 C). Actual board supply and temperature readings are
  required because vectorless reset activity is not representative.
- Synthesis took 3:04 elapsed; placement 4:29; routing 2:26; bit generation
  1:36. The complete implementation run took 11:11 elapsed and the full clean
  script took 18:12. Synthesis had no errors or critical warnings; placement
  and routing each completed with no errors or critical warnings.
- The compressed bitstream is 33,383,572 bytes at
  `build/gt_test_milestone25/gt_test_milestone25.runs/impl_1/gt_test_milestone25_top.bit`.
  SHA-256 is
  `49c8a71111d00bb30bd65892e09dc26995d79d7186702b724d7eeab3896e7d8a`.
  The embedded 1,376-byte ELF SHA-256 is
  `214010627452480da52f4352ceea545fd4678db57c343b56502b39b0149cf23f`.
- The first board attempt used the superseded `0x00020001` candidate. Its
  completion words were `F0=1`, `F4=0x04000404`, `F8=1`, and
  `FC=0x04000404`; `C8=0x00010000` reported a latched platform fault. Lane 12
  returned the engine's deterministic platform-failure record
  (`D0=0x0000280c`, all measurement fields zero, `E4=1`). That `E4` value is
  synthetic and is not evidence of observed PRBS lock loss.
- Candidate `0x00020002` extended the PRBS reset qualifier through loopback
  application, PMA reset, counter reset, and lock wait, but failed identically.
  XSDB read AXI platform status `0x44A00070` as `0x00000085`, proving the quad
  supervisor entered state 5 / FAULT. The remaining cause was a synchronizer
  race: PRBS lock could arrive before RX user-clock-active/reset-done reached
  the supervisor. Version `0x00020003` adds bounded intentional RX
  requalification while preserving `quad_ready`, and exposes an eight-bit
  latched fault reason at AXI `0x070[15:8]`. Unit simulation covers delayed RX
  readiness, successful requalification, unexpected RX loss, and QPLL loss.
  Neither superseded bitstream may be programmed again: `0x00020001` hash
  `85cefe9aad58bf3040444ebabc91ce36e0073dcf7b2a634bbbcdb33de772553e`;
  `0x00020002` hash
  `ff79a4e01be52dafb77eb93966433ac56c788ac4a8a8349c58e1084e64bffca0`.
- Hardware smoke acceptance passed on F1 for both a four-lane external
  optical-loopback PRBS31 run and a near-end PMA-loopback PRBS31 run. Both
  returned aggregate `0x00040401`, zero errors and lock losses in all four
  lane records, and healthy final `C8=0`. The earlier external-path failure
  was resolved by correcting the optical setup (about 3 dB of path loss), not
  by an HDL change. The planned comment-only SystemVerilog pass remains
  deferred until the full Milestone 3 smoke gate passes.

## External MCU support state

- The external target is the TM4C1290NCPDT TivaWare/FreeRTOS firmware in the
  public `apollo-lhc/cm_mcu` repository, primary project
  `projects/cm_mcu`. This is separate from the embedded MicroBlaze firmware.
- `mcu/gt_test_mcu_protocol.h` provides byte-exact, endian-independent request,
  completion, summary, and lane-result structures and decode helpers for the
  `0xA0`-`0xFF` mailbox.
- `mcu/cm_mcu/GTTestEngine.c` and `.h` bind those structures to the existing
  `apollo_i2c_ctl_*()` API. Following `clk_freq_fpga_cmd()`, each operation
  acquires the I2C5 semaphore, selects mux `0x70` channel 2 for F1 or channel 0
  for F2, accesses slave `0x2B`, clears the mux, and then releases the
  semaphore. Error paths perform the same cleanup.
- Submit writes and reads back command, duration, timeout, and all four mask
  words before committing request sequence `0xA0`. Result collection reads
  managed global lanes 12-15 under one semaphore/mux ownership interval and
  checks the hardware run ID before and after the multi-transaction read.
- The portable protocol test and mocked `cm_mcu` transport test pass with
  C11, pedantic warnings, and warnings-as-errors. The adapter also compiles
  cleanly against the current `cm_mcu` and pinned FreeRTOS headers using the
  compiler selected by `/nfs/cms/tracktrigger/wittich/apollo_setup.sh`: Arm
  GNU Toolchain 14.2.Rel1 (`arm-none-eabi-gcc` 14.2.1), producing a 1,047-byte
  release-style (`-Os`) object with no data or BSS.
- These files are ready to copy into `projects/cm_mcu`, but they have not yet
  been integrated into a `cm_mcu` branch or exercised on the board. The CLI
  path has passed the shortened Milestone 3 hardware integration smoke test.

## Root cause and resolution

The original timing failure was not caused by ordinary 200-MHz monitor/I2C logic. The generated IBERT debug/DRP network had been attached to the board's 200-MHz fabric clock even though vendor constraints expected 50 MHz. Its worst path crossed SLRs from the debug hub to IBERT XSDB logic with roughly 2,045 fanout and about 5.8 ns of routing against a 5-ns period.

The fix was to retain 200 MHz for application logic and create a physical 50-MHz `BUFGCE_DIV` clock for `dbg_hub` and IBERT XSDB/DRP. Correct application of all 28 vendor quad pblocks was also required.

## Remaining review items before hardware use

- Routed DRC has no errors. It reports three generated debug-hub PDCN-1569
  violations, one RPBF-3 violation on bidirectional `i2c_scl_f_generic`, one
  RTSTAT-10 violation for generated debug/IBERT nets with no routable loads,
  and 672 generated-IP power advisories.
- Methodology reports contain many generated-IBERT warnings, notably TIMING-7 for related dynamically generated clocks, TIMING-17 for non-clocked sequential cells, and TIMING-54 scoped false paths. Timing passes, but these warnings should be dispositioned before programming hardware.
- GT routing reports north/south reference-clock pin swaps onto physically equivalent resources. Keep this in the hardware-review checklist.

## Working tree

The source changes associated with this build were not committed when this
file was last updated. Do not discard unrelated work or commit generated
products. The modifications cover pin/lane corrections, local IP generation,
synthesized-design validation, hierarchical floorplan hooks, the 50-MHz debug
clock, the 100/325-MHz MMCM, the generic-I2C register remap and direct-kHz
scaling, SysMon addressing, build timing checks, and documentation.
