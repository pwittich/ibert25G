# HDL-first GT test engine

This is the migration shell for the HDL-first parallel GT test architecture.
It is deliberately separate from the golden `top` target: the existing Vivado
project and its 112 standalone IBERT lanes are unchanged.

## Implemented Milestone 2 and Milestone 3 architecture

- One AXI4-Lite job controller accepts one opcode, PRBS mode, duration,
  timeout, and 112-bit lane mask.
- 112 lane engines run concurrently. Each has toggle/acknowledge CDC
  handshakes for start and stop, native PRBS controls, saturating 64-bit error
  and tested-bit counters, lock-loss tracking, and an atomic result snapshot.
- The global controller does no per-lane polling while a test is active. It
  waits for one collective start acknowledgement, times the job, issues one
  stop request, copies stable snapshots, swaps the result banks, increments the
  run ID, and raises one level interrupt.
- Two 112-by-256-bit result banks infer as eight `RAMB36E2` blocks. The bank
  visible to software stays immutable until the next complete publish.
- Normal completion, abort, and timeout all publish partial or complete atomic
  results. A rejected command raises the fault interrupt without consuming a
  run ID.
- The synthetic shell ties all RX domains to the 200-MHz management clock and
  exposes per-lane lock and 16-bit error stimuli. A managed-GT target replaces
  those stimuli with GT Wizard/native-GT signals and independent RX user
  clocks.
- A generic-I2C slave at `0x2B` exposes the `0xA0`-`0xFF` mailbox window. MCU
  request fields are distinct from the executable descriptor, so firmware
  must validate and translate a request before ringing the AXI doorbell.
- A Tcl-generated MicroBlaze subsystem runs at 200 MHz with 32 KiB of local
  BRAM, MDM/JTAG debug, and one external AXI4-Lite master connected to the
  engine at `0x44A00000`. The engine's sole level interrupt connects directly
  to MicroBlaze; no AXI interrupt controller is needed for one source. That
  same level drives `Wakeup[0]`, because an interrupt does not by itself wake a
  MicroBlaze pipeline stopped by `sleep`. MDM `Dbg_Wakeup` drives `Wakeup[1]`.
- The freestanding supervisor firmware validates mailbox requests, writes one
  hardware descriptor and one doorbell, and executes `sleep` until the engine
  interrupt arrives. Its interrupt handler clears and acknowledges the level
  interrupt; it never polls engine status while acquisition is active.
- Both active-high FPGA RGB LED triplets are driven identically. A blue
  heartbeat appears while the processor has not yet published its firmware
  version, blue is solid while a job is active, green means firmware is alive
  and the engine is idle with a healthy last result, and red means an idle
  engine has a rejected request, failed lane, abort, or timeout to report.
- The isolated Milestone 2.5 target gives only physical GTY quad 124 / FireFly
  5 (global lanes 12 through 15) to a native GT Wizard wrapper. It instantiates
  no IBERT cores and drives no other GT transmitters. The full Milestone 3
  target uses the same managed wrapper while leaving the other 108 lanes under
  IBERT control.
- A quad controller qualifies power-good, QPLL0 lock, TX/RX user-clock active,
  and all reset-done signals. Initialization and intentional post-reset RX
  requalification are bounded. Power, QPLL, or TX loss remains immediately
  fatal; an unexpected RX loss outside the intentional recovery interval also
  latches a fault and holds the GT reset until FPGA reset.
- Each managed lane transfers its complete 256-bit result record through an
  `xpm_cdc_handshake`. The RX-domain payload is held stable until the XPM has
  captured it in the 200-MHz management domain; only then does that lane
  acknowledge the global stop. Start/stop toggles and all status inputs use
  explicit synchronizers.
- Near-end PMA loopback follows the required high-rate GT reset sequence:
  assert `GTRXRESET` with `LOOPBACK=000`, select `LOOPBACK=010`, then pulse
  `RXPMARESET`. Acquisition begins only after all selected receivers report
  PRBS lock. External-loopback jobs skip these PMA-loopback reset operations.
- At stop, the controller reads each selected channel's exact 32-bit native
  `RX_PRBS_ERR_CNT` through DRP addresses `0x25E` and `0x25F`. This replaces
  the earlier approximation that accumulated cycles in which `RXPRBSERR` was
  asserted. The result record keeps the existing 64-bit error-count ABI by
  zero-extending the exact GT counter.
- Hardware enforces the Milestone 3 managed mask (`0x0000F000` in the low
  word), supports native PRBS7/9/15/23/31, loopback modes, masked TX error
  injection, and a descriptor-selectable 1-ms duration/timeout timebase for
  uninterrupted jobs up to about 49.7 days.

The MicroBlaze block design and firmware remain separate from the golden
target. Milestone 2 is synthetic. Milestone 2.5 is the isolated physical smoke
target built by `scripts/build_milestone25_bitstream.tcl` with top
`gt_test_milestone25_top`. Milestone 3 is the full mixed managed-GT/IBERT
target. None changes `src/top.sv`.

## MicroBlaze design choices

The processor is intentionally a small supervisory endpoint rather than part
of the measurement datapath:

| Choice | Configuration and rationale |
|---|---|
| Clock | 200 MHz from the buffered board clock, shared with AXI and the synthetic engine. This avoids a processor/AXI CDC in Milestone 2 and exercises the intended management-clock rate. |
| Local memory | 32 KiB dual-port BRAM through ILMB/DLMB, with no external memory. The freestanding image remains under 1 KiB including BSS, so this leaves ample stack and future logging space without adding DDR infrastructure. |
| Caches/MMU | No instruction cache, data cache, or MMU. Local BRAM has deterministic latency and the supervisor has a tiny working set. |
| Arithmetic | Hardware barrel shifter enabled; multiply remains software. Request parsing uses field extraction, while the control path has no throughput-sensitive multiplication. |
| Control instructions | MSR instructions, interrupt support, and discrete ports enabled. Firmware enables exceptions and uses `sleep` between the doorbell and completion interrupt; the engine interrupt is also wired to `Wakeup[0]` so it releases the sleeping pipeline. |
| Debug | MDM in debug-only mode with the internal JTAG/BSCAN path. This retains breakpoint and halt/resume support needed for the CPU-halt acceptance test. |
| AXI | One 32-bit AXI4-Lite master at 200 MHz. The test engine occupies 4 KiB at `0x44A00000`; no high-bandwidth AXI datapath is needed because results remain in hardware-owned BRAM. |
| Interrupts | The engine's one level-sensitive interrupt drives both MicroBlaze `Interrupt` and `Wakeup[0]` in standard mode; MDM `Dbg_Wakeup` drives `Wakeup[1]`. MicroBlaze wakes, enters through the fixed `0x10` vector, and the engine holds the interrupt until firmware clears it. This removes an unnecessary controller configuration and acknowledge path. |
| Reset | An eight-cycle power-on reset in the top level feeds Processor System Reset, which distributes synchronous peripheral and processor resets. |
| Peripherals | No UART, timer, GPIO, or operating system. The existing I2C mailbox is the command/response transport, the HDL engine owns duration and timeout timing, and MDM provides development visibility. |
| Board status | No AXI GPIO peripheral is used. Coarse engine status is wired directly to both RGB LED triplets; green depends on the firmware-version AXI write, so it proves that MicroBlaze reached `main()` rather than merely that the FPGA configured. |
| Software | A BSP-free, freestanding little-endian ELF matching the generated MicroBlaze configuration, with fixed reset and `0x10` interrupt vectors. Linking disables relaxation so vector addresses cannot move. The build rejects an ELF with the wrong endianness. Firmware validates requests, writes one descriptor and doorbell, uses an interrupt-masked check/sleep sequence so completion cannot be lost at the sleep boundary, and publishes the already-snapshotted summary. |

The firmware build compiles explicitly named assembly and C object files
before linking. This keeps the ELF symbol table reproducible; a one-step GCC
link otherwise records a randomly named temporary object even though its
loadable bytes are identical.

The block design is recreated by `scripts/create_milestone2_project.tcl`; no
generated block-design or IP products are committed.

## AXI4-Lite register map

All registers are 32-bit little-endian words.

| Offset | Access | Meaning |
|---:|---|---|
| `0x000` | R | Hardware ID, `0x47545354` (`GTST`) |
| `0x004` | R | Hardware version: M2 `0x00010002`, current M2.5/M3 `0x00020004` |
| `0x008` | R | Capabilities: lanes, quads, groups, PRBS mask |
| `0x00C` | W | Doorbell: bit 0 start, bit 1 abort, bit 2 clear IRQ/fault |
| `0x010` | R | State, IRQ pending, bad-command, and platform-fault status |
| `0x014` | R | Interrupt status: bit 0 pending, bit 1 bad command |
| `0x018` | R | Published run ID |
| `0x01C` | R | `{failed, passed, selected, stop_reason}` |
| `0x020` | R/W | Descriptor: opcode `[7:0]`, PRBS `[10:8]`, loopback `[13:11]`, 1-ms timebase enable bit 16 |
| `0x024` | R/W | Duration in 200-MHz cycles, or milliseconds when control bit 16 is set |
| `0x028` | R/W | Timeout in the selected timebase; zero disables |
| `0x02C`-`0x038` | R/W | 112-bit lane mask, low word first |
| `0x03C` | R/W | Published-result lane selector, 0 through 111 |
| `0x040`-`0x05C` | R | Selected lane's eight-word record |
| `0x060`-`0x06C` | R/W1T | Per-lane TX PRBS error-injection toggles, low word first; unmanaged bits are ignored |
| `0x070` | R | Platform status: quad state `[2:0]`, ready bit 6, fault bit 7, latched fault reason `[15:8]` |
| `0x074`-`0x080` | R | Hardware managed-lane mask, low word first |

PRBS modes 1 through 5 select PRBS7, PRBS9, PRBS15, PRBS23, and PRBS31.
Opcode 1 starts a parallel BER job. Loopback encodings accepted by firmware
are 0, 1, 2, 4, and 6; mode 2 is near-end PMA loopback. Stop reasons are 1
normal, 2 abort, 3 timeout, and 4 fatal platform/quad fault. A platform fault
publishes explicit failed records in the management domain, so completion
does not depend on an RX user clock that may have stopped. Its reason field
uses bit 0 power, bit 1 QPLL, bit 2 TX user-clock active, bit 3 TX reset-done,
bit 4 RX user-clock active, bit 5 RX reset-done, and bit 6 qualification
timeout. Bit 7 identifies a wrapper/PRBS-controller fault. Duration zero, an
invalid PRBS mode, a missing platform-ready indication, or any lane bit
outside the managed mask is rejected without consuming a run ID.

Each lane record is:

| Word | Meaning |
|---:|---|
| 0 | Lane ID `[7:0]`; selected bit 11; locked bit 12; lock-loss bit 13; error saturation bit 14; bit-count saturation bit 15 |
| 1-2 | 64-bit PRBS error count, low word first |
| 3-4 | 64-bit tested-bit count, low word first |
| 5 | Lock-loss event count |
| 6-7 | 64-bit valid RX-user-clock cycle count, low word first |

At the 80-bit datapath width, each locked RX user-clock cycle contributes 80
tested bits. No x2 monitor scaling is applied.

## I2C mailbox

The shell reserves `0x00`-`0x9F` for the deployed clock-monitor ABI and never
reassigns those addresses. In this standalone synthetic top they read as zero;
the golden image remains the operational clock-monitor/IBERT image. A future
combined managed-GT top must reconnect the existing monitor values without
changing their addresses. The mailbox uses the remaining byte addresses:

| Bytes | Owner | Meaning |
|---:|---|---|
| `0xA0`-`0xBC` | MCU | Request sequence, command, duration, timeout, lane mask |
| `0xC0` | CPU | Firmware version |
| `0xC4`-`0xC8` | Hardware | Hardware version and engine state |
| `0xCC` | MCU/CPU | Published-result lane selector |
| `0xD0`-`0xEC` | Hardware | Selected immutable lane record |
| `0xF0`-`0xF4` | CPU | Response sequence and response code |
| `0xF8`-`0xFC` | Hardware | Published run ID and aggregate summary |

The MCU indicates a new command by changing the request sequence. Firmware
copies validated request fields into the descriptor registers and writes one
start doorbell. It then waits for the interrupt, reads the summary, and updates
the response fields. Acquisition requires no status polling.

External board-MCU firmware can copy or include `mcu/gt_test_mcu_protocol.h`
for byte-exact wire
structures covering the request window, status window, and eight-word lane
record. The header does not assume the MCU is little-endian or permit unaligned
integer loads: I2C buffers remain arrays of bytes and explicit helpers decode
them into native request, engine-state, summary, and per-lane result structures.
It also provides the hardware-equivalent lane-pass predicate and the stricter
Milestone 3 acceptance predicate, which rejects either counter saturation. It
is not linked into or required by the MicroBlaze supervisor and has no Xilinx
or MCU-vendor HAL dependency.

For the TM4C1290NCPDT Apollo firmware, `mcu/cm_mcu/GTTestEngine.c` binds that
protocol to the existing FreeRTOS-aware `apollo_i2c_ctl_*()` layer. It follows
`clk_freq_fpga_cmd()` by holding `i2c5_sem`, selecting mux `0x70` channel 2
for F1 or channel 0 for F2, retaining ownership for the complete operation,
then clearing the mux before releasing the semaphore.

Write request bytes `0xA4`-`0xBF` before writing the sequence at `0xA0`. To
collect results, write the desired lane number at `0xCC`, then read its record
from `0xD0`-`0xEC`. Read `run_id` before and after collecting all lane records;
if it changes, discard the mixed set and read the newly published immutable
bank again. This guards against a job completing while the MCU is partway
through a multi-transaction result collection.

## Validation

Run the self-checking simulation:

```sh
vivado -mode batch -source scripts/run_gt_test_engine_sim.tcl
```

It covers an all-112-lane job with the AXI master inactive after launch,
simultaneous snapshot completion, immutable bank reads during the next job,
lane-local error injection, lock loss, abort, timeout, bad-command rejection,
one interrupt, and monotonically increasing run IDs. A second test uses the
Milestone 3 mask and four XPM payload handshakes to check unmanaged-lane
rejection, masked injection, and a complete one-millisecond job.

Synthesize the AXI engine out of context:

```sh
vivado -mode batch -source scripts/synthesize_gt_test_engine.tcl
```

Build the generated MicroBlaze subsystem and embedded supervisor image:

```sh
scripts/build_milestone2_firmware.sh
vivado -mode batch -source scripts/create_milestone2_project.tcl
vivado -mode batch -source scripts/build_milestone2_bitstream.tcl
```

The Milestone 2 project is generated under `build/gt_test_milestone2`; it uses
`src/gt_test_milestone2_top.sv` and does not modify `src/top.sv` or the golden
IBERT project. Its target-specific XDC explicitly enables
`BITSTREAM.GENERAL.COMPRESS`, and the build checks the implemented property
before accepting the output. The full build emits routed timing, route status,
DRC, CDC, clock-utilization, and bus-skew reports under
`build/gt_test_milestone2_reports`.

The RTL testbench proves that the hardware job completes with its AXI master
inactive after the doorbell, which is the hardware-independent equivalent of
halting the CPU after launch. Loading this image on a board, submitting a job
over I2C, halting MicroBlaze in MDM, and observing the interrupt/result after
resume remains required hardware acceptance before migrating quad 124.

### Board smoke test

Program only the final `gt_test_milestone2_top.bit` produced by the clean
build. During configuration/reset, neither green nor red is meaningful; after
reset, blue blinks at about 1.5 Hz until MicroBlaze writes its firmware version.
The LED should then settle to solid green. This transition is a direct visual
check that the embedded C supervisor executed an AXI transaction. At I2C
address `0x2B`, confirm little-endian firmware and hardware versions at `0xC0`
and `0xC4` are both `0x00010002`. If `0xC4` is correct but `0xC0` remains
zero, the HDL is alive but the supervisor has not executed its firmware-alive
write. That exact signature exposed a superseded big-endian firmware image;
do not use bitstream SHA-256
`44ceb1cb5d1592305ad70f265e69a2776bc97a3ace02efee641a12ecee2c9197`.
The first little-endian replacement, SHA-256
`e76121b45c71763efed0bc1265b00650a92a73cc4d21cdea81219a53eb3b9607`,
passed startup but exposed the interrupt-mode mismatch described below. The
version `0x00010001` replacement removes the AXI interrupt controller and
connects the sole engine interrupt directly to MicroBlaze. Its SHA-256 is
`ab18d669a96b15a0ce4e465b603f3b7721c8ce10a53d3aa5d1c36d7032a4871c`;
it is also superseded because the interrupt was not connected to the separate
MicroBlaze `Wakeup` input. Version `0x00010002` adds that connection. Its clean,
compressed bitstream is 32,079,859 bytes with SHA-256
`41e559b11fe2e058dc61addef32da321d24c4bb0d95d657bddaedf0d211f6f6a`.
Write request fields before changing the request sequence:

| Byte address | Little-endian value | Meaning |
|---:|---:|---|
| `0xA4` | `0x00000501` | Parallel BER, PRBS31 |
| `0xA8` | `0x01312D00` | 20,000,000 management cycles, 100 ms |
| `0xAC` | `0x02625A00` | 40,000,000-cycle timeout |
| `0xB0`, `0xB4`, `0xB8` | `0xFFFFFFFF` | Lanes 0 through 95 selected |
| `0xBC` | `0x0000FFFF` | Lanes 96 through 111 selected |
| `0xA0` | a new sequence number | Commit the complete request last |

Using the board console syntax shown above, this copy/paste sequence starts a
five-second PRBS31 synthetic job on all 112 lanes. The longer duration makes
the solid-blue busy indication easy to see. `i2cwr` arguments are I2C bus,
7-bit slave address, register-address width, byte address, data width, and
little-endian value. Write `0xA0` last; changing that sequence number is the
firmware doorbell. These blocks also respect the six-line CLI copy/paste
limit. The example selects F1 (`0x04`); use `0x01` for F2, retain the I2C5
semaphore across every block, and wait for each block's output.

```text
semaphore 5 take
i2cw  5 70 1 0x04
i2cwr 5 2b 1 a4 4 0x00000501
i2cwr 5 2b 1 a8 4 0x3b9aca00
i2cwr 5 2b 1 ac 4 0x77359400
i2cwr 5 2b 1 b0 4 0xffffffff
```

```text
i2cwr 5 2b 1 b4 4 0xffffffff
i2cwr 5 2b 1 b8 4 0xffffffff
i2cwr 5 2b 1 bc 4 0x0000ffff
i2crr 5 2b 1 b0 4
i2crr 5 2b 1 b4 4
i2crr 5 2b 1 b8 4
```

```text
i2crr 5 2b 1 bc 4
i2cwr 5 2b 1 a0 4 0x00000001
```

Here `0x3B9ACA00` is 1,000,000,000 cycles, or five seconds at 200 MHz;
`0x77359400` is a ten-second timeout. For every later job, keep all descriptor
writes ahead of `0xA0` and use a request sequence different from the previous
one, for example `0x00000002`.

Verify those four mask readbacks are `0xFFFFFFFF`, `0xFFFFFFFF`,
`0xFFFFFFFF`, and `0x0000FFFF` before writing `0xA0`. A board test that read
`B4=0x0000000F` correctly selected and reported 84 lanes: 32 + 4 + 32 + 16.
Changing the mask after launch cannot change that run's atomic result.

The response sequence at `0xF0` must eventually match the request sequence.
For this all-locked, zero-error synthetic top, `0xF4` and `0xFC` should read
`0x00707001` (`failed=0`, `passed=112`, `selected=112`, normal stop), and the
run ID at `0xF8` should increment once. Blue must be solid during acquisition
and green must return after successful publication. A rejected command, abort,
timeout, or failed lane produces red while idle. Starting a retry suppresses
the prior red indication and shows solid blue until the new result publishes.

After green returns, read the result with:

```text
i2crr 5 2b 1 f0 4
i2crr 5 2b 1 f4 4
i2crr 5 2b 1 f8 4
i2crr 5 2b 1 fc 4
i2cw  5 70 1 0x00
semaphore 5 release
```

The final two commands clear the mux and release the semaphore. Run them even
after any earlier error.

For the first job after configuration, the expected values are request
sequence `0x00000001`, summary/response `0x00707001`, run ID `0x00000001`, and
summary `0x00707001`, respectively.

The first interrupt-path board attempt completed and published the hardware
result (`0xF8=0x00000001`, `0xFC=0x00707001`) but left the CPU-owned response
at zero, and `0xC8=0x00004000` confirmed the interrupt remained pending. The
generated design had selected low-latency vectored interrupts while the
freestanding startup used the standard fixed `0x10` vector. A subsequent
standard-mode AXI-controller image still showed the pending-interrupt
signature. Version `0x00010001` removed that controller and drove
MicroBlaze's standard interrupt input directly. Its board readings of
`0xC0=0xC4=0x00010001` proved that the correct firmware ran, but the same
pending-interrupt signature remained. The final cause was MicroBlaze `sleep`:
it halts the pipeline until a discrete `Wakeup` bit is asserted, and
`Interrupt` alone is not that signal. Version `0x00010002` enables the
discrete ports, connects the engine level to both `Interrupt` and `Wakeup[0]`,
and retains MDM access on `Wakeup[1]`. Its clean build and board rerun passed
on 2026-08-25: `0xF0=0x00000001`, `0xF4=0x00707001`,
`0xF8=0x00000001`, `0xFC=0x00707001`, and final engine state
`0xC8=0x00000000`. The matching CPU response and hardware summary, plus the
cleared interrupt and fault-free idle state, close the interrupt/wakeup smoke
test for all 112 synthetic lanes.

The F1 triplet is blue/green/red on `A30`/`A29`/`A28`; the F2 triplet is on
`BL27`/`BL28`/`BL30`. Both are active-high and show the same state so the
single binary is useful at either VU13P site.

The corrected little-endian supervisor passed this startup check on hardware
on 2026-08-25: `0xC0` and `0xC4` both returned `0x00010000`, and the LED
settled to green. The blue heartbeat can be too brief to see because the first
firmware action publishes `0xC0`; it is a failure indicator only if blue
continues instead of transitioning to green.

The CPU-independence check passed on hardware on 2026-08-25. With MicroBlaze
halted after launching request sequence 2, `0xF0` stayed at sequence 1 while
the hardware run ID advanced to `0xF8=0x00000002`, the atomic summary became
`0xFC=0x00707001`, and `0xC8=0x00004000` held the pending completion
interrupt. After XSDB `con`, firmware published `0xF0=0x00000002` and
`0xF4=0x00707001`; the hardware result remained unchanged and `0xC8` cleared
to zero. The test therefore proves that acquisition and publication complete
without CPU execution after launch, and that resume services the retained
level interrupt without restarting the job.

## Milestone 2.5 smoke and Milestone 3 validation plan

Milestone 2.5 enables only FireFly 5, global lanes 12 through 15, in GTY quad
124; the other GT transmitters and all IBERT cores are absent. Milestone 3
uses the same native-GT engine for quad 124 while the other 108 lanes remain
owned by standalone IBERT. Both managed images must enforce ownership in
hardware: the only valid
lane-mask words are `B0=0x0000F000`, `B4=0`, `B8=0`, and `BC=0`. A request
containing any other lane bit must be rejected without starting a test or
changing the published run ID.

For the present campaign, treat the board, FireFly modules, fibers, reference
clocks, and power hardware as already extensively validated. The immediate
smoke test therefore validates the new FPGA image and its control/result path;
it is not a requalification of the physical platform. External-path testing,
fault campaigns, repeated initialization, and long soaks remain useful later
image-qualification evidence, but they do not block a comment-only HDL pass
after the full Milestone 3 smoke gate succeeds.

### Long-soak duration support

Descriptor control bit 16 makes duration and timeout count a
hardware-generated 1-ms tick. This preserves the 32-bit mailbox fields,
allows one uninterrupted job of about 49.7 days, and keeps PRBS accumulation,
lock tracking, stop, snapshot, and publication entirely in HDL. With bit 16
clear, the fields retain their original 200-MHz cycle units for short tests
and backward compatibility (about 21.47 seconds maximum).

### CLI-first operating policy

Use the existing `cm_mcu` CLI for board tests for as long as practical; updating
the board-MCU firmware is not a prerequisite for the smoke test or the initial
qualification work. The raw `i2crr`, `i2cwr`, and `i2cw` commands deliberately
do not acquire a bus semaphore themselves. Wrap the entire multi-command FPGA
transaction sequence with `semaphore 5 take` and `semaphore 5 release`.

While holding that semaphore, select mux `0x70` channel 2 (`0x04`) for F1 or
channel 0 (`0x01`) for F2, perform every access to FPGA slave `0x2B`, then
write zero to mux `0x70` before releasing the semaphore. Do not release the
semaphore between descriptor writes, readback, the `0xA0` commit, and the
associated result reads. If a command fails or the procedure is abandoned,
still clear the mux and release the semaphore.

Dedicated board-MCU support is deferred until CLI operation becomes too
cumbersome for unattended runs or structured logging. Such firmware may
sequence jobs and collect telemetry, but it must not own PRBS timing, poll
acquisition counters, conceal a failed interval with an automatic retry, or
weaken the one-descriptor/one-doorbell/one-completion-interrupt contract.
MicroBlaze remains the validating supervisor.

### Qualification setup and records

For the deferred qualification campaign, retain the following records. These
are not all prerequisites for the reduced smoke gate:

- Preserve the compressed golden IBERT bitstream as the recovery image and
  record SHA-256 hashes for the milestone-3 bitstream and embedded ELF.
- Review the clean-build IP, DRC, timing, CDC, route-status, bus-skew, clock,
  utilization, power, and GT-placement reports. Quad 124 must occupy
  `GTYE4_CHANNEL_X0Y16` through `X0Y19` and use 322.265625-MHz
  `lf_r0_af`/`MGTREFCLK0_124`.
- Record board/site identity, FireFly/module identity, optical loop or link
  partner, supply readings, ambient and SysMon temperature, firmware/hardware
  versions, PRBS mode, loopback mode, lane mask, start/end time, run IDs, and
  every lane record. Sample environmental telemetry out of band; do not poll
  acquisition counters.
- Confirm the 108 non-migrated lanes are visible in IBERT before the campaign.
  Capture their link state before and after the soak to detect collateral
  effects from the quad-124 migration.

### Immediate FPGA-image smoke gate

The following short gate is sufficient before beginning the planned
comment-only SystemVerilog pass:

1. Preserve the compressed golden image and verify the candidate bitstream
   hash.
2. Program the intended FPGA and, through the semaphore/mux procedure above,
   confirm firmware `0xC0=0x00020004`, hardware `0xC4=0x00020004`, healthy
   idle `0xC8=0`, and the green status LED.
3. Run one one-second, all-four-lane PRBS31 job in near-end PMA loopback. Read
   back command, duration, timeout, and all four mask words before committing
   a new request sequence at `0xA0`.
4. Require aggregate summary `0x00040401`, a response sequence matching the
   request, exactly one run-ID increment, correct records for global lanes
   12-15, zero errors, zero lock losses, no saturation, and final state
   `0xC8=0` after MicroBlaze services completion.
5. Check basic temperature and power sanity after programming. For the
   isolated Milestone 2.5 image, confirm no GT transmitter other than FireFly
   5 is active. In the full Milestone 3 image, confirm that the 108 remaining
   lanes enumerate under the reduced left and full right IBERT cores.

The smoke gate does not require a local fiber loopback or remote PRBS partner.
An external PRBS31 run validates the new image's FireFly lane mapping,
polarity, and external routing, but under the known-good-hardware assumption it
may be performed during later image qualification.

### Deferred qualification campaign

The full Milestone 3 candidate built on 2026-08-27. It consists of 52 lanes in
the reduced left IBERT, four native-managed quad-124 lanes, and 56 lanes in the
right IBERT, for 112 exclusive GT channel owners. The compressed bitstream is
`build/gt_test_milestone3/gt_test_milestone3.runs/impl_1/gt_test_milestone3_top.bit`,
71,214,671 bytes, SHA-256
`2adde4672dc227ad62c90f46b0c3b3e4013c1fb768eea7fb05f1260305582f5a`.
Its authoritative routed results are WNS `+0.138 ns`, WHS `+0.008 ns`, zero
timing failures, zero routing errors, all four bus-skew constraints met, and
the expected 100.000-MHz and 325.000-MHz monitored clocks. Hardware acceptance
passed the immediate FPGA-image smoke gate on 2026-08-27: the managed run
returned matching sequence/run ID 1, aggregate `0x00040401`, and final `C8=0`;
lane 12 independently showed zero errors and lock losses over about 25.78
billion bits, while the other 108 IBERT-owned channels operated as before.
Long soaks and fault injection remain later qualification work.

The deferred comment-only HDL pass was completed after this smoke result. It
documents lane ownership, mailbox commit semantics, CDC handshakes, atomic
publication, PMA reset/DRP capture, and fixed clock-monitor ordering in the
handwritten SystemVerilog. The synthetic engine tests, Milestone 3 mask/timebase
test, quad-controller test, and PRBS-controller test all passed afterward; a
separate `xvlog` parse also accepted every touched module.

| Stage | Test | Required result |
|---|---|---|
| 1. Initialization | Perform 20 FPGA resets or reconfigurations with the reference clock and FireFly present. Record QPLL lock, TX/RX reset-done, PRBS lock acquisition, and initialization time for every lane. | All four lanes initialize every time; no reset timeout, QPLL fault, or unexplained large variation in lock time. |
| 2. Internal loopback | Test each lane alone, then all four together, using near-end GT loopback. Run PRBS7/9/15/23 for at least 60 seconds each and PRBS31 for 10 minutes. | Normal stop, summary `0x00040401` for the four-lane runs, zero errors, zero lock losses, and no saturation. |
| 3. External path | Run PRBS31 through the intended optical/electrical path for 15 minutes, first per lane and then on all four concurrently. | All selected lanes remain locked with zero unexpected errors. Tested-bit counts agree with valid RX-clock time and line rate. |
| 4. Isolation and faults | Inject an error into one lane at a time; disable only that lane's link-partner TX to force lock loss; exercise explicit abort and a timeout shorter than duration. Avoid physically disturbing a powered module when the link partner can create the fault safely. | Only the targeted lane reports the injected error or lock loss. Abort and timeout publish atomic partial records with stop reasons 2 and 3. No adjacent lane or IBERT lane is corrupted. |
| 5. CPU independence | Start a multi-minute four-lane job, halt MicroBlaze after the doorbell, and leave it halted past hardware completion. | HDL stops and publishes, run ID advances once, results remain immutable, and the level interrupt remains pending. After resume, firmware acknowledges the same completed run without restarting it. |
| 6. One-hour burn-in | Run one uninterrupted external PRBS31 job on all four lanes for one hour. | Zero unexpected errors and lock losses; no counter saturation, timeout, QPLL/reset fault, or result-bank inconsistency. |
| 7. Overnight soak | Run one uninterrupted external PRBS31 job for at least 12 hours. Repeat at the normal operating thermal/load condition; add cold/hot operating points when board controls permit safe operation. | Same criteria as the one-hour run. Temperature and supplies remain within board limits, and all 108 IBERT-owned lanes retain their expected post-test state. |
| 8. Extended qualification | After the overnight run passes, perform a 24-hour run; use 72 hours when qualifying a board/module combination for deployment. | No unexplained error, lock loss, reset, QPLL, firmware, or publication failure. Any failure preserves the complete failing record and environment log. |

For zero observed errors at 25.78125 Gb/s, one lane tests approximately
`9.28125e13` bits in one hour, `1.11375e15` bits in 12 hours, and
`2.2275e15` bits in 24 hours. The approximate one-sided 95% upper BER bound
is `3/tested_bits`: about `3.2e-14`, `2.7e-15`, and `1.35e-15` per lane for
those durations. Report bounds per lane; do not combine lanes to hide a weak
channel.

### Acceptance and failure handling

A normal four-lane run must publish aggregate summary `0x00040401`: zero
failed, four passed, four selected, normal stop. Each selected lane must show
the correct lane ID, selected and locked flags, zero unexpected errors, zero
lock losses, monotonically plausible tested-bit/valid-time values, and no
saturation. The response sequence must match the request sequence, the run ID
must increment exactly once, and the final interrupt/state must clear only
after MicroBlaze handles it.

Do not average away intermittent failures. On the first unexpected error,
lock loss, timeout, reset/QPLL fault, version mismatch, or result inconsistency:

1. Stop automatic retries and preserve the published lane records and run ID.
2. Capture temperature, supply, reference-clock, module, and link-partner
   state without reconfiguring the FPGA.
3. Repeat a short diagnostic run on the affected lane, then its adjacent lanes.
4. Compare against the compressed golden IBERT image when safe. A failure is
   not closed until it is reproduced or assigned to a documented external
   cause.

Continue using the existing CLI for operator-driven qualification. If later
soaks justify dedicated MCU campaign firmware, it should use unique
monotonically increasing request sequences, verify every response/run ID, read
and store all four lane records, timestamp environmental samples, and stop on
the first discrepancy. It should expose an explicit operator-selected policy
for stage, duration, loopback, PRBS mode, and retry count rather than silently
retrying.

The generated reports and checkpoint are under `build/` and must not be
committed. This check does not replace implementation, timing, CDC, DRC, GT
placement, and clock review for each future managed-GT target.

### Milestone 2.5 build and first board commands

The first board run of the superseded `0x00020001` image terminated with
aggregate `0x04000404` and `C8=0x00010000`. Lane 12 contained the deterministic
platform-failure record `D0=0x0000280c`, zero measurement fields, and `E4=1`;
the latter is synthesized for an aborted selected lane and is not a measured
lock-loss count. Candidate `0x00020002` extended the PRBS controller's reset
qualifier through PMA reset and lock reacquisition, but failed identically.
An XSDB read of AXI platform status `0x44A00070` returned `0x00000085`: state 5
and fault bit 7 prove that the quad supervisor, rather than the PRBS timeout
logic, entered its fatal state.

The remaining race was between separately synchronized status inputs:
`rx_prbs_locked` could reach the PRBS controller before `rx_userclk_active` or
`rxresetdone` reached the quad supervisor. Release `0x00020003` added a bounded
quad-supervisor RX requalification state for an intentional runtime RX reset.
It preserves `quad_ready` while the RX qualifiers settle, but still faults
immediately for power, QPLL, TX, or unexpected RX loss. The regression delays
the synchronized RX-ready indications, verifies state 6 without a fault, then
checks recovery to READY and exact fatal-cause latching. Do not reuse either
superseded bitstream: `0x00020001` SHA-256
`85cefe9aad58bf3040444ebabc91ce36e0073dcf7b2a634bbbcdb33de772553e`, or
`0x00020002` SHA-256
`ff79a4e01be52dafb77eb93966433ac56c788ac4a8a8349c58e1084e64bffca0`.

Build the supervisor and the compressed isolated managed-quad image with:

```sh
scripts/build_milestone3_firmware.sh
vivado -mode batch -source scripts/build_milestone25_bitstream.tcl
```

On the board, use the existing CLI and manually retain the I2C5 semaphore for
the entire operation. The example below selects F1 with mux value `0x04`; use
`0x01` instead for F2. The current `0x00020004` image uses the same corrected
supervisor behavior and a uniquely bumped build identity. Confirm firmware
`0xC0=0x00020004`, hardware `0xC4=0x00020004`, and `0xC8=0` at healthy idle
before launching a one-second
near-end PMA-loopback PRBS31 job. The only valid four-lane mask is the low word
`0x0000F000`; the other three words must be zero. The CLI copy/paste buffer is
assumed to accept at most six lines, so submit each block below separately and
wait for its output before submitting the next block. The semaphore remains
held across all block boundaries.

```text
semaphore 5 take
i2cw  5 70 1 0x04
i2crr 5 2b 1 c0 4
i2crr 5 2b 1 c4 4
i2crr 5 2b 1 c8 4
i2cwr 5 2b 1 a4 4 0x00011501
```

```text
i2cwr 5 2b 1 a8 4 0x000003e8
i2cwr 5 2b 1 ac 4 0x000007d0
i2cwr 5 2b 1 b0 4 0x0000f000
i2cwr 5 2b 1 b4 4 0x00000000
i2cwr 5 2b 1 b8 4 0x00000000
i2cwr 5 2b 1 bc 4 0x00000000
```

```text
i2crr 5 2b 1 a4 4
i2crr 5 2b 1 a8 4
i2crr 5 2b 1 ac 4
i2crr 5 2b 1 b0 4
i2crr 5 2b 1 b4 4
i2crr 5 2b 1 b8 4
```

```text
i2crr 5 2b 1 bc 4
i2cwr 5 2b 1 a0 4 0x00000001
```

Wait at least one second for this job, then read completion:

```text
i2crr 5 2b 1 f0 4
i2crr 5 2b 1 f4 4
i2crr 5 2b 1 f8 4
i2crr 5 2b 1 fc 4
i2crr 5 2b 1 c8 4
```

For each selector `0x0c`, `0x0d`, `0x0e`, and `0x0f`, submit the following
two blocks after changing the selector value in the first line. Together
they read that lane's complete eight-word record:

```text
i2cwr 5 2b 1 cc 1 0x0c
i2crr 5 2b 1 d0 4
i2crr 5 2b 1 d4 4
i2crr 5 2b 1 d8 4
i2crr 5 2b 1 dc 4
i2crr 5 2b 1 e0 4
```

```text
i2crr 5 2b 1 e4 4
i2crr 5 2b 1 e8 4
i2crr 5 2b 1 ec 4
```

After all four lane records are captured, always clean up:

```text
i2cw  5 70 1 0x00
semaphore 5 release
```

Confirm every descriptor readback before writing `0xA0`; that write is the
commit and must remain last. Wait for completion before interpreting `0xF0`
through `0xFC`. A healthy four-lane completion returns aggregate
`0x00040401`, the response sequence matches the request, the run ID advances
once, and final `0xC8` returns to zero. Select each lane at `0xCC` and read
`0xD0`-`0xEC` before clearing the mux to verify the four published lane
records. Always issue the final mux-clear and semaphore-release commands,
including after an earlier CLI error.

The later external-path equivalent uses command `0x00010501` and requires a
known local fiber loopback or a configured remote PRBS partner. It is not part
of the reduced smoke gate. Program only the reviewed compressed output at
`build/gt_test_milestone25/gt_test_milestone25.runs/impl_1/gt_test_milestone25_top.bit`.
The final 2026-08-26 `0x00020004` clean build is 33,383,572 bytes with SHA-256
`49c8a71111d00bb30bd65892e09dc26995d79d7186702b724d7eeab3896e7d8a`.
It meets timing with WNS `+0.434 ns`, TNS `0`, WHS `+0.010 ns`, and THS `0`;
route status has zero routing errors. The only routed DRC finding is the
existing warning for incomplete buffering on generic-I2C SCL.
Retain the compressed golden IBERT image as the immediate recovery image.
The isolated managed image passed both external optical-loopback and near-end
PMA-loopback four-lane PRBS31 smoke tests with aggregate `0x00040401`, zero
errors and lock losses, and final `C8=0`. Proceed to the full Milestone 3
integration smoke test; defer the comment-only HDL pass until that test passes.

For the targeted-error stage, the injection mechanism is intentionally an AXI
debug control rather than an MCU policy command. In XSDB select the exact CPU
target (for example `targets -set -filter {name =~ "MicroBlaze #0"}`), then
`mwr 0x44a00060 0x00001000` toggles one error request for global lane 12;
bits 13, 14, and 15 select the other managed lanes. Writes to any of the other
108 lane bits are masked out in hardware. Read all four lane records after
completion and verify that only the selected lane has a nonzero error count.
