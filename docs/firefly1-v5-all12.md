# Managed v5 all-twelve-lane diagnostic

User authorized an all12 ten-second F1-to-F2 PRBS31 gate, a single fresh
repeat if it passes, and planning (not starting) a later soak. No new build,
programming, reset or replay. Actual one-way cabling is unchanged.

Approved launcher: board_firefly1_v5_managed_oneway.py fixed operations
deploy-all12/start-all12/repeat-all12/status-all12. Separate immutable remote
bundle `/tmp/firefly1-v5-all12-20260916`, verified hashes, exclusive per-gate
started/passed sentinels and non-overwriting evidence. Repeat requires the
first passed sentinel AND exact live predecessor/publication checks.
42 offline tests passed before deployment.

Both sessions use maskFFF/180s. RSSI observed at1/5/10/20seconds, never a
pass threshold; platform/session/clock health required. One F2 ten-second
receive request per gate, maskFFF, including test lane9/GTX0Y13/opticalRx02.
Normal summary000C0C01, all12 selected, zeroerrors/native losses,80bits/cycle,
duration within1%, and stable publication across safe stops required.
Observe12seconds after publication; faults preserved, no blind stop/reset
of faulted/busy/ambiguous endpoints, bounded hardware lease remains fallback.

|Gate|F1 prior/start/stop; run|F2 prior/start/RX/stop; run|
|---|---|---|
|First|5/6/7;0|6/7/8/9;1→2|
|Repeat after PASS|7/8/9;0|9/10/11/12;2→3|

First gate PASS, F2receive sequence8/run2, summary000C0C01. All12 lanes,
includinglane9/X0Y13, have exactly257808266560bits/3222603332cycles, zero
errors and native lock losses. Stable across explicit stops; F1seq7/run0,
F2seq9/run2, bothhealthy IDLE,PRBSsessionsoff,no retained faults.
Evidence: `build/diagnostic_archive/firefly1-v5-managed-oneway-start-all12-1789593261132194.log`.
RSSI all12 high by5.171seconds, includingRx02 about1095uW. No image/drive
change or reload. First start consumed.

Repeat PASS: F2sequence11/run3,summary000C0C01,all12 zeroerrors/native losses.
Lanes0/2 recorded257808264400bits/3222603305cycles; all other lanes recorded
257808264480bits/3222603306cycles. Publication stable across explicit stops.
Evidence: `build/diagnostic_archive/firefly1-v5-managed-oneway-repeat-all12-1789593323952075.log`.
Final F1seq/ack9,run0;F2seq/ack12,run3. Both healthy IDLE,C8=00100000,
PRBS sessions inactive,no retained faults,required clocks valid. MCU final
F1/F2 temperatures28.015625/27.578125C;AVTT1.2001953125/1.2021484375V.
Both start and repeat are consumed; do not replay or reload.

X0Y13 now passes two measured external baselines with unchanged v5 drive24.
The reason for the earlier golden failure is not established. These short
diagnostics are not full qualification. Next proposed step is a separately
reviewed longer all12 one-way soak with lease duration exceeding settling,
measurement and cleanup; no soak launched or implicitly authorized here.
