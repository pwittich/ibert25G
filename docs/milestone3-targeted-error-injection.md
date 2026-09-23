# Milestone 3 Five-Minute Targeted Error-Injection Test

This procedure runs a five-minute PRBS31 test on managed global lanes 12-15 in
near-end PMA loopback and injects exactly one TX PRBS error request into lane
12. It verifies the nonzero-error reporting path and isolation of the other
three managed lanes while the remaining 108 channels stay under IBERT.

The board CLI steps target F1 through I2C5, mux address `0x70` with value
`0x4`, and FPGA register-slave address `0x2B`. Submit each CLI block separately
and wait for its output. Every paste block has six lines or fewer. Write values
omit redundant leading zeroes because `i2cwr` pads them to the requested width.

The injection itself uses XSDB, not the board CLI. Keep MicroBlaze running; the
test is intended to verify ordinary firmware completion after the injected
hardware error.

## Descriptor settings

Command `A4=0x11501` selects:

| Field | Setting | Encoded value |
|---|---:|---:|
| Opcode `[7:0]` | `1`, parallel BER | `0x1` |
| PRBS `[10:8]` | `5`, PRBS31 | `0x500` |
| Loopback `[13:11]` | `2`, near-end PMA | `0x1000` |
| Timebase bit 16 | `1`, milliseconds | `0x10000` |

Five minutes is 300 seconds or 300,000 ms, so `A8=0x493E0`. Timeout `AC=0`
disables the descriptor timeout; independent bounded quad reset and lock checks
remain active.

The managed-lane mask is `B0=0xF000` and `B4=B8=BC=0`. The previous one-hour
soak completed with response sequence 2, so this example commits request
sequence 3. If `F0` no longer reads 2, use a different request sequence,
normally the next integer.

## Pre-test checks

Confirm that the other 108 IBERT-owned channels are in their expected state.
Then take I2C5, select F1, and check the image and previous response:

```text
semaphore 5 take
i2cw  5 70 1 0x4
i2crr 5 2b 1 c0 4
i2crr 5 2b 1 c4 4
i2crr 5 2b 1 c8 4
i2crr 5 2b 1 f0 4
```

For a new run with the current full-M3 candidate, require
`C0=C4=0x0002000B`, `C8=0`, and note the actual prior response at `F0`. The
recorded 2026-08-27 result below belongs to the earlier `0x00020004` artifact.

## Configure the five-minute run

```text
i2cwr 5 2b 1 a4 4 0x11501
i2cwr 5 2b 1 a8 4 0x493e0
i2cwr 5 2b 1 ac 4 0x0
i2cwr 5 2b 1 b0 4 0xf000
i2cwr 5 2b 1 b4 4 0x0
i2cwr 5 2b 1 b8 4 0x0
```

```text
i2cwr 5 2b 1 bc 4 0x0
i2crr 5 2b 1 a4 4
i2crr 5 2b 1 a8 4
i2crr 5 2b 1 ac 4
i2crr 5 2b 1 b0 4
i2crr 5 2b 1 b4 4
```

```text
i2crr 5 2b 1 b8 4
i2crr 5 2b 1 bc 4
```

Before committing, verify `A4=0x00011501`, `A8=0x000493E0`,
`AC=0x00000000`, `B0=0x0000F000`, and `B4=B8=BC=0x00000000`.

## Start request 3

Only after all descriptor readbacks are correct:

```text
i2cwr 5 2b 1 a0 4 0x3
i2crr 5 2b 1 a0 4
i2crr 5 2b 1 c8 4
i2cw  5 70 1 0x0
semaphore 5 release
```

## Recorded result: 2026-08-27

Request/run sequence 3 completed normally. Firmware and hardware summaries
both read `0x01030401`, and final status was `C8=0`. The XSDB injection word
changed from `0x00000000` to `0x00001000` while engine state was `ST_RUN=2`,
confirming exactly one lane-12 injection request.

Lane 12 reported normal selected/locked status, exactly one error, zero lock
losses, no saturation, 7,734,241,958,880 tested bits, and 96,678,024,486 valid
RX cycles. Lanes 13-15 had identical bit/cycle counts with zero errors, zero
lock losses, and no saturation. For every lane, `tested_bits = valid_cycles *
80`. The other 108 IBERT-owned channels operated as before after the test. The
targeted-error detection and full-image isolation criteria passed.

`A0` should read back as 3. The immediate `C8` state will normally show arming
or running. Releasing I2C5 is intentional: the FPGA runs independently, and
normal MCU monitoring should remain available during the five-minute interval.

## Inject one error into lane 12

Wait roughly 30 seconds after launch so the engine is well inside its
measurement interval. In XSDB, connect and select the running MicroBlaze:

```text
connect
targets
targets -set -filter {name =~ "MicroBlaze #0"}
mrd 0x44a00010
```

The low state bits at engine status address `0x44A00010` should indicate
`ST_RUN=2`. Do not inject if the engine is idle or already complete.

Read the lane-injection toggle word, inject lane 12 once, and read it again:

```text
mrd 0x44a00060
mwr 0x44a00060 0x1000
mrd 0x44a00060
```

AXI offset `0x060` covers lanes 0-31; bit 12 (`0x1000`) targets only global
lane 12. This register is write-one-toggle. Each write containing bit 12
creates one new pulse after synchronization into TXUSRCLK2, so execute the
`mwr` command exactly once. The before/after `mrd` values should differ in bit
12; the absolute stored toggle value may be either zero or one depending on
earlier injection tests.

Do not halt MicroBlaze and do not write any other injection bit. Leave the run
undisturbed until its five-minute hardware duration expires.

## Check for completion

The response sequence `F0` remains at 2 until request 3 has completed and
firmware has published its response. Check occasionally without retaining the
semaphore:

```text
semaphore 5 take
i2cw  5 70 1 0x4
i2crr 5 2b 1 f0 4
i2crr 5 2b 1 f8 4
i2cw  5 70 1 0x0
semaphore 5 release
```

Request 3 is ready when `F0=3`. Hardware run ID `F8` should also be 3. If
`F8=3` while `F0=2`, hardware has published but MicroBlaze has not yet serviced
the completion interrupt.

## Read aggregate results

After `F0=3`, take the semaphore and retain it through all lane-result reads:

```text
semaphore 5 take
i2cw  5 70 1 0x4
i2crr 5 2b 1 f0 4
i2crr 5 2b 1 f4 4
i2crr 5 2b 1 f8 4
i2crr 5 2b 1 fc 4
```

```text
i2crr 5 2b 1 c8 4
```

Expected aggregate values are:

- `F0=0x00000003`: response sequence matches request 3.
- `F4=0x01030401`: one failed, three passed, four selected, normal stop.
- `F8=0x00000003`: hardware run ID advanced exactly once.
- `FC=0x01030401`: hardware and firmware summaries agree.
- `C8=0x00000000`: healthy idle with no platform fault.

The targeted lane is intentionally classified as failed because its exact
error count is nonzero. That expected failure must not set a platform fault or
prevent normal result publication.

## Read all four lane records

### Channel 12: injected lane

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

Require normal selected/locked status `D0=0x0000180C`, a nonzero nonsaturated
error count in `D8:D4` (normally one for one force-error pulse), zero lock
losses at `E4`, and a full five-minute-sized tested-bit count at `E0:DC`.

### Channel 13

```text
i2cwr 5 2b 1 cc 1 0xd
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

### Channel 14

```text
i2cwr 5 2b 1 cc 1 0xe
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

### Channel 15

```text
i2cwr 5 2b 1 cc 1 0xf
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

For channels 13-15 require normal selected/locked status (`D0=0x180D` through
`0x180F`), exactly zero errors in `D8:D4`, zero lock losses at `E4`, no
saturation, and tested-bit/valid-cycle counts equal to channel 12. For every
lane, `E0:DC` must equal `(EC:E8) * 80`.

The nominal five-minute count is approximately 7,734,375,000,000 bits per
lane. The actual value will track the measured RX clock and may be slightly
lower. Do not treat the deliberately injected error as a BER-quality
measurement; this test validates reporting and isolation.

After reading the managed records, confirm the 108 IBERT-owned channels retain
their expected state.

## Cleanup

Always clear the mux and release I2C5, including after an earlier error:

```text
i2cw  5 70 1 0x0
semaphore 5 release
```
