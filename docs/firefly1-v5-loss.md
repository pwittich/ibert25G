# v5 controlled optical interruption characterization

## Executed result — inconclusive automatic mapping gate

Started once (worker109632); start-loss is consumed and must not be replayed.
Evidence: build/diagnostic_archive/firefly1-v5-managed-oneway-results-loss-1789604713240431.log.
All intended requests completed, no transport errors. Raw F1 TX part ID
ECUOT12251000513; original control mask0000 restored/read back after
10.010531 seconds. F2seq17/run5 published normal-stop summary010B0C01.

RX02 RSSI baseline935.5uW, disabled samples549.7/535.6/532.9uW at1/5/9s,
restored1037.7uW after20s. Other11 channels remained near their baselines.
The predeclared mapping criterion required both late samples below233.875uW
(25% baseline); none met it. Worker therefore recorded FAIL with
`RSSI mapping inconclusive: []`. Do not change the archived criterion to
retroactively pass the run. The cause of residual RSSI is not established;
this is not proof of complete optical extinction or a DUT functional failure.

Lane9/X0Y13 alone: status5809, errorsFFFFFFFF (saturated), native losses0,
1,546,849,535,760 tested bits / 19,335,619,197 valid cycles. Other11 lanes
zeroerrors/losses, status1800+lane. Lanes0–7 each1,546,849,535,680 bits /
19,335,619,196 cycles; lanes8/10/11 match lane9 denominators. No retained
platform fault. Native counters did not report lock loss despite measured
lane-local corruption. Saturation prevents inferring error cessation after
restoration from this run. RSSI+isolated errors support TX02→RX02→X0Y13,
but automatic mapping gate remains failed/inconclusive.

Both explicit stops succeeded: final F1seq13/run0 and F2seq18/run5 healthy
IDLE/C8=00100000, session off, required clocks valid; original module mask
verified again. No recovery baseline, sweep, retry, reset or programming.
Next decision: review this evidence and authorize a separately sequenced
clean baseline if desired; do not replay this disturbance to force a PASS.

## Reviewed plan and implementation

User authorized agent critique, plan re-evaluation, then execution.
Critique: conditional GO, no rebuild; characterize instead of claiming loss/
recovery qualification. Existing mapping is receiver-only; derive TX02's
destination from all12 RSSI. V5 runtime-integrity detector is off. Healthy
quad123 native live locks are not visible through the current FE mux.

Fixed approved launcher: python3 scripts/board_firefly1_v5_managed_oneway.py
deploy-loss/start-loss/status-loss/results-loss. Exclusive remote directory
/tmp/firefly1-v5-loss-20260916, hash-verified bundle, detached worker. Status
and results read logs only; no competing MCU access while worker runs.

Preflight exact audited20304 bothsites, F1seq11/run0 F2seq15/run4, healthy
IDLE, required clocks/no faults; previous hour records revalidated and its
worker.passed sentinel required. Fixed180s sessionsF1seq12/F2seq16, settle20s,
all12 positive RSSI baseline, F2seq17/run5 externalPRBS31 60s maskFFF.
Confirm RUN, wait5s, confirm still RUN, then disable F1_1 TX02 once for10s.
Raw FireflyTx endpoint0x20 (MCUindex0); datasheet Rev4 Table18 p21 defines
byte53bit2. Preserve original byte and other/reserved bits. RSSI samples
at1/5/9s; 12s SIGALRM interrupts an overlong stimulus body. Finally restores
original byte even on ambiguous ACK, verifies full mask before diagnostics.
This software cannot guarantee restoration after MCU/power/process failure.

Wait20s after restore, sample recovery RSSI, capture all12 publication and FE,
then observe12s. RSSI mapping requires exactly one channel below25% of its
active baseline in both late samples; other channels and restored channels
must exceed50%. These are conservative mapping heuristics, not calibration;
inconclusive RSSI is not automatically a DUT failure. Normal measured records
required; target errors/saturation/native losses expected and recorded. Other
lanes must have clean full-duration records. Synthetic failures cannot prove
neighbor isolation. Safe stops F2seq18/run5 and F1seq13/run0, no reset/abort/
retry. No automatic recovery baseline or sweep; interpret first result.

Offline suite61 tests PASS before deployment. Agent independently reviewed
implementation and approved subject to tests; positive baseline guard added.
Preparation record above predates the executed result.
