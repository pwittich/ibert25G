# FireFly-1 v5 independent TX sessions

**Later hardware update:** user has manually replaced v5 with golden IBERT
on both sites. Confirmed wiring is F1_1 TX → F2_1 RX only, not the originally
assumed bidirectional path. Golden has eleven working external links; F2
X0Y13 fails externally but passes PMA PRBS31, with optical Rx02 RSSI 61.2 µW.
All channel-mapping disable writes were restored and user confirms working
links recovered without new errors after clearing counters. See
[mapping and golden closeout](firefly1-rx-channel-mapping.md). The following
v5 live-state records are historical; preserve their archived evidence.

Identity: FW/HW `0x00020304`. Default-off `ENABLE_TX_SESSION` preserves
historical targets. Build/audit and both PMA gates pass. The first dual external
gate failed; no second baseline or retry occurred. Both TX sessions are off.

## Contract

TX sessions generate PRBS31 on all twelve FireFly-1 lanes independently of
receive requests and RX clocks. Enable reaches each quad through a two-stage
single-bit TXUSRCLK2 synchronizer. External receive tests require an active
session and PRBS31; PMA tests require no active session and retain their old
per-lane TX controls. No lane wiring, GT configuration or reference clocks change.

Session commands use the existing request/response sequence protocol:

| Mailbox command | Meaning | Duration | Mask |
|---|---|---|---|
| `2` | Start TX session | 1–86,400,000 ms | `0xFFF`, other words zero |
| `3` | Stop TX session | zero | `0xFFF`, other words zero |
| `0x10501` | External receive PRBS31 measurement | measurement ms | selected managed lanes |
| `0x11501` | Historical PMA measurement | measurement ms | selected managed lanes |

Session command timeout field must be zero. Response code 0 means accepted,
1 means rejected. Session commands consume request sequences but NEVER
increment measurement run ID or overwrite frozen lane records/summary.
They require idle and do not renew an active session. Stop while busy is
rejected. Software must wait for command response before submitting another.

AXI registers: 0x100 write-one-action start=1/stop=2; 0x104 status;
0x108 remaining milliseconds; 0x10C configured duration. Status bits:
0 active, 1 expired/platform-terminated (retained), 2 last command rejected,
3 capability. The same four bits occupy mailbox C8 bits 17–20. Existing
lower status bits, FE diagnostics, clock monitor and normal result layout
are unchanged. Expiry clears on the next accepted session start, not on a
stop/read. A new session clears rejected status; each accepted stop clears
rejected status. There is no extension/renewal command.

The watchdog counts from accepted TX start using clk_200, independent of
RX clocks, MCU/UART, firmware interrupt state or local measurement. Expiry
and aggregate platform faults turn TX off. In this target the aggregate
includes PRBS acquisition faults, not only physical GT faults; see the
hardware investigation below. Expiry during an external run
uses the existing deterministic platform-failure publication path (including
when RX clocks are missing). Management reset clears the session. A normal
receive abort leaves the independent TX session active; the operator must
stop it after both receive engines are idle, or the watchdog expires.

## Validation/build approach

The actual-engine dual-endpoint test reproduces v4's early-TX-stop race with
equal durations and staggered acquisition. With sessions enabled, both
receivers pass while TX remains enabled through both publications. Tests
also cover duplicate-start/busy-stop refusal, explicit stop, idle expiry,
unchanged frozen results, no-session rejection, missing RX clock expiry
with failed publication, platform-fault termination and reset.
The serial GT behavior is modeled, not an analog/CDR simulation.

Initial session regression:
`build/logs/run_firefly1_v5_session_sim-20260916T171122Z.log`.
Final expanded session regression (including v5 PMA, abort semantics and
zero/over-limit watchdog duration refusal):
`build/logs/run_firefly1_v5_session_sim-20260916T172334Z.log`.
All 13 historical regression checks pass:
`build/logs/run_milestone3_unit_sim-20260916T171033Z.log`.
Compressed build and independent routed audit pass.
Synthesis-warning review also found the pre-existing scalar quad reset was
zero-extended into each four-lane slice. V5 explicitly broadcasts it to all
four lanes; default-off historical mode keeps the exact prior mapping.
This is a v5-only correction, not a claim that v4 tested all reset paths.
The actual group-wrapper wiring regression passes for all three quads in
both historical and v5 modes (the quad itself is stubbed in this wiring test):
`build/logs/run_firefly1_reset_fanout_sim-20260916T172109Z.log`.
The first v5 implementation was intentionally interrupted before a bitstream;
its synth checkpoint/logs are archived in
`build/diagnostic_archive/firefly1-v5-before-reset-fanout/`.
The replacement clean-synthesis/incremental-implementation launcher log is
`build/logs/rebuild_firefly1_v5_reset_fanout-20260916T172040Z.log`.
The new session CDC first stage also now has a direct registered source,
without an unnecessary combinational management-reset gate.
Firmware SHA256: `37972efc9f7cd65ff2bd2569bd6b776bec0263d2ad00a32e9c3de2975ab06528`.
Bitstream SHA256: `a1014f7d2451045ae6fbae66f0d2d1faef60d74c4a74190584be20b6a821f28e`.
Routed checkpoint SHA256: `7d29be615970170d32abfd2e6ca2c497e9494d5117749e9cfeb2c3b80f5123d1`.

Independent audit log:
`build/logs/audit_firefly1_loopback_v5_bitstream-20260916T173437Z.log`.
WNS/WHS +0.372/+0.003 ns; zero routing or DRC errors; required clocks,
48 descriptor bounds, three bus-skew constraints and actual-driver skew,
12 channels/three commons, golden RX attributes/polarity, cleanup registers,
management-clocked watchdog, six TX-domain synchronizer registers and all
twelve reset destinations pass. The three new session crossings are CDC-3
two-stage ASYNC_REG paths. Existing non-session CDC/methodology caveats and
the generic-I2C RPBF-3 warning remain; this is not a globally clean CDC claim.
The first audit stopped on a flattened-away hierarchical reset pin query;
the corrected audit checks actual reset fan-out to each lane's sequential
descriptor-freeze enable, with exact quad/lane ownership. No RTL/bit changes
were needed for this query correction.

Final checkpoint reuse: 81.34% of cells, 60.28% of nets, 100% of ports.
The corrected clean-synthesis through compressed-bit build took about ten
minutes and retained both top synthesis and routed checkpoints.

Checkpoint workflow clones the completed v4 project/IP cache into a separate
v5 project, verifies unchanged IP identities and source ownership, replaces
only application firmware, rebinds hand-written RTL/XDC, and performs clean
top-level synthesis. It disables automatic/incremental synthesis because of
v4's documented omitted-register artifact. Incremental implementation uses
the independently audited v4 routed DCP, SHA256
`c029bd5d51085decd65801b62211db2e3adea9671a098995817246f2a626a835`.
Synthesis and routed checkpoints are retained for resume. Require explicit
session register/synchronizer structural checks in addition to the complete
v4 timing/clock/ownership/descriptor/cleanup checks before any deployment.

## Hardware plan

Preserve v4/run 1 on both sites until the exact v5 artifacts pass independent
audit. Then use newly pinned, separately approved programming and gate choices.
Validate PMA on each new image first. For external tests, start finite TX
sessions on both endpoints before submitting receive requests. Observe each
request exactly once; acquisition completion need not be simultaneous.
Verify both results before stopping TX. On failures, preserve evidence and
use bounded cleanup without resetting/retrying. Long soak and optical-fault
qualification remain separate gates.

Fixed dual-board launcher `python3 scripts/board_firefly1_v5.py
deploy|status|pma|external` is approved and deployed with remote hash verification.
Five offline protocol tests pass, including wrong identity, refused TX-session
start, failed receive gate without retry, and guaranteed attempts to stop live
idle sessions. A remote exclusive sentinel
prevents replay of each gate, even after an SSH disconnect.

Gate sequence plan on each FPGA: fresh PMA sequence/run 1; session start
sequence 2/run still 1 with 180,000-ms lease; external measurement sequences
3/run 2 and 4/run 3, each 10 seconds with post-cleanup observation; stop
sequence 5/run still 3. On failure, stop sequence 5 is permitted only for an
idle endpoint with a live session and matching acknowledged predecessor;
otherwise hardware expiry bounds transmission. No implicit reset/retry.

## Hardware results and preserved failure — 2026-09-16

Both sites were programmed once with the exact audited v5 bit/ELF. F1 target
1 and F2 target 4 each emitted their own completion marker; both subsequently
reported matching FW/HW 0x00020304, fresh run 0, session off, healthy platform,
and valid full clock maps. Evidence under `build/diagnostic_archive/`:

- `firefly1-v5-F1-program-1789580200951519.log`
- `firefly1-v5-F2-program-1789580285660729.log`
- `firefly1-v5-status-1789580369219484.log`
- `firefly1-v5-pma-1789580376220140.log`
- `firefly1-v5-external-1789580413919944.log`
- `firefly1-v5-status-1789580615266583.log`

PMA sequence/run 1 passed on both: summary 0x000c0c01, twelve nonzero records,
zero errors/native lock losses, healthy post-cleanup observation. F1 all
lanes: 257,808,253,520 bits / 3,222,603,169 cycles. F2 matches except lane 4
has one fewer cycle (257,808,253,440 bits / 3,222,603,168 cycles); do not call
all F2 records equal. The selected acquisition diagnostic has a full
200,000-cycle clean observation on both sites.

Both accepted TX session sequence 2 (run remains 1). External sequence 3
(measurement run 2) then failed:

- F1 completed its measurement with summary **0x04080c01**: lanes 1/3/4/6
  errors = **47/96/57/19**, other lanes zero; all native lock-loss counts zero.
  Lanes 0–3 and 8–11: 257,808,252,000 bits / 3,222,603,150 cycles;
  lanes 4–7: 257,808,251,920 bits / 3,222,603,149 cycles.
- F2 summary **0x0c000c04**, retained PRBS reason 0x80, state 8 LOCK_WAIT,
  sequencer count 1,999,999,999 (10 seconds). The selected failing quad had
  no lanes ever PRBS-locked and selected error active, while QPLL, TX/RX
  clocks and all reset-done/PMA-done qualifiers were healthy. The group
  diagnostic does not identify its quad index. Its twelve 0x2800+lane records
  are synthetic platform failures, **not twelve measured native lock losses**.

Sequence 4 was never submitted. Cleanup accepted F1 stop sequence 5 without
changing run 2 or its frozen failed summary. F2's acquisition platform fault
automatically terminated its session; no stop/reset/retry request was sent.
Final F1 request/response 5, run 2, C8=0x00100000, healthy platform. Final F2
request/response 3, run 2, C8=0x00150000, retained platform fault and session
termination flag, TX inactive. **Both `pma` and `external` launchers are
consumed. Do not clear their sentinels, rerun, reset or reload silently.**

All required clocks remain valid (100/325 MHz and FF1 reference ~322.260 MHz).
Final MCU temperatures F1/F2 28.171875/27.421875 C; AVTT
1.2021484375/1.203125 V.

### Investigation and remaining uncertainty

Read-only optics inspection found the installed `tf` preset sparse and
renumbered: its location labels are not a safe physical address map. The
helper now uses the installed generic 20-endpoint mapping directly: F1_1
Tx/Rx 0x20/0x21, F2_1 Tx/Rx 0x2A/0x2B. No module control/page/reset write or
clear-on-read alarm access occurred. Successful controls evidence:
`firefly1-v5-optics-1789580584033599.log`; API/mapping evidence:
`firefly1-v5-optics-api-1789580560742766.log`.
All four modules were page 0, matched ECUOT12251000513/ECUOR12251000513 parts,
controls 0x34/36/38/3A read 0000 and 0x4B read FF00; temperatures were
32/38/29/35 C for F1 Tx/Rx and F2 Tx/Rx. These reads exclude an obvious
asymmetric disable setting, but do not prove optical signal/CDR health during
acquisition. Keep CDR control bytes raw rather than infer twelve-channel
semantics from the installed API's incomplete single-byte helper.

Source inspection confirms a remaining failure-mode coupling:
`quad_fault = quad_controller_fault | prbs_controller_fault`, and the TX
session aborts on the resulting aggregate platform fault. Thus F2's RX
acquisition timeout shuts down its TX, potentially contaminating F1's later
measurement/capture. The records lack synchronized event timestamps, so this
is a plausible explanation of F1's small errors, not a proved cause. It does
not explain why F2 initially failed to acquire.

The above cross-endpoint contamination hypothesis preceded the later wiring
clarification. F2 TX was not connected to F1 RX in the confirmed topology,
so it is not an established explanation of the F1 result. The aggregate
fault coupling still exists in RTL and matters for future supported topologies.

The subsequent golden comparison/mapping is complete enough to resume managed
investigation. Proposed next work: compare golden drive settings; distinguish
fatal physical GT faults from RX-test faults for TX-session lifetime; simulate
an endpoint failing acquisition while its peer measures; and review an
explicit eleven-lane mask 0x0DFF before a one-way F1→F2 gate. None of these
new changes/tests has run. Do not claim they alone repair F2 acquisition or
that the bad external lane is qualified. The consumed v5 gates stay consumed.
