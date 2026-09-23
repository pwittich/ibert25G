# v5 TX02 LOS/CDR-LOL observation

## Final result: observation completed

Clean recovery baseline F2seq20/run6 PASS: all12 zero errors/native losses,
summary000C0C01 (about257.808e9 bits/lane). This establishes recovery from
the preceding disturbance without FPGA reload/reset, not recovery from the
new disturbance below.

F2seq21/run7: TX02 disabled once10.074281s; raw original0000 restored and
verified. RX02 CDR LOL was004 in all three disabled samples (1/5/9s), with
all other channel bits clear. Pre-stimulus reads were000. Immediate restored
sample retained004;5s and20s restored samples read000. LOS was000 throughout;
competing clear-on-read polling means zeros cannot establish absence of LOS.
RX CDR was enabled0FFF and alarm masks0000; no monitoring controls changed.
RSSI RX02 during disable548.2/532.6/535.3uW, restored1032.9uW.

Normal-stop summary010B0C01, all12 equal1,546,849,564,400 bits /
19,335,619,555 valid cycles. Only lane9/X0Y13 has saturated errorsFFFFFFFF,
status5809; other11 lanes clean. All native FPGA loss counters remain0,
no retained platform fault. Thus module CDR-loss indication was captured
while FPGA native loss counters did not record it. Saturation means this
record cannot establish clean BER after restoration. Not full qualification.

Both sessions stopped successfully: F1seq15/run0, F2seq22/run7, healthy
IDLE/C8=00100000, required clocks valid, stable publication. No new baseline
after this interruption. start-alarm consumed; no replay/reset/reload.
Final evidence: build/diagnostic_archive/firefly1-v5-managed-oneway-results-alarm-1789609353476341.log.
An earlier results read1789609342322424 occurred during final worker
validation and returned pending, not a hardware failure; no start was repeated.

## Protocol and preparation history

User authorized the follow-up test after identifying clear-on-read contention.
MCU source at /nfs/cms/tracktrigger/wittich/cmtest/cm_mcu shows MonitorTaskI2C.c
reads hardware flags and calls storeData on each pass; MonI2C_addresses.c
F2 setters assign (not OR) cached LOS/CDR LOL values. This source inspection
is not verification of the exact installed MCU binary. cm_interface MCU API
has no exposed selective FireFly-alarm pause or accumulated event history.
We do not halt monitoring, take a long bus lock, or change alarm masks.
Positive direct reads provide evidence; zero samples cannot exclude a loss
because another reader may consume latched flags. No RSSI percentage gate.

Fixed approved launcher board_firefly1_v5_managed_oneway.py operations
deploy-alarm/start-alarm/status-alarm/results-alarm use new exclusive remote
directory /tmp/firefly1-v5-alarm-20260916, hash verification and detached worker.
Only log reads while worker owns MCU UART. No arbitrary duration/path/stimulus.
71 offline tests passed before deployment. No programming or firmware changes.

Preflight F1seq13/run0,F2seq18/run5, exact audited20304, healthy IDLE/no fault.
Explicit TXindex0 and RXindex11. Require TX/RX enabled, RX02 CDR enabled,
capture masks without changes. Fixed180s sessionsF1seq14/F2seq19; settle20s.
Archive alarm history; one clean10s all12 F2seq20/run6 baseline must pass.
Observe12s then sample alarm history, wait1s/recheck RX02 clear. Only then
submit one60s all12 request F2seq21/run7; observeRUN and wait5s/recheck.
Raw TXbyte53bit2 disabled once10s using existing finally-restoration helper.
Sample raw2-byte LOS7–8 and CDRLOL20–21 at1/5/9s plus RSSI; restore original
byte/mask even if a disable ACK is lost.12s alarm guards stimulus body.
Read alarms immediately after restore,5s and20s later. First restored read
is retained-history evidence, not proof of continuing fault. Complete all12
records, neighbor isolation and native-loss counters; target saturation allowed.
No post-interruption clean baseline or automatic retry. Stops F1seq15/run0,
F2seq22/run7 (also permitted after session19/run5 or baseline20/run6).
Fault/busy/ambiguous states preserved; bounded leases, no resets or aborts.

Started once, worker110343. start-alarm CONSUMED.
Start evidence firefly1-v5-managed-oneway-start-alarm-1789609215573495.log.
Initial hardware RX controls: disable0000/output-disable0000/CDR-enable0FFF,
LOS-mask0000/CDR-mask0000. Baseline submitted; result pending.
