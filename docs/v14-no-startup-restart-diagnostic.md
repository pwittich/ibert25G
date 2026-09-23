# Full Milestone 3 v14 — no-startup-restart diagnostic

## Purpose and scope

Full v13 (`0x0002000D`) failed two independently programmed fresh external
requests before `RUN`, each with `0x04000404`. The selected-lane error
observation remained active through the fixed acquisition interval. The first
run sampled lane 14 unlocked; the second had all lanes ever locked, but the
same all-lane error-active failure. Both failures preserved their results
before reconfiguration, with normal clocks, rails, regulator status, and
approximately 24.5 C FPGA temperature. They are reproducible, not transient.

The cross-image routed comparison against isolated v275 found the same managed
quad sites, GT properties, PRBS/reset structure, and no managed-to-full-IBERT
net. The remaining controlled hypothesis is the v13 planned full-quad restart
at external startup: it consumes the single recovery opportunity before the
one-millisecond clean observation can succeed.

V14 (`0x0002000E`) is a separately versioned, unqualified diagnostic that
changes exactly one v13 policy generic:

```
EXTERNAL_STARTUP_QUAD_RESTART=0
```

It retains staged acquisition, `EXTERNAL_QUAD_RECOVERY=1`, no external RX
recovery, post-capture quad restart, the runtime-integrity detector, and the
physical-only heartbeat path. It is not a qualification candidate and does not
establish optical LOS, native CDR-loss, or missing-RXUSRCLK2 behavior.

## Build and routed audit — 2026-09-14

The matching v14 firmware, compressed implementation, and independent routed
audit pass. The implementation has zero errors and critical warnings; routed
timing is WNS `+0.222 ns`, WHS `+0.009 ns`, TNS/THS `0`. Routing and routed DRC
have zero errors. All four bus-skew constraints pass (worst slack `+19.464 ns`),
and `clk_100_raw`/`clk_325_raw` implement at 100.000/325.000 MHz.

The audit verifies the 52+4+56 ownership split (112 GT channels), managed
sites `GTYE4_CHANNEL_X0Y16` through `X0Y19`, golden managed RX properties,
compression, direct registered profile sources, runtime-integrity synchronizer
structure, and physical-only heartbeat fan-in. All 16 descriptor capture paths
retain their 3.000-ns requirement; worst slack is `+2.155 ns`. Existing
generated-IP and intentional CDC/methodology findings remain; this does not
make the design globally CDC-clean.

- Bitstream SHA-256: `02633d63dce3e75b4e80de537341b89d7e6aa964ee6b710b8e3432e2ad665931`
- Firmware SHA-256: `d8eecdb9b84c9d0395e6a0a06f5f84d0add22b6622e2dc6566e3f87afa2a41c9`
- Routed reports: `build/gt_test_milestone3_v14_audit/`

## Hardware result — 2026-09-14

Following a board power cycle, F1 was programmed once through the explicit
XVC endpoint `TCP:apollo3010-1:2542`. The hash-pinned helper enumerated F1 as
JTAG target 1 (F2 is target 5), and the serialized mailbox preflight confirmed
firmware/hardware `0x0002000E`, IDLE, and request/response/run ID 0.

Two explicitly authorized, unique 60-second external requests completed with
matching sequence/run IDs 1 and 2 and normal response/summary `0x00040401`.
For sequence 1, all managed lanes 12--15 recorded exactly
1,546,848,197,680 tested bits and 19,335,602,471 valid cycles; for sequence 2,
they recorded 1,546,848,072,800 tested bits and 19,335,600,910 valid cycles.
Both runs had zero errors, zero native lock losses, and `BER95 < 1.939e-12` per
lane. The retained fault counter and first-fault words were zero. The engine
returned to healthy IDLE; no retry, reset, or reload was performed.

Post-run regulator captures were clear: after sequence 1 AVTT page 0 was
1.20435 V, 24.21875 A, and 42.6875 C; after sequence 2 it was 1.20093 V,
24.34375 A, and 43.25 C. The existing FPGA-SysMon temperature helper remains hard-coded
to the retired `lnx4189:3121` hardware-server endpoint, so it failed before
reading a sensor. The serialized MCU ADC path subsequently captured F1 at
54.59375 C and F2 at 27.71875 C. This is the authoritative post-v14 FPGA
temperature capture. The old Vivado helper still requires XVC conversion, but
it is not needed for MCU-based temperature telemetry. Evidence is retained in
`build/diagnostic_archive/v14-external-smoke-{start,results}-1789426*.log`.

The two independent passes support the narrow hypothesis that the planned
full-quad startup restart caused the full-v13 pre-RUN acquisition failure.
They are diagnostic, not qualification, and do not test optical LOS, native
CDR loss, or missing RXUSRCLK2.

## Superseded hardware strategy

The completed sequence-1 and sequence-2 operations are consumed. Do not recast
them as qualification results or repeat them as silent retries. Any subsequent
v14 work requires an explicitly justified new request sequence and a corrected
temperature-capture path; the MCU ADC helper is the available path.
