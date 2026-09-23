# Milestone 3 One-Hour PMA-Loopback Soak

This procedure runs PRBS31 for one hour on managed global lanes 12-15 using
near-end PMA loopback. It targets F1: I2C5 mux address `0x70`, mux value `0x4`,
and FPGA register-slave address `0x2B`.

Submit each command block separately and wait for its output. Every block has
six lines or fewer. Write values omit redundant leading zeroes because
`i2cwr` pads values to the explicitly requested width.

## Descriptor settings

The command at `A4` is `0x11501`:

| Field | Setting | Encoded value |
|---|---:|---:|
| Opcode `[7:0]` | `1`, parallel BER | `0x1` |
| PRBS `[10:8]` | `5`, PRBS31 | `0x500` |
| Loopback `[13:11]` | `2`, near-end PMA | `0x1000` |
| Timebase bit 16 | `1`, milliseconds | `0x10000` |

With the millisecond timebase selected, one hour is 3,600,000 ms, so duration
`A8` is `0x36EE80`. Timeout `AC` is zero (disabled); the independent bounded
quad initialization, reset, and lock checks remain active.

The only legal Milestone 3 lane mask selects global lanes 12-15:

| Register | Value |
|---|---:|
| `A4` | `0x11501` |
| `A8` | `0x36EE80` |
| `AC` | `0x0` |
| `B0` | `0xF000` |
| `B4` | `0x0` |
| `B8` | `0x0` |
| `BC` | `0x0` |

Writing a new request sequence to `A0` commits the complete descriptor. The
examples below use sequence `2`, appropriate when the last completed response
at `F0` is `1`. If `F0` contains another value, use a different sequence,
normally the next integer.

## Before launch

Record F1 AVTT current and FPGA temperature.

Take I2C5, select F1, and confirm the image and current response sequence:

```text
semaphore 5 take
i2cw  5 70 1 0x4
i2crr 5 2b 1 c0 4
i2crr 5 2b 1 c4 4
i2crr 5 2b 1 c8 4
i2crr 5 2b 1 f0 4
```

For a new run with the current full-M3 candidate, require
`C0=C4=0x0002000B`, healthy idle `C8=0`, and note the response sequence at
`F0`. The recorded 2026-08-27 passing run used the earlier `0x00020004`
artifact; retain that identity in historical results.

## Configure the run

```text
i2cwr 5 2b 1 a4 4 0x11501
i2cwr 5 2b 1 a8 4 0x36ee80
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

Before committing, verify these exact padded readbacks: `A4=0x00011501`,
`A8=0x0036EE80`, `AC=0x00000000`, `B0=0x0000F000`, and
`B4=B8=BC=0x00000000`.

## Start the run

Only after the descriptor readbacks are correct, commit sequence 2:

```text
i2cwr 5 2b 1 a0 4 0x2
i2crr 5 2b 1 a0 4
i2crr 5 2b 1 c8 4
i2cw  5 70 1 0x0
semaphore 5 release
```

`A0` should read back as `2`. The immediate `C8` state will normally indicate
arming or running rather than idle.

Releasing the semaphore after launch is intentional. The test progresses
entirely in FPGA hardware, and releasing I2C5 permits normal MCU monitoring
during the hour. Do not poll acquisition counters.

## Check whether the run is finished

`F0` is the firmware response sequence and is the normal completion indicator:

- `F0=1`: request 2 has not yet been published.
- `F0=2`: request 2 is complete and its results are ready.

`F8` is the hardware run ID. For this example, `F8=2` means hardware has
completed and atomically published run 2. If `F8=2` while `F0=1`, hardware is
finished but MicroBlaze has not yet serviced the completion interrupt.

Use this occasional status check without retaining the semaphore:

```text
semaphore 5 take
i2cw  5 70 1 0x4
i2crr 5 2b 1 f0 4
i2crr 5 2b 1 f8 4
i2cw  5 70 1 0x0
semaphore 5 release
```

Normally, wait one hour plus several seconds before checking. PMA reset, lock
qualification, stopping, DRP capture, and firmware publication add a small
amount of time outside the measured one-hour interval.

## Read the aggregate result

After `F0=2`, record F1 AVTT current and FPGA temperature again, then read:

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

A successful sequence-2 run has:

- `F0=0x00000002`: response sequence matches the request.
- `F4=0x00040401`: four selected, four passed, normal stop.
- `F8=0x00000002`: hardware run ID advanced once.
- `FC=0x00040401`: hardware and firmware summaries agree.
- `C8=0x00000000`: healthy idle with no pending fault.

## Read all four lane records

Keep the semaphore and mux selection from the aggregate read while collecting
these records.

### Channel 12

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

For each lane require:

- `D0`: selected, locked, normal result; normally `0x180C`-`0x180F`.
- `D8:D4`: zero errors.
- `E0:DC`: approximately 92,812,500,000,000 tested bits (`9.28125e13`).
- `E4`: zero lock losses.
- `EC:E8`: approximately 1,160,156,250,000 valid RX cycles.
- No error-count or tested-bit saturation flags.

The exact tested-bit and valid-cycle counts may be slightly below the nominal
values because of synchronized start/stop boundaries. Do not combine the four
lanes when quoting a BER limit. With zero observed errors, the approximate
one-sided 95% upper bound is `3/tested_bits`, about `3.2e-14` per lane.

## Cleanup

Always clear the mux and release I2C5, including after an earlier command
error:

```text
i2cw  5 70 1 0x0
semaphore 5 release
```

## Recorded result: 2026-08-27

Request/run sequence 2 completed normally. Firmware and hardware both
published `0x00040401`, and final status was `C8=0`. All four lane records
reported normal selected/locked status (`D0=0x180C` through `0x180F`), zero
errors, zero lock losses, and no saturation. Every lane recorded exactly
92,810,902,916,320 tested bits and 1,160,136,286,454 valid RX cycles, satisfying
`tested_bits = valid_cycles * 80`. The zero-error one-sided 95% BER upper bound
is approximately `3.23e-14` per lane. F1 AVTT current and FPGA temperatures
were checked and remained normal.
