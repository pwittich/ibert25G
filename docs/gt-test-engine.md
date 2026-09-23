# HDL-first GT test engine

Current development status (2026-09-14): full v13 (`0x0002000D`) produced two
independently programmed fresh external failures before `RUN`, both preserved
as `0x04000404` platform faults. A routed comparison with isolated v275 found
the same managed-quad configuration, placement, golden RX properties, and no
managed-to-full-IBERT net. Full v14 (`0x0002000E`) is therefore the current
one-variable diagnostic: it disables only v13's planned external-startup
full-quad restart. Matching firmware, compressed implementation, and
independent routed audit pass at WNS/WHS `+0.222/+0.009 ns`, with zero routing
or DRC errors, all bus-skew constraints met, and descriptor/profile/runtime
structure verified. After a power cycle, F1 was programmed once through XVC
`TCP:apollo3010-1:2542` and two unique 60-second external sequences/run IDs 1
and 2 passed (`0x00040401`): each managed lane recorded 1,546,848,197,680 and
1,546,848,072,800 tested bits, respectively, with zero errors and zero native
lock losses. This supports the narrow startup-restart hypothesis but is
diagnostic, not qualification.
See [the v14 diagnostic record](v14-no-startup-restart-diagnostic.md).

The descriptor-skew hardware record, its source repair, and isolated v270
evidence remain historical references. Architecture descriptions below are not
qualification claims; full-M3, isolated diagnostics, and qualification
candidates remain separate.

Recovery plan items 1–4 are documented in
[recovery-items1-4.md](recovery-items1-4.md), including the separate lane protocol
reset, integrated regression matrix, diagnostic artifact archive and selector
0xFD retained restart records. Existing 0xFE diagnostics keep their layout.

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
  `RXPMARESET`. External-path jobs retain `LOOPBACK=000` and keep the already
  live RX datapath out of reset. In both modes, a management-domain qualifier
  suppresses expected transient RX-status faults from the engine ARM interval
  until all selected receivers report PRBS lock. Acquisition then clears the
  selected native error counters before starting the timed measurement.
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
| `0x004` | R | Hardware version: M2 `0x00010002`, validated M2.5 `0x00020004`, current full-M3 candidate `0x0002000C` |
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
| `0x03C` | R/W | Published-result selector: lane 0 through 111, or diagnostic page `0xFE` |
| `0x040`-`0x05C` | R | Selected lane's eight-word record |
| `0x060`-`0x06C` | R/W1T | Per-lane TX PRBS error-injection toggles, low word first; unmanaged bits are ignored |
| `0x070` | R | Platform status: quad state `[2:0]`, ready bit 6, fault bit 7, latched fault reason `[15:8]` |
| `0x074`-`0x080` | R | Hardware managed-lane mask, low word first |
| `0x084` | R | Live PRBS sequencer, selected/running/locked/ever-locked/lost-lock masks and control flags |
| `0x088` | R | Live RX reset, PMA reset, capture, DRP, and loopback qualifiers |
| `0x08C` | R | Live quad power, QPLL, user-clock, reset-done, state, ready, and fault qualifiers |
| `0x090`-`0x098` | R | First-fault snapshots of the preceding three diagnostic words |
| `0x09C` | R | First-fault-valid bit 31 and captured sequencer-cycle count `[30:0]` |

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
| `0xCC` | MCU/CPU | Published-result lane selector, or platform-diagnostic selector `0xFE` |
| `0xD0`-`0xEC` | Hardware | Selected immutable lane record; for selector `0xFE`, platform status followed by the seven `0x084`-`0x09C` diagnostics |
| `0xF0`-`0xF4` | CPU | Response sequence and response code |
| `0xF8`-`0xFC` | Hardware | Published run ID and aggregate summary |

The MCU indicates a new command by changing the request sequence. Firmware
copies validated request fields into the descriptor registers and writes one
start doorbell. It then waits for the interrupt, reads the summary, and updates
the response fields. Acquisition requires no status polling.

Write request bytes `0xA4`-`0xBF` before writing the sequence at `0xA0`. To
collect results, write the desired lane number at `0xCC`, then read its record
from `0xD0`-`0xEC`. Read `run_id` before and after collecting all lane records;
if it changes, discard the mixed set and read the newly published immutable
bank again. This guards against a job completing while the MCU is partway
through a multi-transaction result collection.

The former repository-local external-MCU protocol header and `cm_mcu` adapter
were retired on 2026-09-23. They were an unintegrated Milestone-3 draft limited
to lanes 12--15 and are not part of the current all-links or host-side test
path. The wire ABI above remains authoritative; current board access uses the
pinned `cm_interface` checkout described in the repository README.

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
Write values in copy/paste commands omit redundant leading zeroes; the CLI
parses the value and `i2cwr` supplies the requested data width.

```text
semaphore 5 take
i2cw  5 70 1 0x4
i2cwr 5 2b 1 a4 4 0x501
i2cwr 5 2b 1 a8 4 0x3b9aca00
i2cwr 5 2b 1 ac 4 0x77359400
i2cwr 5 2b 1 b0 4 0xffffffff
```

```text
i2cwr 5 2b 1 b4 4 0xffffffff
i2cwr 5 2b 1 b8 4 0xffffffff
i2cwr 5 2b 1 bc 4 0xffff
i2crr 5 2b 1 b0 4
i2crr 5 2b 1 b4 4
i2crr 5 2b 1 b8 4
```

```text
i2crr 5 2b 1 bc 4
i2cwr 5 2b 1 a0 4 0x1
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
i2cw  5 70 1 0x0
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

### FPGA-image smoke gate

The current gate target is full Milestone 3 candidate `0x0002000C` (v12).
Its clean implementation and independent routed audit passed on 2026-09-11:
WNS `+0.141 ns`, WHS `+0.009 ns`, zero routing errors, worst bus-skew slack
`+19.437 ns`, exact 112-channel ownership, correct 100.000/325.000-MHz clocks,
and four routed native-CDR-lock synchronizer pairs. Program the versioned
compressed artifact
`build/gt_test_milestone3/gt_test_milestone3.runs/impl_1/gt_test_milestone3_v12.bit`
(SHA-256
`35e8ba4ec565c9972e72e3ebf61ee842fd446d2b51d35650f1d9ec2b76ca180f`).

V12 preserves acquisition on `RXPRBSLOCKED`. During measurement, a lane is
valid only while both `RXPRBSLOCKED` and native `RXCDRLOCK` are asserted; a
falling qualified-lock edge increments the existing lock-loss count. This
does not change the MCU register or result-record ABI. One PMA smoke and its
following 60-second external smoke passed on F1, but other fresh/restart
attempts failed in `LOCK_WAIT`, including a post-reload PMA attempt. Those
failures were preserved. After a later explicit reload, PMA and external gates
passed again and the intended FireFly channel-0 stimulus ran. The module
reported RX0/TX0 LOS and RX0 CDR LOL, while the FPGA recorded isolated lane-12
error saturation but no `RXCDRLOCK` transition, no excluded cycles, and zero
lock losses. V12 is therefore not hardware-qualified.

After the short gate passes, `scripts/run_milestone3_12hour_soak.sh` runs the
12-hour external soak end to end, mirrors output to the screen and a timestamped
log, checks status every 30 minutes, and collects final results. Its defaults
are request sequence 4 and previous sequence 3; optional positional arguments
override the request sequence, previous sequence, and log path respectively.

The v11 F1 run completed successfully at `2026-09-03T06:24:05+00:00`.
Lanes 12-15 each reported zero errors, zero lock losses,
1,113,730,526,168,800 tested bits, 13,921,631,577,110 valid cycles, and
`BER95 < 2.694e-15`. The full log is
`docs/evidence/legacy/milestone3_12hour_soak_20260902_182351.log`. Its final mailbox has
matching request/response sequence `4`, response/summary `0x00040401`, stable
hardware run ID `3`, and healthy IDLE. Append the final F1 AVTT current and
FPGA temperature when those readings are available.

Apply the following short gate to every new full-Milestone-3 candidate before
long tests or fault campaigns. The earlier comment-only SystemVerilog pass was
already completed after the `0x00020004` integration smoke.

1. Preserve the compressed golden image and verify the candidate bitstream
   hash.
2. Program the intended FPGA and, through the semaphore/mux procedure above,
   confirm firmware `0xC0=0x0002000C`, hardware `0xC4=0x0002000C`, healthy
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

The first 12-hour external-path launch attempted on 2026-08-31 did not enter
`ST_RUN`. Request sequence 7 completed immediately with platform-fault summary
`0x04000404`, final mailbox state `C8=0x00010000`, hardware run ID 2, and XSDB
platform status `0xE1208085`. A subsequent 60-second external smoke after FPGA
reconfiguration failed the same way. Unlike the already passing PMA-loopback
path, external mode had changed PRBS controls and proceeded directly to
counter reset/lock qualification without resetting the RX datapath.

Full-M3 candidate `0x00020005` therefore gave both external and PMA-loopback
jobs the same bounded initial `GTRXRESET` qualification. External mode still
keeps `LOOPBACK=000` and does not pulse `RXPMARESET`. Unit simulation covers
both sequences and retains the first failing controller stage rather than
overwriting it with the generic fault-state number. That build failed routed
setup timing and must not be programmed. Candidate `0x00020006` retains this
functional fix and elaborates full lane engines only for compile-time managed
lanes; IBERT-owned lanes use deterministic protocol stubs. Its first external
60-second run entered and completed `ST_RUN` normally, but lane 13 passed while
lanes 12, 14, and 15 returned saturated error counts despite remaining locked
with no lock losses. The controller had cleared native PRBS counters before
waiting for lock and retained all errors accumulated during checker
acquisition. Candidate `0x00020007` adds a second bounded counter-reset pulse
after every selected lane is locked and before asserting acquisition-ready,
so the timed interval begins with clean native counters. It must pass the
60-second external smoke before restarting the 12-hour soak.

Its first external smoke did not reach the new counter-reset state. AXI
platform status `0xE08080C4` decoded to a healthy READY quad, healthy RX/PMA
reset qualifiers, PRBS-controller fault reason `0x80`, and retained stage 8
(`ST_LOCK_WAIT`). Candidate `0x00020008` therefore makes the acquisition bound
ten seconds and retains richer first-fault context until FPGA reset. The live
and captured records include selected/running lanes, current/ever/lost lock
masks, RX/PMA reset and DRP qualifiers, quad power/QPLL/user clocks/reset-done,
sequencer state, and its elapsed cycle counter. Python launch/status tools
select I2C diagnostic page `0xFE` and decode it automatically on a fault.
The same snapshot can be read without starting or acknowledging a run using
`python3 scripts/milestone3_platform_diagnostics.py`.

The clean `0x00020008` Vivado 2023.2.2 build completed on 2026-09-01.
Authoritative routed timing is WNS `+0.139 ns`, TNS `0`, WHS `+0.009 ns`,
THS `0`, and pulse-width slack `+0.241 ns`, with no failing endpoints. All
784,712 routable nets are fully routed with zero routing errors; all four
bus-skew constraints pass with worst slack `+19.358 ns`. Routed DRC has zero
errors, and the clock report contains 100.000-MHz `clk_100_raw` and
325.000-MHz `clk_325_raw`. Compression is enabled. The 70,608,035-byte
bitstream has SHA-256
`85ef03f28d60b93b1b5bb45546d4745572c9f937638e664d560e81877c067ce0`.
This image is implementation-qualified but still requires the 60-second
external-path hardware smoke.

That `0x00020008` smoke subsequently completed normally with healthy platform
diagnostics, but only lanes 13 and 14 passed; lanes 12 and 15 saturated even
in separate ten-second runs. The all-lane diagnostic captured partial running
mask `0x7`. Candidate `0x00020009` keeps external RX live, qualifies the quad
supervisor directly from the engine ARM interval through lock, waits for a
stable running mask, and limits persistent lock-loss tracking to acquisition
and measurement. PMA loopback still performs its RX/PMA resets, and both modes
retain the post-lock native-counter clear.

The clean `0x00020009` Vivado 2023.2.2 build and independent routed audit
completed on 2026-09-01. Routed timing is WNS `+0.146 ns`, TNS `0`, WHS
`+0.009 ns`, THS `0`, and pulse-width slack `+0.243 ns`, with no failing
endpoints. All 784,597 routable nets are fully routed with zero routing
errors; all four bus-skew constraints pass with worst slack `+19.601 ns`.
The clock report contains 100.000-MHz `clk_100_raw` and 325.000-MHz
`clk_325_raw`. Routed DRC has zero errors and the same five established
generated-debug/IP and generic-I2C warnings as v8. Compression, the
112-channel ownership/site audit, and the managed-GT golden-property audit
pass. The 70,686,055-byte bitstream has SHA-256
`ded0954bf9c7bfadfac5d2ad3305bb9b38ffe5dc340aad4d29ccf9027cb1742d`.
This image was implementation-qualified; its subsequent first hardware gate
failed before acquisition as described below.

The first v9 lane-12 launch did not reach acquisition. The engine remained in
ARM while diagnostics showed a healthy quad, controller IDLE, synchronized
running/locked mask `0x1`, and selected mask zero. The stable-mask filter set
its counter to one when the mask changed but never incremented it while the
mask remained stable. Candidate `0x0002000A` adds the missing increment and a
bounded testbench watchdog. Do not reuse the v9 bitstream.

The clean `0x0002000A` Vivado 2023.2.2 build and independent routed audit
passed on 2026-09-02. Routed timing is WNS `+0.238 ns`, TNS `0`, WHS
`+0.009 ns`, THS `0`, and pulse-width slack `+0.247 ns`. All 785,339 routable
nets are fully routed with zero routing errors; all four bus-skew constraints
pass with worst slack `+19.578 ns`. The 100.000-MHz and 325.000-MHz generated
clocks, compression, managed quad-124 sites and golden RX properties, and all
13 IP status checks pass. Routed DRC has zero errors and the same five
established generated-debug/IP and generic-I2C warnings. The 70,098,947-byte
bitstream has SHA-256
`fa4042fd1def68935e34e5c4d282d5db7416cc1182518b3a46c4e2f5fb40d268`.
It is ready for the short lane-12 external diagnostic and remains
hardware-unaccepted until that gate and the all-lane 60-second smoke pass.

The first v10 lane-12 diagnostic accepted sequence 2, entered the measurement
interval, stopped normally, and returned to healthy IDLE, proving the missing
stable-mask increment was the v9 launch blocker. It did not pass the BER gate:
lane 12 returned status `0x0000180C`, exactly one native error, zero lock
losses, no saturation, 257,808,079,360 tested bits, and 3,222,600,992 valid
cycles. Aggregate `0x01000101` is therefore internally consistent. Repeat the
same ten-second lane-12 test without reprogramming before the all-lane smoke.
Repeated exact one-count results would identify the post-lock counter-reset to
measurement transition as the next boundary to harden.

The clean `0x00020007` Vivado 2023.2.2 build completed on 2026-09-01.
Authoritative routed timing is WNS `+0.119 ns`, TNS `0`, WHS `+0.009 ns`,
THS `0`, and pulse-width slack `+0.251 ns`, with no failing endpoints. All
784,885 routable nets are fully routed with zero routing errors; all four
bus-skew constraints pass with worst slack `+19.600 ns`. Routed DRC has no
errors and the same generated-IP/debug warnings as the previous candidate.
The implemented clock report contains 10.000-ns `clk_100_raw` and 3.077-ns
`clk_325_raw` periods. Compression and the 112-channel ownership/site audit
passed. The 70,619,719-byte bitstream has SHA-256
`3ce07b01b3e7b3c14483897dbd5c00ecc71a1ecdf38779276c266497ed131ce7`.

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
| 6. One-hour burn-in | Run one uninterrupted near-end PMA-loopback PRBS31 job on all four managed lanes for one hour. Record F1 AVTT current and FPGA temperature immediately before and after the run. | Zero errors and lock losses; no counter saturation, timeout, QPLL/reset fault, or result-bank inconsistency. AVTT and temperature remain sane and stable. |
| 7. Overnight soak | Run one uninterrupted external PRBS31 job for at least 12 hours. Repeat at the normal operating thermal/load condition; add cold/hot operating points when board controls permit safe operation. | Same criteria as the one-hour run. Temperature and supplies remain within board limits, and all 108 IBERT-owned lanes retain their expected post-test state. |
| 8. Extended qualification | After the overnight run passes, execute `scripts/run_milestone3_24hour_qualification.sh`; use 72 hours when qualifying a board/module combination for deployment. | No unexplained error, lock loss, reset, QPLL, firmware, or publication failure. Any failure preserves the complete failing record and environment log. |

The standalone operator procedure for stage 6, including register derivation,
six-line CLI blocks, completion polling, and result interpretation, is
[`milestone3-one-hour-soak.md`](milestone3-one-hour-soak.md).

The first stage-4 isolation procedure is the five-minute lane-12 targeted
error-injection test in
[`milestone3-targeted-error-injection.md`](milestone3-targeted-error-injection.md).

The explicit-abort portion of stage 4 passed on 2026-08-27. A five-minute
four-lane PMA-loopback request was stopped through AXI doorbell bit 1 after
about 62.06 seconds. The result was `0x00040402`, final `C8=0`, and four
identical partial lane records with zero errors or lock losses and exact
`tested_bits = valid_cycles * 80` accounting.

The automatic-timeout portion of stage 4 also passed on 2026-08-27. A
five-minute request with a one-minute timeout published `0x00040403`, returned
to `C8=0`, and produced zero-error/zero-lock-loss records on all four lanes.
The measured interval was 60.000 seconds; a one-cycle difference on lane 13
was accompanied by exactly 80 additional bits and is consistent with the
asynchronous stop boundary.

The stage-5 CPU-independence test passed on 2026-08-31. After an FPGA reload,
the MCU committed request sequence 6 and MicroBlaze was halted in its wait
loop while the hardware engine reported `ST_RUN`. With the CPU still halted,
hardware completed its first post-reload run: `F8=1`, `FC=0x00040401`, and
`C8=0x00004000`, while the CPU-owned words correctly remained `F0=F4=0`.
All four lane records contained 7,734,239,847,600 tested bits,
96,677,998,095 valid RX cycles, zero errors, zero lock losses, no saturation,
and exact `tested_bits = valid_cycles * 80` accounting. After XSDB `con`,
firmware acknowledged the retained result with `F0=6`, `F4=0x00040401`, and
`C8=0`; `F8=1` and `FC=0x00040401` remained unchanged. This proves that GT
timing, stop, snapshot, atomic publication, and interrupt retention operate
without MicroBlaze execution, and that resume does not restart the run.

Before the stage-7 external soak, program the reviewed `0x0002000B` candidate
and run `python3 scripts/milestone3_60second_external_smoke.py start`. Do not
start the 12-hour interval unless the short run enters `ST_RUN`, completes
normally with aggregate `0x00040401`, returns to healthy idle, and publishes
zero-error/zero-lock-loss records for lanes 12-15. Use
`scripts/milestone3_12hour_external_soak.py` only after that gate passes.

The accepted 12-hour v11 run satisfies that prerequisite. For the subsequent
unattended stage-8 run, execute—not source—
`scripts/run_milestone3_24hour_qualification.sh`. It defaults to request
sequence `5` after sequence `4`, polls every 30 minutes, logs stdout and stderr
to both screen and a timestamped file, and collects final results after 48
checks. When continuing from the accepted soak without reprogramming, require
the hardware run ID to advance exactly once from `3` to `4`.

The unattended 24-hour v11 external qualification passed. Final results in
`docs/evidence/legacy/24hour.txt`, captured on 2026-09-10, show matching request/response sequence
`5`, stable hardware run ID `4`, response/summary `0x00040401`, and healthy
IDLE. Lanes 12-13 recorded 2,227,461,058,375,760 tested bits over
27,843,263,229,697 valid cycles; lanes 14-15 recorded
2,227,461,058,375,680 tested bits over 27,843,263,229,696 valid cycles. Every
lane had zero errors, zero lock losses, exact 80-bit-per-cycle accounting, and
`BER95 < 1.347e-15`. No first-fault snapshot was valid. The SSH connection
died during the run, so the scheduled half-hour watcher output was not
retained; this is final-state evidence rather than a continuous status record.
The retained acquisition observation recorded sampled-error mask `0xF`,
sampled-unlock mask `0`, and maximum clean streak zero. Those startup samples
were excluded from measurement by the post-observation native-counter reset.
The exact completion timestamp, final F1 AVTT current, and FPGA temperature
remain to be appended. At that point, the remaining campaign work was targeted
measurement-time error injection, forced single-lane lock-loss isolation,
abort/timeout, and CPU-halted completion; current outcomes follow.

On 2026-09-11, the v11 short fault-path continuation produced three accepted
results. Sequence 6/run ID 5 injected one TX PRBS error into lane 12 during a
five-minute near-end-PMA measurement: lane 12 counted exactly one error, lanes
13-15 remained at zero, all lock-loss counts were zero, and matching summary
`0x01030401` returned to healthy IDLE. Sequence 7/run ID 6 was explicitly
aborted through AXI control offset `0x00C` bit 1 and published four coherent,
clean partial records with summary `0x00040402`. Sequence 8/run ID 7 used a
60,000-ms timeout on a five-minute request and published four coherent, clean
partial records with summary `0x00040403`. Every record retained exact
80-bit-per-cycle accounting.

The sequence-9 CPU-halted-test launch was preserved as a failed acquisition
and was not retried. Before the CPU could be halted, the near-end-PMA job
reached the 10-second PRBS `LOCK_WAIT` bound and published run ID 8 with
summary `0x04000404`. First-fault diagnostics show selected/running mask `0xF`
but locked/ever-locked mask `0xB`; lane 14 alone never locked. The quad stayed
READY with power, QPLL, both user clocks, and every TX/RX reset-done qualifier
healthy. All monitored clocks were present, including `lf_r0_af=322.260 MHz`,
and both F1 AVTT/CC PMBus pages reported no status fault. This is an internal
PMA-loopback acquisition failure, so the external module/link partner is not
in its signal path. FPGA die temperature was unavailable because the deployed
MCU firmware does not implement the telemetry page. Forced single-lane
lock-loss isolation remained outstanding after the fault capture.

F1 was subsequently reloaded explicitly with the same audited v11 image, so
the preserved sequence-9 fault remains a separate historical result rather
than a silent retry. A fresh post-reload CPU-halted test then passed as
sequence 1/run ID 1. XSDB halted MicroBlaze at PC `0x220` only after AXI state
confirmed `ST_RUN`. Hardware completed five minutes independently, published
summary `0x00040401` and interrupt-pending state `0x00004000`, and advanced the
run ID exactly once while CPU response sequence/code stayed zero. All four
lane records were clean and coherent with exact 80-bit-per-cycle accounting.
After XSDB resumed the processor, firmware acknowledged the same sequence and
summary, retained run ID 1, and returned to healthy IDLE without relaunching.
Forced single-lane lock-loss isolation was the remaining qualification item.

The installed F1 FireFly-5 x4 module is physical MCU FireFly index 8, part
`B0425040011201`; do not use the mutable populated-device preset for this
operation because it packs F1_5 onto the wrong MCU index. The dedicated
`scripts/milestone3_firefly_lock_loss.py` helper addresses index 8 directly,
uses lower-page byte 86 (`0x56`) as the per-channel TX-disable mask, verifies
each write, and restores the complete original byte in a `finally` path.
Post-reload sequence 4/run ID 4 disabled only channel 0/global lane 12 for one
second, and sequence 5/run ID 5 repeated it for ten seconds. Both verified
`0x00 -> 0x01 -> 0x00` and completed normally with summary `0x01030401`.
Lane 12 alone saturated at 4,294,967,295 errors; lanes 13-15 remained clean and
locked, proving correct channel mapping and adjacent-lane isolation. However,
`RXPRBSLOCKED` did not deassert during either TX-disable interval: lane 12
retained full valid-cycle accounting, remained locked at stop, and published
zero lock losses. The required lock-loss indication therefore did not pass,
so v11 is not fully hardware-qualified despite completing every other listed
test. Sequence 6/run ID 6 repeated the ten-second interval while reading
incorrect candidate alarm addresses `0x07` and `0x15`; those zero reads are not
interpreted as module evidence. Sequence 7/run ID 7 repeated the interval with
the correct read-to-clear interrupt bytes. During TX disable, LOS byte 3 was
`0x11` (RX0/TX0) and CDR-LOL byte 5 was `0x01` (RX0), proving the module saw
the isolated signal and CDR loss. The final FPGA result nevertheless repeated:
lane 12 alone saturated its error counter, lanes 13-15 stayed clean, and all
FPGA lock-loss counts were zero. V11's `RXPRBSLOCKED`-based runtime detector
therefore did not reflect a module-confirmed lock-loss event.

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
   Run `python3 scripts/milestone3_dump_results.py` to decode the aggregate and
   all four records without starting, clearing, or acknowledging another run.
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
`0x01` instead for F2. The validated isolated `0x00020004` image uses the same
corrected supervisor behavior and a uniquely bumped build identity. Confirm
firmware `0xC0=0x00020004`, hardware `0xC4=0x00020004`, and `0xC8=0` at healthy idle
before launching a one-second
near-end PMA-loopback PRBS31 job. The only valid four-lane mask is the low word
`0x0000F000`; the other three words must be zero. The CLI copy/paste buffer is
assumed to accept at most six lines, so submit each block below separately and
wait for its output before submitting the next block. The semaphore remains
held across all block boundaries. Write values omit redundant leading zeroes;
`i2cwr` pads each value to its requested width.

```text
semaphore 5 take
i2cw  5 70 1 0x4
i2crr 5 2b 1 c0 4
i2crr 5 2b 1 c4 4
i2crr 5 2b 1 c8 4
i2cwr 5 2b 1 a4 4 0x11501
```

```text
i2cwr 5 2b 1 a8 4 0x3e8
i2cwr 5 2b 1 ac 4 0x7d0
i2cwr 5 2b 1 b0 4 0xf000
i2cwr 5 2b 1 b4 4 0x0
i2cwr 5 2b 1 b8 4 0x0
i2cwr 5 2b 1 bc 4 0x0
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
i2cwr 5 2b 1 a0 4 0x1
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
i2cwr 5 2b 1 cc 1 0xc
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
i2cw  5 70 1 0x0
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

Two v2.5-only Python 3.6 diagnostics support a controlled comparison with the
later full-M3 external-path failure. After a fresh v2.5 programming operation,
`scripts/milestone25_historical_external_smoke.py` repeats the original
one-second, four-lane external test. Reprogram v2.5 again before running
`scripts/milestone25_external_restart_matrix.py`; it performs two ten-second
lane-12 external jobs, one lane-13 external job, a four-lane near-end PMA
recovery job, and two more lane-12 external jobs. It waits internally, prints
every selected lane record, and retains ordinary BER failures through the end
of the six-job comparison. A version mismatch, dirty initial sequence/run-ID
state, transport error, engine-state error, or platform fault stops the matrix.

The 2026-09-02 golden-IBERT control captured in
`docs/evidence/legacy/Table.xlsx`
shows Quad 124 channels `MGT_X0Y16` through `MGT_X0Y19` running PRBS31 with
`Loopback Mode=None`. All four links report locked RX and TX PLLs, zero errors,
and approximately `1.072e12` tested bits per lane. This demonstrates that the
current external optical path can carry error-free PRBS31 under the golden
IBERT controller. In contrast, a freshly programmed preserved v2.5 image
subsequently saturated the native error counter on all four lanes during its
first one-second external-path run. Consequently, do not attribute the current
failure to the optical path or solely to a v2.5-to-v10 RTL regression; the
remaining investigation is the difference between golden-IBERT and managed
PRBS acquisition/control behavior.

The subsequent fresh-image v2.5 restart/recovery matrix sharpened that result.
Lane 12's first ten-second external run accumulated 1,425 native error
indications, its immediate repeat saturated, and the following lane-13 run
also saturated. The four-lane near-end PMA run did not recover the checker:
lanes 12 and 14 reported one error indication per valid RX cycle while lanes
13 and 15 reported zero. Both later lane-12 external runs saturated. Every job
entered RUN, stopped normally, retained PRBS lock, and reported no lock-loss
transition, so this is not an engine-control timeout or result-publication
failure. The existing RTL enables RX PRBS selection before the corresponding
TX PRBS selection has crossed its two-stage TXUSRCLK2 synchronizer. The next
candidate must test staged acquisition: hold RXPRBSSEL disabled, establish TX
PRBS31 first, enable/restart the RX checker afterward, qualify a stable locked
and error-free interval, reset the counter, and only then begin measurement.

### Milestone 2.5.1 staged-acquisition experiment

Candidate `0x00020101` implements that experiment in a distinct quad-124-only
target. It does not replace the preserved `0x00020004` v2.5 image or the full
Milestone 3 image. The staged controller performs this order:

1. Stabilize the selected lane mask and apply TX PRBS31.
2. Keep RXPRBSSEL at zero through the normal TX/control settling interval.
3. Enable RXPRBSSEL, wait another settling interval, and pulse the native PRBS
   counter reset.
4. Wait for every selected checker to report locked, then require one
   millisecond of continuously locked and sampled-error-free operation. Any
   sampled error or unlock restarts this qualification; the existing bounded
   operation timeout prevents an infinite wait.
5. Pulse the native counters again so acquisition history is excluded, then
   enter the requested timed measurement.

Build and audit commands are:

```sh
scripts/build_milestone251_firmware.sh
vivado -mode batch -source scripts/build_milestone251_bitstream.tcl
vivado -mode batch -source scripts/audit_milestone251_routed.tcl
```

Program
`build/gt_test_milestone251/gt_test_milestone251.runs/impl_1/gt_test_milestone251.bit`
into F1 and, from a shell with access to `cm_interface` and `/dev/ttyUL4`, run:

```sh
python3 scripts/milestone251_acceptance.py
python3 scripts/milestone251_platform_diagnostics.py
```

The Python 3.6-compatible script requires fresh zero request/response/run-ID
state and verifies version `0x00020101`. It runs five internally timed jobs:
lane-12 external first and repeat, four-lane external, four-lane near-end PMA,
and lane-12 external after PMA. A result is accepted only when the expected
selected/pass counts are published, all selected lanes remain locked with no
lock loss or counter saturation, and every error count is zero. Preserve all
output whether the hypothesis passes or fails.
On a platform fault the acceptance script now prints the live and persistent
selector-`0xFE` page automatically. The standalone diagnostic reader retrieves
the same snapshot later and does not start, abort, acknowledge, or clear a
test.

The first hardware attempt reached state 21 with lane 12 selected, running,
and locked, but timed out after exactly 1,999,999,999 sequencer cycles
(10.000 s) without finding a continuously clean 1-ms window. All quad and RX
reset/clock qualifiers were healthy, and the engine returned platform-fault
summary `0x01000104`. This rules out failure to apply the staged checker or to
acquire initial lock, but does not yet distinguish sampled PRBS errors from
brief unlocks during qualification. Do not treat TX-before-RX staging as the
complete fix based on this image.

### Milestone 2.5.2 fixed-window staged-acquisition experiment

Candidate `0x00020102` retains the staged TX-before-RX control ordering but
does not require an error-free acquisition window. State 21 instead observes
exactly 200,000 management-clock cycles (1 ms), records whether each selected
lane sampled a checker error or unlock, and retains the maximum consecutive
clean streak. It then pulses the native counters and begins the requested
measurement. This deliberately tests whether the post-staging counter reset
can produce a useful measurement even when acquisition itself is not clean.

Build and independently audit it with:

```sh
scripts/build_milestone252_firmware.sh
vivado -mode batch -source scripts/build_milestone252_bitstream.tcl
vivado -mode batch -source scripts/audit_milestone252_routed.tcl
```

Program
`build/gt_test_milestone252/gt_test_milestone252.runs/impl_1/gt_test_milestone252.bit`
into F1. From a shell with `cm_interface` and `/dev/ttyUL4` access, run:

```sh
python3 scripts/milestone252_acceptance.py
```

The script requires a freshly programmed `0x00020102` image and zero mailbox
history. It runs lane-12 external twice, all four lanes external, all four
lanes in near-end PMA loopback, and lane 12 external once more. It handles all
sleeps and polling itself. To reread platform diagnostics without changing
the engine, run:

```sh
python3 scripts/milestone252_platform_diagnostics.py
```

For 2.5.2 only, selector `0xFE` diagnostic word `live_rx` is encoded as:

- bits 31:28: lanes that sampled an error during the fixed window;
- bits 27:24: lanes that sampled an unlock during the fixed window;
- bits 23:6: maximum consecutive clean streak in management-clock cycles;
- bit 5: selected-lane error at the terminal sample;
- bit 4: selected-lane lock at the terminal sample;
- bit 3: Wizard RX done;
- bit 2: selected RXRESETDONE;
- bit 1: selected RXPMARESETDONE;
- bit 0: fixed-window diagnostic format marker (one).

The build, all three controller simulations, and independent routed audit pass.
The complete F1 hardware matrix also passed: both lane-12 external runs, the
four-lane external run, the four-lane near-end PMA run, and the post-PMA
lane-12 external run all completed with zero errors and zero lock losses.
Each ten-second lane measured about 257.8 billion bits (`BER95 < 1.164e-11`).
This accepts fixed observation plus post-acquisition counter reset as the
working acquisition sequence for the managed quad-124 path.

One diagnostic limitation remains: the acquisition masks and maximum-clean
streak are cleared when the controller returns to IDLE, so the all-zero values
printed after these runs do not characterize the preceding 1-ms window. A
future diagnostics revision should retain them until the next request begins.

### Milestone 2.5.3 retained-observation check

Candidate `0x00020103` makes only that diagnostic-lifetime correction. It
retains the fixed-window error/unlock masks and maximum clean streak after the
result handshake and throughout IDLE, then clears them when the next stable
running mask is accepted. The 2.5.2 physical acquisition sequence is otherwise
unchanged.

Build and audit commands are:

```sh
scripts/build_milestone253_firmware.sh
vivado -mode batch -source scripts/build_milestone253_bitstream.tcl
vivado -mode batch -source scripts/audit_milestone253_routed.tcl
```

Program
`build/gt_test_milestone253/gt_test_milestone253.runs/impl_1/gt_test_milestone253.bit`
and run:

```sh
python3 scripts/milestone253_acceptance.py
```

This focused check performs one ten-second lane-12 external run, applies the
normal zero-error/zero-lock-loss criteria, and requires a retained nonzero
maximum clean streak. `milestone253_platform_diagnostics.py` rereads the same
page without changing engine state. Build, simulation, and routed audit pass;
the focused F1 hardware confirmation also passes. Lane 12 measured
257,808,252,880 bits with zero errors and zero lock losses, while the retained
acquisition observation reported error mask `0`, unlock mask `0`, and the full
200,000-cycle (1.000-ms) clean streak. Milestone 2.5.3 is the accepted source
behavior for the next full-M3 integration.

For the targeted-error stage, the injection mechanism is intentionally an AXI
debug control rather than an MCU policy command. In XSDB select the exact CPU
target (for example `targets -set -filter {name =~ "MicroBlaze #0"}`), then
`mwr 0x44a00060 0x00001000` toggles one error request for global lane 12;
bits 13, 14, and 15 select the other managed lanes. Writes to any of the other
108 lane bits are masked out in hardware. Read all four lane records after
completion and verify that only the selected lane has a nonzero error count.
