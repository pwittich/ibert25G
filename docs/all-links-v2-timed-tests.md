# All-links v2 timed link tests

## Status and scope

These launchers target the timing-clean all-links v2 image, identity
`0x00020501`. The shared contract is released for reviewed, explicitly
authorized stages. Deployment copies hash-checked Python files and the
authoritative `cm_interface` checkout; it does not program or reset an FPGA.
The contract pins BIT/DCP/ELF SHA-256 values `163172d9...0b66f`,
`323ff582...993a`, and `d947fd47...30f9c` from the frozen timing-clean archive.

Both tests run on F1 and F2 together. `--duration-seconds N` selects an integer
duration from 1 through 86,340 seconds and defaults to 90 seconds. They use the
firmware's hardware-timed measurement window, not a host sleep. A passing lane
must be selected and locked, report zero PRBS errors, zero native lock losses,
a nonzero denominator equal to `valid_cycles * 80`, and a cycle count within
one percent of `322,265,625 * N`. Every selected lane on both endpoints must
pass. There is no retry. Script names use `timed` rather than the obsolete
`_90s` suffix; 90 seconds is the default rather than a fixed duration.
The upper bound reserves 60 seconds below firmware's 24-hour command limit for
the bounded TX-session cleanup lease.

The scripts manage these 25.78125-Gb/s channels:

- FireFly globals 0--55: q121--q134, four lanes per quad.
- Inter-FPGA globals 56--111: q221--q234. The fitted receive masks test 54
  lanes per endpoint, omitting F1 globals 70/71 and F2 globals 96/97.
- The 10-Gb/s AXI C2C channels are never included.

## Clock and telemetry gates

Before the first measurement doorbell, each FPGA must report identity
`0x00020501`, healthy IDLE, the caller-supplied predecessor sequence/run, and
clock status `0x434DA501`. The launcher logs all 37 direct-kHz counters and
requires:

- `clk_200_ext`: 200,000 kHz within 0.1%;
- `clk_100`: 100,000 kHz within 0.1%;
- `clk_325`: 325,000 kHz within 0.1%; and
- all twelve physical managed-GTY REFCLK counters: 322,266 kHz within 323 kHz.

Any mismatch aborts before a test request. Board transactions use one
`Registry` instance while holding `/tmp/all-links-v2-90s-mcu.lock`; the legacy
lock name is intentionally retained so old and new launcher deployments cannot
access the MCU concurrently. FPGA
selection and the I2C5 semaphore remain inside the MCU's `FP` transactions.

Complete telemetry snapshots are taken before the request, near one-third and
two-thirds of the requested duration, and after completion. Each snapshot logs:

- MCU ADC voltage and current for `VCC_12V` and `CUR_V_12V`, plus derived
  12-V power in watts;
- every MCU ADC channel, including FPGA diode temperatures `F1_TEMP` and
  `F2_TEMP`;
- temperature sensors 1 and 3 on both pages of all seven LGA80D devices; and
- module temperature for every populated FireFly in the authoritative TF
  preset (currently F1_1--F1_4, F2_3, and F2_6).

Apollo does not mount the authoritative source path directly. The maintained
remote bundle lives in `/home/cms/25G`; its `cm_interface` checkout must be
clean and exactly at tag `v1.0.0`, commit
`8e56fdf24c038b64f69f26b55f0facb7c77e0537`. Deployment verifies both the
tag and commit before every stage. If the checkout is absent, deployment copies
the clean authoritative checkout from
`/nfs/cms/tracktrigger/wittich/int_test/cm_interface`; it never overwrites a
present checkout that fails verification.

The verified remote runtime bundle in `/home/cms/25G` contains:

- `all_links_v2_timed_contract.py`
- `all_links_v2_timed_common.py`
- `milestone3_12hour_external_soak.py`
- `all_links_v2_timed_status.py`
- `all_links_v2_timed_results.py`
- `test_all_links_v2_inter_fpga.py`
- `test_all_links_v2_firefly_loopback.py`

The `board_*` launchers and Markdown report generator remain in this checkout:
they own SSH transport and the local `build/diagnostic_archive/`, so Apollo
does not need copies of them. The bundle above was deployed and independently
hash-checked on 2026-09-20 without programming, resetting, or testing hardware.

Telemetry is evidence, not a temperature or power limit: this procedure has
no approved numerical thermal/power threshold. A missing or invalid required
reading fails the run because the requested evidence would be incomplete.

## FireFly external-loopback test

“Loopback” here means the FireFly optical/link path is physically looped back.
The test therefore uses external command `0x00010501` with `LOOPBACK=000` so
the measurement includes the FireFly module and loopback path; it does not use
near-end PMA loopback, which would bypass them. Its positional quad selector
accepts a single quad, an inclusive range, or comma-separated combinations.
The confirmed bench wiring self-loops q121--q124 independently on both F1 and
F2: each endpoint's TX returns to that same endpoint's RX. These are not
F1-to-F2 links. The symmetric launcher therefore measures two valid but
independent optical loopback sets for those quads.

As with the direct test, v2 requires the complete 112-lane mask for the
bounded TX session whose lease is the requested duration plus 60 seconds. All
112 transmitters are active even though
only the selected FireFly receive quads are measured. The explicit
`--acknowledge-all-managed-tx` option confirms that this is safe:

```sh
python3 scripts/board_all_links_v2_firefly_loopback.py deploy
python3 scripts/board_all_links_v2_firefly_loopback.py status
python3 scripts/board_all_links_v2_firefly_loopback.py run q121 \
  --f1-sequence 0 --f1-run 0 --f2-sequence 0 --f2-run 0 \
  --acknowledge-all-managed-tx
python3 scripts/board_all_links_v2_firefly_loopback.py run q124-q130 \
  --f1-sequence 3 --f1-run 1 --f2-sequence 3 --f2-run 1 \
  --duration-seconds 300 \
  --acknowledge-all-managed-tx
```

Only q121--q134 are accepted. A range is inclusive and each selected quad adds
all four of its global receive lanes. Selection does not limit which
transmitters the session activates. The example values are illustrative:
always obtain and review the actual predecessor sequence and run IDs
immediately before authorizing a run.

## Bidirectional inter-FPGA test

The direct-link test starts a bounded TX session at both endpoints with a lease
60 seconds longer than the requested measurement, then starts the two external
PRBS31 receive windows as closely
together as serialized MCU access permits. It always attempts a normal
session stop; if cleanup cannot safely submit one, the logged hardware lease
bounds transmission.

All-links v2 accepts TX-session commands only with the full 112-lane managed
mask. Consequently this direct-link test also drives all outward FireFly
transmitters with PRBS31 for the duration of the session, although it measures
only the fitted direct receivers. This is why the launcher requires the
explicit `--acknowledge-all-firefly-tx` option:

```sh
python3 scripts/board_all_links_v2_inter_fpga.py deploy
python3 scripts/board_all_links_v2_inter_fpga.py status
python3 scripts/board_all_links_v2_inter_fpga.py run \
  --f1-sequence 0 --f1-run 0 --f2-sequence 0 --f2-run 0 \
  --duration-seconds 90 \
  --acknowledge-all-firefly-tx
```

Do not use that acknowledgement unless the connected optical hardware is
known safe for PRBS31 transmission.

## Replay and evidence rules

The `--f1-sequence`, `--f1-run`, `--f2-sequence`, and `--f2-run` arguments are
the exact expected predecessor state, not the values to write. The scripts
derive the next mailbox values and verify every descriptor before the single
doorbell write. If an SSH connection drops after a request, invoking the same
command again fails its predecessor check instead of replaying it.

Use either launcher's `status` stage immediately before review to capture both
sites' current request/response sequence, run ID, identity, state, complete
clock table, and one complete telemetry snapshot. `status` is read-only.

The board launchers hash-check every deployed file before a run and stream the
complete output into a unique log below `build/diagnostic_archive/`. When the
remote process ends, including on failure, the launcher creates a sibling
immutable `*.report.md` summary with the outcome, exact invocation and frozen
hashes, predecessor state, clock-preflight table, per-endpoint lane summary,
any non-clean lane records, telemetry extrema by snapshot, evidence-log hash,
and the completion marker or failure tail. It prints the paths as
`ALL_LINKS_V2_90S_EVIDENCE` (retained for log-consumer compatibility) and
`ALL_LINKS_V2_TIMED_REPORT`. The raw log remains
authoritative; report creation uses exclusive-create mode and never changes
hardware or retries a request. Preserve a failed log and report, then inspect
live state; do not retry automatically. Neither launcher programs, resets,
reloads, or clears a fault.

The first 180-second inter-FPGA gate is consumed and failed on F2 global lane
98; it was not automatically retried and must not be replayed. After a
separately authorized board power cycle and exact-image reprogramming, a new
gate from fresh sequence/run state passed all 54 fitted receivers at each
endpoint. Its sequences 1--3 and run 1 are also consumed. See
`docs/all-links-v2-inter-fpga-hardware-gate.md`.

The q121--q123 FireFly test subsequently failed twice. Run3 reported F1 lane
errors on 1/3/4/6 and F2 lane4; one explicitly authorized 90-second repeat
reproduced the same four F1 lanes while F2 passed all twelve. Both runs had
zero native lock losses and full denominators. Final F1/F2 are healthy
IDLE/session-off at sequence/ack12, run4. The repeat is consumed; do not replay
it without new authorization.
One later authorized q121--q124 run5 established that q124 passes all four
lanes on both endpoints. F2 passed all 16 selected lanes, while F1 reproduced
errors only on q121/q122 lanes 1/3/4/6. Q123 and q124 were clean, with zero
native lock losses everywhere. Final F1/F2 are healthy IDLE/session-off at
sequence/ack15, run5. This run is consumed.

Implementation files:

- `scripts/board_all_links_v2_inter_fpga.py`
- `scripts/board_all_links_v2_firefly_loopback.py`
- `scripts/test_all_links_v2_inter_fpga.py`
- `scripts/test_all_links_v2_firefly_loopback.py`
- `scripts/all_links_v2_timed_common.py`
- `scripts/all_links_v2_timed_contract.py`
- `scripts/all_links_v2_timed_status.py`
- `scripts/all_links_v2_timed_results.py`
- `scripts/all_links_v2_timed_report.py`
