# How to run and plot an eye scan

Eye-scan v1 (`0x00020503`) is implemented and statically qualified, but is
**not released or loaded on hardware**. Offline plotting works now. The
acquisition commands below describe use after a separate reviewed hardware
gate; the current launcher rejects mutating commands with `UNRELEASED`.
Packaging does not release or program the image.

## Plot saved data now

From the repository root, use a Python environment with NumPy and Matplotlib:

```bash
python3 scripts/board_eye_scan.py plot logs/eye-scan-v1-EXAMPLE.json \
    --output-prefix eye-example
```

Replace the input with an actual saved scan JSON. This creates
`eye-example.png` and `eye-example.pdf`; choose a new prefix each time because
existing output files are never overwritten. Plotting requires no board,
`cm_interface` checkout or hardware release. On the development host,
`/usr/bin/python3` has the plotting dependencies.

The figure contains a logarithmic eye-sampler mismatch heatmap and central
horizontal/vertical slices. Horizontal position is in UI; vertical position
is in codes. Zero-error points show a 95% upper bound, rather than a measured
zero error probability. Missing or invalid points stay blank. An eye scan
does not replace an ordinary link BER measurement.

## Prepare the operator bundle

Run from the repository root:

```bash
python3 scripts/package_eye_scan_v1_runtime.py
```

The printed `build/eye_scan_v1_runtime_<timestamp>/` directory contains seven
runtime files and `eye_scan_v1_runtime_manifest.json`. Keep these together.
On the board-control host, the bundle needs a sibling directory
`cm_interface/` at clean tag **v1.0.3**, commit
`64260cf23b01c9da987feda1fbf51567240c2c71`. Commands verify the checkout and
manifest before board access. The bundle retains `RELEASED=False` until the
hardware gate is reviewed; do not edit that flag to bypass the gate.

After approved deployment, run the following commands from that bundle
directory. Both endpoints must run the matching eye-scan image; existing
v2/v3 images and their launchers cannot substitute for it. Programming and
the first hardware qualification are separate from this operating guide.

## Acquire one scan after hardware release

This example assumes a **same-endpoint optical loop on F1 q121**, with
F2 unused. Confirm the actual cabling before selecting transmitter and
receiver. A lane is the local GT lane **0–3 within its quad**, not an optical
channel label. See the physical ordering in the [README](../README.md).

First inspect both endpoints:

```bash
python3 board_eye_scan.py status
```

Require matching firmware/hardware identity `0x00020503`, healthy
IDLE/session-off state `0x00100000`, no busy/fatal eye job and no pending
request. A retained result must be saved and reviewed before acknowledging
it. The scan also checks clocks, quad health and final cleanup automatically.

Configure only the required quads, then acquire F1 q121 lane 0:

```bash
python3 board_eye_scan.py configure --site F1 --tx q121 --rx q121 \
    --acknowledge-firefly-tx
python3 board_eye_scan.py configure --site F2 --tx none --rx none
python3 board_eye_scan.py scan --receiver F1 --quad q121 --lane 0 \
    --transmitter F1 --tx-quad q121 \
    --horizontal=-32:32:2 --vertical=-120:120:8 \
    --prescale 5 --budget-seconds 120 --point-timeout-ms 1000 \
    --acknowledge-firefly-tx
```

The acknowledgement permits PRBS31 on enabled outward FireFly transmitters.
Every enabled TX quad on either endpoint participates in the bounded session,
so review both configurations. Configuration persists after the scan; the
launcher stops the TX sessions it started.

For an inter-FPGA connection, use the receiver's fitted direct quad
(`q221`–`q234`) and the actual opposite endpoint/quad as transmitter. Enable
that transmitter quad and receiver quad on their respective sites first.
Do not infer the peer quad or lane mapping from matching numbers.

| Option | Meaning / default |
| --- | --- |
| `--quad`, `--lane` | Receiver quad q121–q134 or q221–q234; local lane 0–3 |
| `--transmitter`, `--tx-quad` | Explicit transmitter endpoint and connected quad |
| `--horizontal` | Inclusive `first:last:step`; default `-32:32:2`, allowed −32…32 |
| `--vertical` | Inclusive `first:last:step`; default `-120:120:8`, allowed −127…127 |
| `--prescale` | Accumulation prescale, default 5; higher values take longer |
| `--budget-seconds` | Total sampling/cleanup budget, default 120 seconds |
| `--point-timeout-ms` | Per-point deadline, default 1000 ms |

Use `--horizontal=...` and `--vertical=...` when the value starts with a
minus sign. The default grid has 1023 points; the maximum is 4096. The host
rejects deadlines or budgets too short for the requested accumulation.
Result retrieval over the mailbox adds time after sampling and TX cleanup;
the budget is not a wall-clock limit on the whole command.

## Save, review and acknowledge the result

Require exit status zero and an `EYE_SAVED` line reporting the expected job
and point count. Each invocation creates an exclusive timestamped log and
process report under `logs/`. A scan that reaches acquisition also preserves
JSON and CSV, including partial data on failure where available:

```text
logs/eye-scan-v1-<timestamp>.log
logs/eye-scan-v1-<timestamp>.report.md
logs/eye-scan-v1-<timestamp>.json
logs/eye-scan-v1-<timestamp>.csv
```

The report records exit status and artifact hashes. Keep all four files.
Generate the PNG/PDF separately with the plotting command above. A nonzero
exit status is a failed operation even if some points can be plotted.

After the process exits, inspect status again:

```bash
python3 board_eye_scan.py status
```

Require both TX sessions off, healthy IDLE, and no busy/fatal job. The result
remains in FPGA memory and blocks another scan until explicit acknowledgement.
After saving and reviewing the files, use the **actual job ID** printed by
`EYE_SAVED`/`EYE_PROGRESS`; for example, if that ID is 7:

```bash
python3 board_eye_scan.py ack --site F1 --job 7
```

## Interruptions and failures

Ctrl-C requests bounded cancellation of the owned job and cleanup of owned
TX sessions. The launcher preserves partial evidence, returns failure, and
never retries the scan or automatically acknowledges the result. Let the
process finish cleanup before using another board command.

If the original process has exited and a matching job remains busy, inspect
status and use its actual job ID for an explicit cancellation:

```bash
python3 board_eye_scan.py cancel --site F1 --job 7
python3 board_eye_scan.py status
```

Cancellation retains the matrix. If cleanup fails, a fatal lock remains, or
TX-off cannot be confirmed, preserve the logs and review the failure before
another hardware action. Do not replay the scan, reset, reload or acknowledge
an unreviewed result as an automatic recovery step.

## Build and qualification reference

The existing static candidate is frozen under
`build/diagnostic_archive/eye-scan-v1-0x00020503-static-candidate/`.
Its hashes, timing margins, build entry points and audit evidence are in the
[runtime and qualification record](eye-scan-v1-runtime.md). Build scripts
refuse existing output directories; preserve this candidate before preparing
a fresh build. The [accepted plan](eye-scan-plan.md) records the implementation
scope and the separate hardware qualification requirement.
