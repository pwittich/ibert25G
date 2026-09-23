# V270 hardware baseline gates — 2026-09-12

Subsequent [lane-12 pulse characterization](v270-pulse-characterization.md)
passed as sequence/run ID 3. The baseline-only record below is historical.

**Both 10-second, four-lane external PRBS31 baselines passed on F1.**
F1 now runs isolated diagnostic v270 / 2.5.20, firmware/hardware `0x00020114`,
healthy IDLE after request/response/run ID 2. No fault stimulus, FireFly
disable, third request, or reload between the two runs was issued. These are
diagnostic baseline passes, not complete hardware qualification.

## Programming and preflight

The user authorized continuation after the build. Before reconfiguration, a
read-only result dump confirmed the unchanged v269/run-1 failure. Its archived
JSON/logs remain intact. The v270 bitstream and ELF hashes were rechecked
against [the build record](v270-build.md).

XSDB ran on lnx4189, connected with `-url TCP:lnx4189:3121`. Read-only target
enumeration showed F1 target 1, its running MicroBlaze target 3, F2 target 4.
`build/program270.tcl` checked the bitstream hash and programmed only F1,
using the embedded matching firmware. A subsequent mailbox dump verified both
version words `0x00020114`, engine IDLE, and request/response/run ID zero.

JTAG SysMon before programming and after run 2: F1 **25.5 C**, F2 **24.0 C**
on both readings. Logs: `build/temperature-preprogram270.log` and
`build/temperature-post270-run2.log`. This is FPGA temperature, not FireFly.

F1AVTT/CC telemetry before / after:

| Page | Vin (V) | Vout before / after (V) | Raw Iout before / after (A) | Regulator temperature before / after (C) |
| --- | --- | --- | --- | --- |
| 0 | 11.9375 | 1.2060546875 / 1.207763671875 | -0.765625 / -0.6337890625 | 33.0625 / 32.5625 |
| 1 | 11.9375 | 0.902587890625 / 0.90625 | -0.18798828125 / -0.204833984375 | 32.0625 / 32.5625 |

All supply status fields were zero; switching frequency 457 kHz. Negative
current values remain raw/unvalidated. FireFly was 38 C, 3.299 V before and
38 C, 3.304 V after. Byte 86 stayed zero. Bytes 3/5 remained `FF/FF` on both
checks. That unresolved readback must be investigated before optical stimuli;
it is not evidence of a controlled outage. No independent optical-partner
telemetry was obtained.

## Baseline evidence

Matching operator `milestone270_characterize.py`, `--stimulus clean
--duration-ms 10000`, sequence/previous/run-ID tuples `(1,0,1)` then `(2,1,2)`.
No retry and no reload between them. Each request verified descriptor mask
`0xF000` before commit and incremented hardware run ID exactly once.

| Check | Run 1 | Run 2 |
| --- | --- | --- |
| Response / hardware summary | `0x00040401` | `0x00040401` |
| Trace epoch / retained events | 1 / 103 | 2 / 108 |
| Trace overflow | No | No |
| FD cumulative requested / accepted / completed | 1 / 1 / 1 | 2 / 2 / 2 |
| Latest restart cause / status / mask | 3 / 3 / `0xF` | 3 / 3 / `0xF` |
| RX clock before / after (kHz) | 322260 / 322262 | 322263 / 322260 |
| Start request / ack at measurement | 1 / `0xF` | 0 / `0x0` |

Each run returned selected/locked lane records `0x180C` through `0x180F`,
zero errors and zero lock losses on all four lanes, and healthy PRBS IDLE /
quad ready after exactly one cleanup restart. Native RX profiles also had
zero errors. Both traces show TX/RX PRBS selections `0x55555555` throughout
the recorded measurement transitions. This exercises both handshake phases
and does not reproduce v269's missing lane-12 selection on these two runs.

Run 1: each lane had 3,222,603,499 valid cycles, 257,808,279,920 tested bits.
Run 2: lanes 12/14/15 had 3,222,603,453 cycles and 257,808,276,240 bits;
lane 13 had one additional cycle (80 bits). All records satisfy bits = cycles
times 80. Capture verified stable overview, lane records and metadata over
the complete trace readout before validation.

## Evidence locations and hashes

Apollo originals, including version-matched operator scripts:
`/tmp/v270-diagnostic-20260912/`. Local copies under
`build/diagnostic_archive/`, SHA-256:

- `v270-run1-clean.json`:
  `e25b2f6668c23e105fe5e1cc7d1b718c85fc60815ff34e340360e3ea9ad2876c`
- `v270-run1-clean.log`:
  `cdf4e979d194a41e64cfe3fecf2c55562bbe823f08c93465658b367064ce0f43`
- `v270-run2-clean.json`:
  `f23c43f6591226aa9e0f380fcd315eec694823b64d1ecd2d6d049faffc789921`
- `v270-run2-clean.log`:
  `4e5c5d9b63d7b7daba949fa2a8c3deb80a83059f878e60f6e89fa240b85798ba`

## Next gate

The two-clean-baseline prerequisite is satisfied. Next is bounded diagnostic
fault characterization (lane-12 injected error pulse first), retaining the
trace/native profile and preserving any unexpected failure before proceeding.
Use sequence 3 after 2, expected run ID 3 if hardware remains unchanged; never
silently retry. Resolve FireFly `FF/FF` before the optical-loss stage. Runtime
integrity-detector thresholds and a separate clean qualification candidate
remain deferred until characterization supports them.
