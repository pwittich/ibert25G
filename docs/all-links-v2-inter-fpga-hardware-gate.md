# All-links v2 inter-FPGA hardware gate

## 2026-10-27 fresh-image 180-second test with cm_interface v1.0.3 — PASS

After separately authorized F1/F2 programming with the same audited BIT hash
listed below, the user authorized one new 180-second bidirectional PRBS31 test
on q221--q234 and explicitly acknowledged safe PRBS31 reception on all outward
FireFly TX paths. The user also expressly selected `cm_interface` v1.0.3,
commit `64260cf23b01c9da987feda1fbf51567240c2c71`. A separate archived wrapper
used direct SSH from lnx4189, verified that clean tag/commit and all seven
remote runtime hashes, and called the unchanged released test procedure.
The released user-facing launchers' v1.0.0 pin was not changed.

Both endpoints started at sequence/ack/run 0/0/0 with matching `0x00020501`
identity, valid required clocks and healthy IDLE/session-off. Session-start
sequence 1 activated all 112 TXs, measurement sequence 2 observed simultaneous
RUN, and normal session-stop sequence 3 succeeded. All 54 fitted receivers at
each endpoint passed with zero errors and zero native lock losses; F1 tested
4,640,547,043,040--4,640,547,043,120 bits/lane and F2 tested
4,640,547,042,800--4,640,547,042,880. F1 globals70/71 and F2 globals96/97 remain
excluded as unfitted. FireFly receivers were not measured.

All requested pre/one-third/two-thirds/post telemetry reads completed. Power
was 189.943/207.787/207.499/208.246 W; the immediate post-stop ADC sample still
showed elevated current. Peak sampled F1/F2 diode temperatures were
52.656/48.031 C, max LGA80D 51.375 C, and max physical FireFly 45 C. A later
settled read returned 189.226 W and F1/F2 diodes 50.406/46.844 C.

Final independent readback confirms both healthy IDLE/session-off
`0x00100000`, sequence/ack 3, run 1, summary `0x00363601`, and required clocks
valid. These new sequences1--3/run1 are consumed. No retry or further
measurement followed. This result also exercises v1.0.3's session commands,
descriptor writes, lane readback and telemetry for this specific procedure.

Evidence:

- `build/diagnostic_archive/all-links-v2-timed-inter-fpga-180s-1793111744850372.log`
- `build/diagnostic_archive/all-links-v2-timed-inter-fpga-180s-1793111744850372.report.md`
- `build/diagnostic_archive/all-links-v2-timed-inter-fpga-180s-1793111744850372.launcher.py`
- `build/diagnostic_archive/all-links-v2-timed-status-1793113074559486.log`

## Result — post-power-cycle retest PASS; original failure retained

On 2026-09-20 two distinct 180-second bidirectional PRBS31 gates were run with
54 fitted direct receivers selected per endpoint. The first gate failed one F2
lane. After the user separately authorized a board power cycle, exact-image
reprogramming, and one new gate, the second gate passed all selected receivers
at both endpoints. The second result validates broad operation of the audited
bitstream and test path after a cold restart. It does not erase the first
failure or establish its root cause.

Both attempts used all-links v2 identity `0x00020501`, BIT SHA-256
`163172d938f5aa87fd606061e75e058f5d7040916d86d4744a206309f970b66f`,
and authoritative `cm_interface` commit
`8e56fdf24c038b64f69f26b55f0facb7c77e0537`.

## Attempt 1 — FAIL

Both FPGAs started fresh at sequence/run 0/0 with valid required clocks and no
retained fault. F1 passed all 54 lanes with zero errors and native lock losses.
F2 passed 53 of 54. Global lane 98 in q231 published
`id_status=0x5862`, saturated errors `0xffffffff`, zero native lock losses,
and `4,640,398,102,160` tested bits. F2 summary `0x01353601` records one
failed, 53 passed, and 54 selected. This failed the zero-error criterion. The
launcher stopped both sessions, and no automatic retry followed.

Pre-run 12-V power was 189.10 W, in-run samples were 207.69 W and 208.43 W,
and post-stop power was 190.16 W. FPGA diode temperatures were 51.0/46.5 °C
before, reached observed maxima 52.5/48.6 °C, and were 51.8/46.5 °C after
stop. All seven LGA80Ds and all six populated FireFly modules returned finite
temperatures.

## Attempt 2 after power cycle — PASS

The board was power-cycled by the user. Both endpoints were then programmed
with the same hash-pinned bitstream and verified fresh at sequence/run 0/0,
identity `0x00020501`, state `0x00100000`, valid required clocks, and no
retained fault. The new 180-second run passed all 54 fitted receive lanes at
both F1 and F2 with zero errors and zero native lock losses. Both summaries
were `0x00363601`. The previously failing F2 global lane 98 passed with
`4,640,546,524,560` tested bits and zero errors.

The power cycle also exposed two valid fresh-process JTAG presentations: the
second bare `xcvu13p` can be target 2 before debug children appear or target 4
after F1 configuration. The exact `all_links_v2_f2` programmer now accepts
only those two positions while still requiring exactly two `xcvu13p` devices
and F1 at target 1. Other image choices retain their existing topology guards.

Pre-run 12-V power was 188.635 W. In-run samples were 206.617 W and 208.059 W;
a settled post-stop status measured 191.032 W. FPGA diode temperatures were
45.781/36.844 °C before, reached observed in-run values of 51.625/47.875 °C,
and were 50.875/47.281 °C in the settled status. All LGA80D and populated
FireFly temperature readings were finite.

Cleanup stopped both sessions. Final F1 and F2 are healthy IDLE/session-off at
sequence/ack 3, run 1, state `0x00100000`, with valid clocks and no retained
platform fault. The second gate's sequences 1–3 and run 1 are consumed; do not
replay them without a new reviewed authorization. One fail followed by one
pass is consistent with a transient board or startup-state issue, but is not
enough evidence to assign that cause or claim comprehensive qualification.

The present global TX enable drove PRBS31 on both link classes. A future
two-bit selector (`FireFly`, `inter-FPGA`) should allow either class or both.

Primary evidence:

- `build/diagnostic_archive/firefly1-all-links-v2-F1-program-1789910389553977.log`
- `build/diagnostic_archive/firefly1-all-links-v2-F2-program-1789910490959855.log`
- `build/diagnostic_archive/all-links-v2-90s-status-1789910584403090.log`
- `build/diagnostic_archive/all-links-v2-90s-inter-fpga-180s-1789910593150881.log`
- `build/diagnostic_archive/all-links-v2-90s-inter-fpga-180s-1789910593150881.report.md`
- `build/diagnostic_archive/all-links-v2-90s-status-1789910799743060.log`
- `build/diagnostic_archive/all-links-v2-90s-inter-fpga-180s-1789909592360531.log`
- `build/diagnostic_archive/all-links-v2-90s-inter-fpga-180s-1789909592360531.report.md`
- `build/diagnostic_archive/all-links-v2-90s-results-1789909866185159.log`
- `build/diagnostic_archive/all-links-v2-90s-status-1789909817891128.log`
