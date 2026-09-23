# v5 scoped closeout — PASS

User scope: MCU alarm-latching implementation is outside this project;
channels have already been qualified and are not being requalified here.
No long soak, new FPGA image, new optical stimulus, or MCU change is needed.

Agent critique approved exactly one fresh-request recovery smoke check,
with the explicit limit that it cannot establish automatic in-run recovery
or the instant when the interrupted lane recovered. Normal controller
acquisition/cleanup behavior still applies. The main agent adopted this
scope and added read-only physical-disable checks before/after the run.

New fixed operations in the approved managed-oneway launcher:
deploy-closeout/start-closeout/status-closeout/results-closeout. Exclusive
directory /tmp/firefly1-v5-closeout-20260916, hash-verified payloads, detached
worker111012, serialized MCU, no replay/reset/reload.76 offline tests passed.
Prior alarm worker completion and exact F1seq15/run0,F2seq22/run7 checked;
run7 preserved in preflight log before publishing the new measurement.

F1 session16, F2 session23, both180s;20s settle; one F2seq24/run8 external
PRBS31 maskFFF10s. Summary000C0C01, all12 status1800+lane and zero errors/
native losses. Lanes0–7 each257,808,259,200 bits /3,222,603,240 cycles;
lanes8–11 each257,808,259,280 bits /3,222,603,241 cycles. Observed12s cleanup,
then explicit safe stops. Frozen records unchanged across stops.

Final F1seq17/run0,F2seq25/run8, healthy IDLE/C8=00100000, sessions off,
required clocks valid, no retained faults. F1 TX disable, F2 RX disable and
F2 RX output-disable masks all0000 before/after. No module-control writes or
alarm reads in this smoke test. start-closeout is CONSUMED; no more tests
are pending under this plan.

Evidence: build/diagnostic_archive/firefly1-v5-managed-oneway-results-closeout-1789610748542168.log.

Conclusion: unchanged auditedv5 can reacquire and measure all12 lanes cleanly
after the latest interruption, without external reset/reload. The prior
module-CDR-LOL / FPGA-native-loss-counter mismatch remains documented in
firefly1-v5-alarm.md. This does not supersede prior channel qualification,
prove automatic uninterrupted recovery, or claim reliable MCU event history.
