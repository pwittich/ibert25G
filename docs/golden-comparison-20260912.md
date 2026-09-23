# Golden IBERT comparison — 2026-09-12

The user authorized returning to golden IBERT after the successful post-cycle
v270 baseline, and explicitly allowed the historical uncompressed bitstream.
This is a one-artifact exception, not a change to the compressed-build policy.

Image: `build/vu13p_ibert_25g.runs/impl_1/top.bit`, SHA-256
`e6f49cef8ff91381ca2470c9b4860e90d13ea5ed98e48562ff14288365541e83`.
It is the unchanged historical `src/top.sv` golden image, not a managed image
and has no matching MicroBlaze ELF requirement. Existing historical reports
record WNS +0.258 ns, WHS +0.009 ns, zero routing errors and passing bus skew;
DRC has warnings/advisories but no errors. This is not global CDC signoff.

The compressed re-emission Tcl was prepared but never launched; no alternate
golden image was built. Original artifacts remain unchanged.

Before programming, the result dumper confirmed v270 FW/HW 0x00020114,
sequence/run ID 1, healthy engine IDLE, summary 0x00040401, and four clean lane
records. Complete prior evidence remains in `v270-post-power-cycle.md`.
FPGA temperatures F1/F2 were 25.5/24.5 C. F1AVTT/CC status was clear on both
pages, Vout 1.20263671875/0.90625 V. FireFly outputs enabled, CDR enable FF,
rate select 00, LOS/CDR LOL FF/FF on both x4 modules. No cabling, clock-source
or FireFly control changes were made.

Programming uses XSDB on lnx4189 and `build/program_golden_comparison.tcl`,
which verifies the historical bitstream hash before selecting F1 target 1.
The subsequent script `scripts/golden_q124_baseline.tcl` scopes the test to
one F1 Quad-124 group with four lanes. It follows the previously successful
external PRBS31 TX-reset, RX-reset, BERT-reset procedure and then collects
results after a 10-second observation, without a fault stimulus or retry.

Programming completed successfully (XSDB exit 0). F1 target 1 now exposes a
Legacy Debug Hub (target 5); F2 remains target 4.

## Result: clean four-lane golden baseline

The scoped hardware-manager script completed with exit 0. Target discovery
identified MGT_X0Y16–MGT_X0Y19 under F1 Quad_124 before control writes.
The observation started at Unix time 1789258287 and was captured at 1789258297.

| Lane | Bit errors | Received bits |
| --- | ---: | ---: |
| X0Y16 | 0 | 259443308320 |
| X0Y17 | 0 | 259444547360 |
| X0Y18 | 0 | 259443831680 |
| X0Y19 | 0 | 259440569920 |

All four reported RXCDRLOCK=1, RXELECIDLE=0, RXRESETDONE=1 and TXRESETDONE=1;
RXUSRCLK2 frequency count was 6720 (raw IBERT register representation, not
direct kHz). Native RXPRBSLOCKED is not a golden fabric-checker pass criterion.
The displayed BER around 3.85e-12 with zero errors is not a measured nonzero
error rate and is not a 95% confidence bound.

Full result log: `build/golden-comparison-20260912.log`, SHA-256
`e941d8e01852cc95e853dd09eea1d2b0f969e04660498d0a1517fb22179931b8`.
F1 remains golden with these links continuously running external PRBS31;
there was no second test/reset, module stimulus, or automatic v270 reload.

Post-test helper snapshot at Unix 1789258324.6377778: F1_5 LOS/CDR LOL FF/00,
F1_6 FF/0F, module temperatures 40/41 C. Both had byte 86=00, byte 98=FF,
rate select 00, masks 100/102=00 and status byte 2=00. Supply statuses stayed
clear, Vout 1.20263671875/0.905029296875 V, raw currents 23.90625/11.859375 A,
regulator temperatures 41.1875/40.6875 C. Golden enables more GT resources
than isolated v270, so its load should not be compared as identical.

Post-test clock helper: valid 0x434DA501, generated clocks 100/325 MHz,
primary references 322260–322261 kHz. The r24–r38 group remains approximately
320637–320639 kHz. In golden, r38 is lf_r1_ab again, NOT managed RXUSRCLK2.

## Follow-up module snapshot

At Unix time 1789259367.4787405, the second diagnostic-helper read returned
F1_5 LOS/CDR LOL **00/00**, status byte 2=02, temperature 41 C. F1_6 returned
0F/0F, status 00, temperature 42 C. Both retained outputs enabled, CDR enable
FF, rate select 00, masks 100/102=00, page 00. Supply statuses were clear;
Vout 1.204345703125/0.90380859375 V, raw currents 24.3125/11.546875 A,
regulator temperatures 42.1875 C. Post-test JTAG FPGA temperatures were
F1 53.3 C, F2 24.5 C. These are distinct from the module temperatures.

Thus F1_5 LOS is no longer persistently FF in the running golden setup.
The earlier FF/00 sample can include retained flags; do not treat latched
alarm samples as instantaneous link-state readings. F1_6 was not the scoped
four-lane comparison and its flags do not describe F1_5/Quad-124.

Both v270 and golden passed their short clean baselines. This does not isolate
an intermittent hardware versus managed-RTL cause. The changed module CDR LOL
is suggestive but confounded: golden is transmitting continuously, while the
v270 alarm snapshots were taken in IDLE. Next proposed comparison is timed
alarm sampling during v270 RUN and after return to IDLE, not a conclusion
that module alarms alone prove a firmware defect. Persistent FF/FF in v270
IDLE remains to be reconciled against a sample taken during active measurement.
