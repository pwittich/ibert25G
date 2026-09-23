# Milestone 2.5.5/2.5.6 signal-loss characterization

These isolated diagnostic targets remain separate from full Milestone 3.
Version 2.5.5 (`0x00020105`) adds one bounded RX-datapath recovery reset after
100 ms of unsuccessful external PRBS acquisition. Version 2.5.6
(`0x00020106`) additionally guards and requalifies synchronized RX-done status
while the external checker is removed after result capture. Both retain the
2.5.4-only diagnostic meanings: lane errors count RXPRBSERR-active RXUSRCLK2
cycles and r38 reports managed RXUSRCLK2.

## Build and simulation

The controller suite covers the one-shot external recovery and a forced
post-capture RX-done drop across the two-stage status synchronizer. Historical
targets default both features off. The clean 2.5.6 Vivado 2023.2.2 build and
independent routed audit passed with WNS `+0.592 ns`, WHS `+0.009 ns`, pulse
width slack `+0.454 ns`, 23,684 fully routed nets, zero routing errors, zero
DRC errors, compressed output, correct 100/325-MHz clocks, golden RX
properties, and exactly `GTYE4_CHANNEL_X0Y16`-`X0Y19`.

- Bitstream: `build/gt_test_milestone256/gt_test_milestone256.runs/impl_1/gt_test_milestone256.bit`
- Bitstream SHA-256: `daa8046dd2ce1702e0bac6d992e5f0ae401b633abc6066203837e1ffbc67a9ec`
- Embedded ELF SHA-256: `ac37c9ae0fabef073b1eb2c17555d21a4967b180be2f3fd7ebcc572d5927f30f`

## Version 2.5.5 run

Fresh sequence 1/run ID 1 acquired all four lanes and completed the intended
30-second external measurement. FireFly-5 byte 86 changed `0x00 -> 0x01 ->
0x00`; during the ten-second channel-0 disable, LOS byte 3 was `0x11` and CDR
LOL byte 5 was `0x01`. Managed RXUSRCLK2 stayed at 322.260-322.261 MHz.

The published summary was `0x01030401`. Lane 12 alone recorded
3,381,646,559 error-active cycles out of 9,667,805,158 valid cycles; lanes
13-15 recorded zero and every lock-loss count was zero. Teardown then latched
platform fault `0x00010000`: the first-fault quad record showed RX reset-done
absent with reason `0x20` after the result was published. This run was
preserved rather than accepted or retried. It motivated the 2.5.6
post-capture requalification state.

## Version 2.5.6 signal-loss run

Fresh sequence 1/run ID 1 passed fully, including exact final healthy IDLE
`C8=0`. FireFly alarms again proved the intended channel-0 outage. Lane 12
alone recorded 8,870,131,729 error-active cycles out of 9,667,809,834 valid
cycles, a fraction of `0.917491`; lanes 13-15 remained zero, and all four
lock-loss counts remained zero. RXUSRCLK2 stayed at 322.260-322.261 MHz. This
confirms sustained lane-local PRBS failure is a strong runtime loss signal,
whereas CDR lock and clock presence are not.

## Version 2.5.6 restart failure

The following unique request, sequence 2/run ID 2, was intended to measure a
single TX-error pulse. It never reached RUN, so no XSDB injection was issued.
After the one permitted recovery reset, only lane 15 had ever locked; the
controller timed out at `LOCK_WAIT` after 1,999,999,999 management cycles and
published atomic summary `0x04000404`. All four power-good, QPLL, user-clock,
and reset-done indications were healthy. The complete result and telemetry
were preserved without retry.

F1 AVTT pages were fault-free (page 0: 1.20093 V, -0.803 A, 32.56 C; page 1:
0.90381 V, -0.219 A, 31.03 C). FireFly byte 86 was restored to `0x00`; the
module reported 37 C and 3.304 V. A subsequent explicit golden-image reload,
PRBS31 configuration, TX/RX reset, and BERT reset produced four clean
Quad-124 links immediately. Each had CDR lock, no electrical-idle indication,
RX/TX reset-done, zero errors, and approximately 77.7 billion checked bits.
F1 was left on the golden image.

## Conclusion and next gate

Do not promote the 2.5.5/2.5.6 one-shot RX-reset recovery into full Milestone
3: it is not repeatable across requests. The next isolated candidate must
first make external acquisition/restart deterministic, likely by coordinating
a bounded full-quad restart or preserving a known-good checker state. Only
then run the deferred sequence-controlled single-error characterization and
choose a sustained-PRBS-failure threshold. Missing-clock detection remains a
separate platform-fault path; it did not respond to this optical outage.
