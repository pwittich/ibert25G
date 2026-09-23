# FireFly-1 RX channel mapping — 2026-09-16

## Hardware context and method

User manually loaded golden IBERT on F1 and F2. Confirmed optical wiring for
this test is F1_1 TX → F2_1 RX; a bidirectional connection must not be assumed.
Golden PRBS31 works on eleven F2 lanes; X0Y13 was already NO LINK. Working F1
TX settings reported by user: TXDIFFCTRL 01001 (GUI 630 mV), zero pre/postcursor.

Direct MCU ProgCom reads/writes through cm_interface raw FireflyRx at logical
address 0x2B (FF device index 11), bypassing incorrect symbolic RX controls.
Manufacturer ECUO 25G x12 Rev.4 Table40 defines disable at bytes52–53,
1=disabled. Table52 defines page1 RSSI at206–229, Rx11 first, big-endian,
0.1 uW/count. Raw sequence evidence:
`build/diagnostic_archive/firefly1-rx-rssi-mapping-1789588910.jsonl`.

Each channel was disabled singly for approximately two seconds, read back,
sampled for RSSI, and restored in a finally block with mask verification.
All twelve original-mask restorations returned 0000. No FPGA reset/reload,
IBERT controls, CDR controls, or other module controls were changed.
User observed the affected GTs marching backward from X0Y15 to X0Y4;
the prior separate Rx00 pulse specifically disturbed X0Y15 and recovered.
Rx02 was already weak/non-linking, so its active transition cannot be
established by these RSSI samples; its GT association follows the observed
reverse ordering and exclusion.

## Mapping and samples

GT column lists Y in GTYE4_CHANNEL_X0Y. Power values are uW. RSSI addresses
are byte offsets on upper page1. The table's final column is the first
post-restoration sample, not a guarantee of settled recovery.

| Datasheet RX channel | Disable byte/bit | RSSI bytes | GT Y | Quad | Before | Disabled | First restored |
|---|---|---|---|---|---:|---:|---:|
| 0 | 0x35, bit 0 | 228–229 | 15 | 123 | 1173.9 | 29.4 | 1192.7 |
| 1 | 0x35, bit 1 | 226–227 | 14 | 123 | 1415.1 | 45.7 | 1426.3 |
| 2 | 0x35, bit 2 | 224–225 | 13 | 123 | 61.2 | 61.2 | 61.2 |
| 3 | 0x35, bit 3 | 222–223 | 12 | 123 | 998.8 | 0.0 | 1017.7 |
| 4 | 0x35, bit 4 | 220–221 | 11 | 122 | 1357.1 | 45.9 | 1367.8 |
| 5 | 0x35, bit 5 | 218–219 | 10 | 122 | 1462.1 | 4248.9 | 1457.5 |
| 6 | 0x35, bit 6 | 216–217 | 9 | 122 | 1929.4 | 0.0 | 1923.3 |
| 7 | 0x35, bit 7 | 214–215 | 8 | 122 | 1593.1 | 3055.9 | 1588.6 |
| 8 | 0x34, bit 0 | 212–213 | 7 | 121 | 1131.8 | 0.0 | 1157.2 |
| 9 | 0x34, bit 1 | 210–211 | 6 | 121 | 1728.6 | 47.5 | 1724.9 |
| 10 | 0x34, bit 2 | 208–209 | 5 | 121 | 1614.1 | 39.9 | 1608.6 |
| 11 | 0x34, bit 3 | 206–207 | 4 | 121 | 1668.1 | 2827.9 | 57.1 |

Thus test lane = 11 − optical channel; GT Y = 15 − optical channel.
The MCU power display matches datasheet channel numbering in direct-read
comparison. The earlier claim that its labels were reversed was incorrect.

## Limits and recovery observation

Eleven RSSI entries respond at the expected byte pair; Rx02 remains 61.2 uW.
Disabled readings are not always near zero: Rx05 and Rx07 rise anomalously,
then recover. This identifies monitor correspondence but not calibrated
optical power while disabled.

Rx11 rises during disable, then initially reads 57.1 uW after restoration.
Two subsequent read-only samples return 42.7 uW while the disable mask is
confirmed 0000; all other formerly healthy RSSI readings are back near baseline.
No further agent reset/write was attempted. The user subsequently confirmed
all formerly working links recovered after the sweep, and clearing/resetting
IBERT counters showed no additional errors. This closes the GUI link-recovery
question, but is not a new RSSI measurement: do not rewrite the raw low-Rx11
samples as normal. Rx02 remains 61.2 uW in the recorded measurements.

## Golden comparison closeout (user-reported)

- F1 quads 121, 122 and 123 all pass near-end PMA with PRBS31.
- F1→F2 external PRBS31 works on eleven lanes with TX swing 630 mV
  (TXDIFFCTRL 01001), pre/postcursor both 0x0000. PRBS7 acquisition sensitivity
  was reported but not independently characterized.
- F2 X0Y13 remains NO LINK externally despite the user's RX reset and TX
  drive scan, but the user now confirms this lane passes near-end PMA PRBS31.
- No final GUI configuration dump, observation duration, bit denominator or
  exact manual-programming artifact hash was captured. The image is golden
  according to the user; it was not reprogrammed by the agent for this test.
  X0Y13's final loopback setting after the local check is not known.

The failure is specific to the external path/settings under these conditions,
not a general inability of F2 X0Y13 to run PRBS31. Low Rx02 RSSI is supporting
evidence but does not distinguish fiber, TX module, RX module, board path or
external GT settings. The golden test is not full twelve-lane qualification.

Next proposed managed work: compare golden GT drive settings to the routed
managed target, separate RX-test faults from independent TX-session shutdown,
and review selection-aware acquisition with measurement mask 0x0DFF (exclude
logical lane 9) before a reduced one-way F1→F2 gate. No new candidate or gate
has been implemented/run. A reduced-mask pass must never be presented as
twelve-lane qualification. The later one-way wiring clarification also means
the historical bidirectional v5 gate had an invalid physical-topology premise.
