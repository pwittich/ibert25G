# Two-v5 one-way diagnostic — 2026-09-16

## Revised receive diagnostic PASS

User authorized the reviewed follow-up with RSSI observational, not a gate.
Approved launcher gained fixed deploy-receive/start-receive/status-receive
operations using a separate `/tmp/firefly1-v5-managed-receive-20260916` bundle,
exclusive sentinel and hash verification. 37 offline checks passed. The start
is now consumed: no replay, reset, reload or another receive request occurred.

Evidence: `build/diagnostic_archive/firefly1-v5-managed-oneway-start-receive-1789593045630818.log`.
Both sequence4/run0 TX sessions started (maskFFF,180s bound). RSSI at1.168s
still matched the inactive-session reference. At5.246s ALL12 channels were
1022.7–1719.8uW;10.224s/20.247s samples remained high. Rx02 reached about1020uW,
but lane9 stayed excluded. This shows the previous one-second RSSI criterion
was premature; no fixed general RSSI update time is established. Session-off
means PRBS generator off, not an explicit transmitter/laser disable.

One F2 sequence5/run1 external PRBS31 request,maskDFF,10000ms passed with
summary000B0B01. Selected lanes0–4 recorded257808273760bits/3222603422cycles;
selected lanes5–8,10–11 recorded257808273840bits/3222603423cycles. All eleven
had zero errors and native lock losses;80bits/cycle and duration checks passed.
Lane9 record is exactlyid9 with zero counters. No platform first fault.
Post-publication cleanup observation and record stability across stops passed.

Final: F1seq/ack5,run0; F2seq/ack6,run1. Both C8=00100000,healthy IDLE,
PRBS sessions inactive,required100000/325000/322260kHz clocks valid. Final
RSSI returned to the inactive-session reference. Post-test MCU temperatures
F1/F2=28.625/28.3125C;AVTT=1.201171875/1.2021484375V.
No build or TX-swing change was necessary for this eleven-lane baseline.
This does not qualify lane9, all12lanes, reverse direction, or long-duration BER.

## Executed result: RSSI pre-gate failed; no RX request

Evidence: `build/diagnostic_archive/firefly1-v5-managed-oneway-start-1789592769659624.log`.
Both bounded session sequence1 commands succeeded with run0 and active status.
The one-second RSSI snapshot failed first at opticalRx06. All unchanged
channels were Rx06/07/08/09/11 (GTY9/8/7/6/4, test lanes5/4/3/2/0).

| Rx channel | TX off uW | TX on uW |
|---|---:|---:|
|00|29.4|458.6|
|01|45.7|717.8|
|02 (excluded)|61.2|300.2|
|03|0|443.3|
|04|45.9|530.3|
|05|0|319.0|
|06|0|0|
|07|35.2|35.2|
|08|0|0|
|09|47.5|47.5|
|10|39.9|262.0|
|11|42.7|42.7|

Both safe stop sequence3 commands succeeded; final seq/ack3, run0, C8=00100000,
healthy IDLE and no retained faults. All powers returned exactly to the off
reference. No receive doorbell, measurement, reset, reload or replay occurred.
The new start sentinel is consumed; do not repeat it.

Read-only module controls afterward show both F1_1 TX and F2_1 RX disable and
output-disable pairs52/54 are0000, page0; optics evidence
`build/diagnostic_archive/firefly1-v5-optics-1789592807813958.log`.
Thus a left-disabled channel mask is not supported as the cause. V5 fixed
TXDIFFCTRL24 differs from working golden9; drive sensitivity is a concrete
candidate, not proven causation. The RSSI gate used one sample after1second;
Rev4 Table52 specifies units/accuracy but no RSSI refresh interval was found.
Partial/stale update or settling remains possible. This is an optical-presence
pre-gate failure, NOT a failed BER measurement or proof of five broken links.
Any further stimulus needs a new reviewed sequence; preserve this evidence.

## Reviewed fixed protocol

User explicitly deferred golden IBERT capture, restored audited v5 to both
FPGAs, and authorized continuation until tests complete or fail. No new build.
Actual cable is F1_1 TX to F2_1 RX only. Rx02/X0Y13 remains excluded.

New launcher: `python3 scripts/board_firefly1_v5_managed_oneway.py deploy|start|status`.
Remote directory `/tmp/firefly1-v5-managed-oneway-20260916` is new and deployment
refuses an existing directory. Bundle hashes verified before every action;
exclusive start sentinel and evidence prevent replay. No programming/reset.

Fresh FW/HW20304 and seq/ack/run0, healthy IDLE, clocks and no platform fault
required on both sites. F1 and F2 each start session sequence1/run0 using
maskFFF and a180-second lease. Read raw F2 RSSI before/one second after start:
every optical channel except2 must exceed100uW and increase by more than100uW.
This is an optical-presence gate, not BER qualification or calibrated accuracy.
If it fails, no RX request. F2 then receives exactly one sequence2/run1
PRBS31 request, maskDFF,10000ms. F1 receives no measurement request.

Success requires summary000B0B01, eleven selected clean records with bits=
80*cycles and ten-second duration within1%, and lane9 unselected/zero counters.
Physical faults remain unmasked. Observe12seconds after publication. Preserve
raw results/diagnostics before safe stop sequence3 on both; F1 run remains0,
F2 run1 on completed measurement. On failures, attempt each safe idle stop
independently; do not reset/abort/replay a busy/faulted/ambiguous endpoint.
Hardware lease bounds TX in those cases. Failed acquisition synthetic records
must not be interpreted as measured BER or native lock losses.

Reuses tested Diagnostic primitives from held golden-F1 helper; that helper's
standalone release remains false. New protocol has separate identity, directory
and authorization, not an expansion of consumed historical dual-board gates.
26 combined offline tests pass before deployment.
