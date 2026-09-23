# Milestone 2.5.4 signal-loss characterization

This diagnostic target is deliberately separate from full Milestone 3.  Its
firmware and hardware identity is `0x00020104`.  In this image only, each lane
record's error field counts RXUSRCLK2 cycles in which `RXPRBSERR` is asserted,
and generic-port register r38 reports managed-quad RXUSRCLK2.  Normal and
historical targets retain their original exact-error and clock-monitor ABI.

## Golden-IBERT control (2026-09-11)

F1 was explicitly programmed with the golden `src/top.sv` image.  Four
same-lane Quad-124 external PRBS31 links were configured and their TX, RX, and
BERT resets were pulsed through the Vivado hardware manager.  With FireFly-5
channel 0 disabled through byte 86, the module reported LOS byte 3 `0x11` and
CDR-LOL byte 5 `0x01`.  Only `GTYE4_CHANNEL_X0Y16` accumulated errors, at about
`1.425e10` bit errors/s and to a final `143350597593` errors.  Channels X0Y17
through X0Y19 remained at zero errors.  Throughout the outage X0Y16 continued
to report `RXCDRLOCK=1`, `RXELECIDLE=0`, `RXRESETDONE=1`, and an unchanged
RXUSRCLK frequency count.  Error accumulation stopped after byte 86 was
restored from `0x01` to its original `0x00`.

This control demonstrates that CDR lock, electrical idle, and a receiver-clock
heartbeat do not detect this optical outage.  Sustained PRBS corruption is the
only observed FPGA-side discriminator.

## Diagnostic image build

The isolated 2.5.4 image was built cleanly with Vivado 2023.2.2.  Synthesis
confirmed `USE_EXACT_ERROR_COUNTS=0` and
`DIAGNOSTIC_RX_CLOCK_MONITOR=1`.  The routed design has WNS `+0.490 ns`, WHS
`+0.010 ns`, zero routing errors, zero DRC errors, compressed bitstream output,
golden RX properties, and exactly the four managed sites X0Y16-X0Y19.  The
independent routed audit passed.

- Bitstream: `build/gt_test_milestone254/gt_test_milestone254.runs/impl_1/gt_test_milestone254.bit`
- Bitstream SHA-256: `c8f67ccee1e13cf534ff9ebe9612df48dee8e9434f158862d11393edc3a38772`
- Firmware SHA-256: `e28caefebc11651fb8dcd83266f405a8c6558bd007dce8cd7a3f2df57754b34d`

## First hardware attempt

At `2026-09-11T18:33:37-04:00`, a freshly programmed image had matching
firmware/hardware versions, zero request/response sequence, and run ID zero.
Diagnostic r38 measured RXUSRCLK2 at 322.260 MHz.  Request sequence 1 was
committed for a 30-second four-lane external run, but acquisition failed before
the script reached the FireFly-disable operation.  Byte 86 was therefore never
changed by this attempt.

The controller timed out in `LOCK_WAIT` after 1,999,999,999 management cycles
(10 seconds).  Only lane 15 ever reached qualified lock.  The atomic published
result was sequence 1/run ID 1, summary and response `0x04000404` (four failed,
four selected, platform-fault stop), with deterministic platform-failure
records for lanes 12-15.  The first-fault quad snapshot showed all four power,
QPLL, TX-clock, RX-clock, TX-reset-done, and RX-reset-done indications healthy;
fault reason was `0x80`.

The result was preserved before reconfiguration.  F1 AVTT telemetry was
1.20264 V, -0.828 A, and 32.06 C with no regulator status flags.  The FireFly
reported 38 C, 3.2940 V, and byte 86 `0x00`; repeated LOS and CDR-LOL reads were
both `0xff`.  A complete clock snapshot showed the four board GT references at
322.260-322.261 MHz, `clk_100=100.000 MHz`, `clk_325=325.000 MHz`, and diagnostic
r38 RXUSRCLK2 at 322.261 MHz.  FPGA die temperature is not exposed by the
deployed `cm_interface` telemetry page.

This attempt is a preserved acquisition failure, not a signal-loss
characterization result, and must not be silently retried as the same request.

## Post-fault golden control

After preserving the complete result and telemetry, F1 was restored to the
golden image and the four Quad-124 links were configured for external PRBS31
with the standard TX, RX, and BERT reset sequence. All four links immediately
ran clean. Each reported `RXCDRLOCK=1`, `RXELECIDLE=0`, `RXRESETDONE=1`,
`TXRESETDONE=1`, RXUSRCLK count `0x6720`, and zero errors after approximately
`7.88e10` received bits per lane. This rules out a persistently broken optical
loopback and localizes the 2.5.4 attempt's blocker to managed external
acquisition/startup behavior. F1 was left running the golden image.
