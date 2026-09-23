# Fixed one-hour all12 F1-to-F2 PRBS31 soak

FINAL RESULT: PASS. All12 zero errors/native lock losses; lanes0–10 each
92,810,973,590,800 bits / 1,160,137,169,885 valid cycles; lane11 one cycle
less (92,810,973,590,720 bits). Summary000C0C01, F2run4. Final healthy IDLE,
F1seq11/run0 and F2seq15/run4, sessions stopped, required clocks valid.
Evidence: build/diagnostic_archive/firefly1-v5-managed-oneway-results-soak1h-1789604293332380.log.
The running-state descriptions below are historical. Start remains consumed.

Explicit user authorization: one hour, existing approved launcher methods.
No programming, reset, arbitrary duration or retry. Same audited v5 bothsites.

Launcher: `python3 scripts/board_firefly1_v5_managed_oneway.py`
with deploy-soak1h/start-soak1h/status-soak1h/results-soak1h. New exclusive
remote directory `/tmp/firefly1-v5-soak1h-20260916`; hashes verified eachcall.
Detached remote worker owns MCU polling; status/results read worker.log only.
Do not run competing UART helpers/manual MCU commands during this worker.
Started/worker/passed/failed sentinels are exclusive, never delete/replay.

Preflight F1seq/ack9run0,F2seq/ack12run3,healthy IDLE/version20304, clocks,
no retained fault; prior all12run3 clean publication revalidated.
Start F1sessionseq10/run0 and F2sessionseq13/run3,maskFFF,3900000ms(65min).
After20s settle and RSSI observation submit exactly one F2seq14/run4
externalPRBS31 measurement3600000ms(1hour),maskFFF. RSSI not a passgate.
Firmware elapsed measurement timer defines the hour, not operator walltime.

Poll at30s in RUN (10s before first RUN), identity/session/clock/sourcehealth
and exact request/published-state guards. RUN retains publishedrun3/ack13;
completion publishesrun4/ack14. No renewal. Timed completion bound3660s;
12s cleanup observation. Final all12status1800+lane,zeroerrors/native losses,
80bits/cycle and nominal322265625*3600cycles±1%,stable across stops required.
Stop F2seq15/run4 and F1seq11/run0 only when safe IDLE with exact predecessor;
pre-receive F2stop15/run3 allowed aftersession13. Fault/busy/ambiguous states
are preserved, no abort/reset/replay; hardwarelease bounds PRBSsessions.
Full records/diagnostics after stopattempts, compact fault/response snapshot
before. Worker writes PASS/FAIL marker and log; status never starts requests.
46 offline tests passed before deployment, including simulatedhour and failure.

STARTED once; autonomous worker PID108549. F1sessionseq10 and F2sessionseq13
accepted. F2receive seq14 submitted at epoch1789596622.557; confirmed RUN
state00120002,ack13,publishedrun3 at elapsed0.138s. Expected measurement end
is approximately epoch1789600223, followed by publication/cleanup/validation.
No final PASS yet. start-soak1h is consumed; never invoke it again.
Worker log `/tmp/firefly1-v5-soak1h-20260916/worker.log` on Apollo; monitor only
via status-soak1h (no MCU access). Local start evidence:
`build/diagnostic_archive/firefly1-v5-managed-oneway-start-soak1h-1789596596349399.log`;
initial RUN evidence `firefly1-v5-managed-oneway-status-soak1h-1789596630123214.log`.
Settled RSSI all12 high, approximately902–2008uW, includingRx02=1164uW.
