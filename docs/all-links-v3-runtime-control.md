# All-links v3 runtime quad control

Separate target `0x00020502`, based on preserved commit `34c73bb`, on
branch `feature/all-links-v3-quad-control`. **Static qualification passed; unreleased for hardware.**
V2 source behavior, programming pins and archived artifacts remain intact.

## Runtime behavior

Each FPGA has independent 28-bit TX and RX masks. Bits 0–13 select q121–q134;
bits 14–27 select q221–q234. Each bit covers all four lanes. Both masks start
at zero. No measurement or session is accepted before configuration succeeds.

TX disable asserts TXELECIDLE after TXUSRCLK2 synchronization and overrides
both PRBS selection and error injection. This does not command FireFly optical
disable. RX disable quiesces acquisition, checking and lane protocol. Clocks,
PLLs and optical modules remain powered; this is not a power-saving mode.

Configuration requires IDLE, sessions off and no pending snapshot transfer.
Masks cannot change during acquisition, measurement, capture or publication.
After publication they also wait for each enabled receive controller to finish
its 100-ms post-capture cleanup or enter its terminal fault state.
Descriptors containing RX-disabled lanes are rejected. PMA loopback additionally
requires TX enable on selected quads. External RX-only operation requires no
local TX session; enabled transmitters use bounded session leases independently.

Fully disabled quads are excluded from operational ready/fault barriers.
TX-only operation ignores RX reset-done/user-clock qualification. RX-enabled
operation preserves TX-before-RX infrastructure startup and acquisition timing.
Changing masks never clears first-fault evidence. An enabled quad with a
retained fatal supervisor fault remains unusable.

## ABI additions

Generic address `0x2B`, clock/scratch/status mapping, normal lane records and
diagnostic selector `0xFE` are unchanged.

Mailbox command **4** applies masks through existing fields:

| Address | Value |
|---|---|
| `0xA4` | Command = 4 |
| `0xA8`, `0xAC` | Zero |
| `0xB0` | TX mask; upper four bits zero |
| `0xB4` | RX mask; upper four bits zero |
| `0xB8`, `0xBC` | Zero |
| `0xA0` | New request sequence, written last |

MicroBlaze validates the request, stages masks at AXI `0x120`/`0x124`, and
writes 1 to `0x128`. Hardware independently enforces eligibility and full-word
writes. AXI `0x12C` returns `{error[15:0],11'b0,state[2:0],busy,usable}`;
successful applied status is 9. Mailbox response is 0 for success or 1 for
failure. Configuration consumes a request sequence, preserving the run ID and
published receive records.

Selector **0xF7** exposes eight read-only words:

| Word | Meaning |
|---|---|
| 0 | Schema `0x51430001` |
| 1–2 | Accepted TX/RX masks |
| 3–4 | Observed TX/RX masks |
| 5 | Successful configuration generation |
| 6 | Bits 2:0: state (0 boot, 1 re-arm, 2 applied, 3 failed, 4 drain, 5 release); bit 8: eligible for configuration |
| 7 | Error: 0 none, 1 invalid/ineligible write, 2 timeout |

Configuration eligibility includes controller quiescence, no active or
unacknowledged TX session, and no pending snapshot. The CLI checks bit 8 before
issuing a configuration request; the hardware checks it independently.

The one-second deadline covers the complete low/high/low re-arm handshake and
release acknowledgement. This cannot alias after multiple missed epochs while
a disabled clock is absent. Enabled lanes rebase start/stop/snapshot phases
before configuration becomes usable. Timeout requests zero masks and blocks
tests until successful explicit configuration. Missing TX clocks cannot
acknowledge electrical-idle application; requesting idle does not prove it.

Selectors **0x80–0x9B** expose raw per-quad diagnostics before operational
masking. Word 0 is `{16'h5153,reason[7:0],ready,fault,quad_index[5:0]}`;
words 1–7 preserve the wrapper's original diagnostic record. Registered
SLR-local muxes need four management clocks to settle, less than an I2C
transaction. These are live/first-fault diagnostics, not measurement records.

### Tagged TX sessions and physical boundaries

V3 extends the internal TX session CDC with two-bit Gray generation tags.
Each start, stop or lease expiry advances the tag. A new start is rejected
until the preceding stop is acknowledged; an unacknowledged start can have
one cancellation outstanding. Repeated stop commands cannot wrap a pending
tag. Registering the tags at the SLR boundary and guarding them through six
TX clock stages keeps them behind the two-stage requested level. Each quad
returns the applied tag only after its registered TXPRBSSEL output updates.

The four banks return independently tagged on/off acknowledgements. The
central two-stage tag guard rejects previous-generation acknowledgements,
including cancellation before startup completed. Configuration cannot change
masks while stop acknowledgement remains pending.

Configuration acknowledgement also uses four SLR-local registered banks,
replicated per-quad epoch launches, and a seven-cycle central phase guard.
Both session and RX-configuration bundles have explicit 3-ns maximum-delay and
bus-skew constraints. Stable config-bank launches use narrow two-cycle
contracts; return data and tags travel together through two real register
stages with ordinary one-cycle timing. Far SLR3 returns first land in SLR2
before reaching central SLR1. Session-tag launches also retain one-cycle
timing. Independent audit checks both timed bundles and return stages.

Inactive result records are generated after each local mux, avoiding a
28,672-bit RX-mask mux before the result banks. Every unselected record has
its lane ID and zero data, regardless of retained snapshots/native counters.
The GT-facing error input also has an unconditional sampling register before
protocol-controlled arithmetic, isolating its native output timing.

## Bench interface

`scripts/board_all_links_v3.py` is an on-blade tool. Write operations fail
closed while the v3 contract is unreleased or lacks artifact pins. A clean
`cm_interface` v1.0.3 checkout, commit
`64260cf23b01c9da987feda1fbf51567240c2c71`, must sit alongside deployed scripts.
No deployment or hardware action accompanies this development.

Intended commands after qualification and release:

```sh
python3 board_all_links_v3.py status
python3 board_all_links_v3.py configure --site F1 --tx q221-q234 --rx q221-q234
python3 board_all_links_v3.py configure --site F2 --tx q221-q234 --rx q221-q234
python3 board_all_links_v3.py run --f1-rx q221-q234 --f2-rx q221-q234 --duration-seconds 90
python3 board_all_links_v3.py configure --site F1 --tx none --rx none
```

Selectors accept singles, same-class inclusive ranges, comma-separated sets,
`all` and `none`. Configure one site at a time. Run reads the applied masks
and never changes them. Site-specific unfitted receivers remain excluded.
Any enabled FireFly TX requires `--acknowledge-firefly-tx`, including a
transmit-only endpoint. Optional per-site sequence/run guards remain available.
No reset, programming or automatic retry operation exists.

Clock validation logs all 37 counters but requires GT reference clocks only
for enabled quads, preserving shared physical REFCLK dependencies. Fabric
200/100/325-MHz checks always apply. A missing disabled reference clock does
not block configuring another quad.

The tool shares the v2 software lock and existing `cm_interface` mux/I2C5
transaction behavior. It validates clocks before writes. Each completed
process creates exclusive sibling log/report files under `logs/`, including
failures. Reports derive from the authoritative log and preserve config,
clock/lane/telemetry records, artifact pins and failure tail.

### Convenience launchers

Run these on the blade from a packaged v3 runtime directory, alongside the
clean pinned cm_interface checkout. They require firmware/hardware v3 and
retain the unreleased contract guard. No programming or deployment is part
of either launcher.

Enable all inter-FPGA TX/RX quads q221–q234 on both endpoints:

```sh
python3 -u enable_all_links_v3_inter_fpga.py
```

This replaces both sites' masks and disables all FireFly quads. It leaves TX
PRBS sessions off. To configure and then test both directions for 90 seconds:

```sh
python3 -u enable_all_links_v3_inter_fpga.py --test --duration-seconds 90
```

The test measures the 54 fitted inter-FPGA receivers at each endpoint; the
physical quad enable masks still cover all 56 lanes per FPGA.

Configure and test the four recorded external optical self-loop quads
q121–q124 independently at F1 and F2 (16 receivers per FPGA):

```sh
python3 -u test_all_links_v3_firefly_loopback.py --acknowledge-firefly-tx
```

This is external optical loopback on each FPGA. It uses external mode
`LOOPBACK=000` and requires fitted optical loops. All inter-FPGA and other
FireFly quads are disabled. Duration defaults to 90 seconds. Select different
sets of exactly four distinct FireFly quads per FPGA when the wiring supports
it, for example:

```sh
python3 -u test_all_links_v3_firefly_loopback.py \
  --f1-quads q121-q124 --f2-quads q125-q128 \
  --duration-seconds 90 --acknowledge-firefly-tx
```

Add `--configure-only` to configure those loopback masks without starting a
TX session or measurement. Enabling FireFly serializers requires the explicit
acknowledgement even for configuration alone. Both presets replace complete
TX/RX masks; they do not add to a previous configuration. Configured enables
remain after testing, with TX PRBS sessions stopped. Electrical idle requires
explicitly configuring TX off afterward.

Both endpoints' identity, predecessor, eligibility and target clocks are
checked before the first configuration write. Configuration is sequential:
if F2 application fails after F1 succeeds, the process stops with F1 already
configured. There is no automatic retry or rollback and no receive test starts
until both configurations succeed. Tests retain the common TX-session cleanup,
clock/lane/telemetry logs and sibling Markdown reports. Optional
`--f1-sequence/--f1-run` and `--f2-sequence/--f2-run` guards refer to the state
before configuration; the subsequent test discovers the advanced sequences
under the same software lock.

The maintained runtime package now contains seven Python files plus its
manifest, including both convenience launchers. Latest local bundle:
`build/all_links_v3_runtime_bundle_1794344913552735/`. The earlier five-file
bundle in the static-qualification archive remains frozen. Offline tests now
pass **27/27**, including preset masks, preflight failure, partial application,
configuration-only dispatch and release/FireFly acknowledgement guards.
No hardware action accompanied this software update.

## Build and validation

```sh
bash scripts/build_all_links_v3_firmware.sh
bash skills/vivado-build-project/scripts/run-vivado.sh scripts/create_all_links_v3_project.tcl
bash skills/vivado-build-project/scripts/run-vivado.sh scripts/build_all_links_v3_routed.tcl
bash skills/vivado-build-project/scripts/run-vivado.sh scripts/audit_all_links_v3_routed.tcl
bash skills/vivado-build-project/scripts/run-vivado.sh scripts/write_all_links_v3_bit.tcl
```

Focused simulations use `run_all_links_v3_{config,engine,quad,banks}_sim.tcl`.
Offline tests use `python3 scripts/test_all_links_v3.py`. Historical regression
entry points are unchanged.

Topology derivation adds only module renaming and an exposed TXELECIDLE input
to copies of the proven 28 wrappers. Inverse transformation must reproduce
the original byte for byte. Vendor XCI/generated originals remain untouched.
V3 explicitly retains four result banks, four 64-bit snapshot handshakes per
lane and localized reset release independently of version comparisons.

Implementation must pass exact GT topology, CDC, placement, setup/hold,
routing, DRC and bus-skew checks. Independent audit gates compressed BIT/BIN
emission. Hardware release remains a separate reviewed procedure.

### XSim 2023.2.2 assertion reproduction

`run_all_links_v3_xpm_repro.tcl` drives four stock XPM handshakes with one
valid source request, without v3 RTL. Vendor S-1/S-2 `$past` properties report
errors on repeated instances while independent procedural transition checks
pass. Its messages are preserved as a reproduction, not a clean test gate.

The engine test overrides simulation-only `SNAPSHOT_VENDOR_ASSERTIONS` and
independently checks all 448 chunk transitions, source payload stability,
selection/exposure and changed epochs. Hardware builds retain the default
vendor assertion setting, which has no synthesized effect. The functional
simulation script rejects every `Error:` or `Fatal:` in its output.

## Qualification evidence — 2026-11-10

The implementation and independent routed audit pass. Sign-off setup/hold
WNS is **+0.036/+0.009 ns**, with zero failing endpoints. All
**227,324/227,324** routable nets route, with zero routing or Error-DRC
failures. All **532/532** skew groups pass: 448 snapshot, 28 descriptor,
28 TX-session and 28 RX-configuration groups. The audit verifies golden GT
properties, dedicated REFCLK routes and QPLL connections, 6/8/8/6 physical
control/reset residency, electrical-idle drivers, and 160 real return
registers with ordinary one-cycle timing. The one RTSTAT-10 warning concerns
eight optimized nets with no loads.

Compressed BIT/BIN generation passes. The BIT metadata explicitly records
`COMPRESS=TRUE`; its complete 69,360,720-byte configuration payload exactly
matches the BIN. Artifact SHA-256 values:

| Artifact | SHA-256 |
|---|---|
| BIT | `60c8311daabf487184672bf987773fbb6fd808bb7e070fde4588854e40d40ed1` |
| BIN | `b04bff257ecdd9d3aeb6d1a63a94a1fa0e4bc7cdcb856b7bac66b5e9d54fcf10` |
| Routed DCP | `ca56c79ccc90b5cf67e6d85d982238b2c3d03997b79fe45d7eccd100354fb684` |
| Synth DCP | `4cdc33364e0e53819f53a9557a4ba333b8158e7b00dd5ac6d53d58d29c1322df` |
| ELF | `c8b1e6c53d9649c0fda090384944d1b9165607c58fe95d1c66065a1db9753911` |

Frozen artifacts, source snapshot, runtime bundle, reports and logs are under
`build/diagnostic_archive/all-links-v3-runtime-quad-control-static-pass/`.
The archive has its own relative-path `SHA256SUMS` and `manifest.json`.
Build logs:

- `build/logs/rebuild_all_links_v3_pipelined_returns-20261110T191216Z.log`
- `build/logs/audit_all_links_v3_routed-20261110T194751Z.log`
- `build/logs/write_all_links_v3_bit-20261110T195903Z.log`

Four focused simulations and 21 offline Python tests pass, including session
cancellation/expiry, independently delayed ACK data/phase, missing/re-enabled
RX clocks, stale native counters, cleanup eligibility, terminal-fault
isolation, one-way operation and cleanup after failed receive results.
All seven historical simulation runners and all 15 unchanged v2 operator
tests pass. The unchanged all-direct firmware test retains its baseline
mismatch: it expects v10's `0x00020407`, while its unchanged builder selects
v12's `0x00020409`. This is not a v3 regression.

Source and implementation-input checksum gates passed after route; audit and
writer independently checked both manifests. The initial and superseded
routes/syntheses remain separately archived. The first route failed setup
-2.518/-2447.112 ns; the cleanup-guarded route failed -2.802/-1835.787 ns.
The final candidate replaces their raw status crossings and result-copy CE
fanout. One-off rebuild helpers are retained in the final archive's
`development_helpers/`; the maintained clean build flow is listed above.

Prepare runtime files locally with
`python3 scripts/package_all_links_v3_runtime.py`. The final pinned bundle is
`build/all_links_v3_runtime_bundle_1794341646157111/`, also copied to the
archive. It contains five runtime files plus their SHA manifest and retains
`RELEASED=False`. The clean pinned cm_interface checkout is a separate
prerequisite for future remote use.

All four working v2 BIT/routed-DCP/synth-DCP/ELF hashes were independently
verified unchanged. No programming, deployment, reset, MCU access or hardware
test occurred. V3 write operations remain blocked pending a separately
reviewed hardware release and qualification procedure. The last observed
board state remains the October 27 v2 record, without a fresh read here.
