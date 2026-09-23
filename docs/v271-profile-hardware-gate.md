# V271 profile-repair hardware gate

Date: 2026-09-12. This gate followed the two clean v271 baselines without an
FPGA reload. It tested a bounded lane-12 error pulse, retained publication in
IDLE, and replacement by the next clean run. F1 remained isolated diagnostic
v271 / 2.5.21 (`0x00020115`) throughout.

## Sequence 3: targeted measurement pulse

An XSDB watcher ran on lnx4189, connected with
`connect -url TCP:lnx4189:3121`, and independently required F1 target 1,
running MicroBlaze target 3, v271 identity, sequence 3 in RUN, prior completed
run ID 2, and lane mask `0xF000`. It then performed exactly one write to toggle
lane 12: `mwr 0x44a00060 0x1000`. The toggle changed from `0x00000000` to
`0x00001000`; state remained RUN. The 3-ms host write interval is not the pulse
width—the RTL creates one TX-clock pulse.

Sequence/run ID 3 passed the matching external-pulse validator:

- Response and summary `0x01030401`: one deliberately error-bearing lane,
  three clean lanes, four selected, normal-duration completion.
- Lane 12 recorded two RXPRBSERR-active cycles. Its native profile contains
  two errors, maximum consecutive run 2, first/last indices 118,480,074 and
  118,480,075, span 2.
- Lanes 13–15 recorded zero errors. Every profile elapsed 3,222,603,238 RX
  cycles; all lanes had zero lock losses or saturation.
- Exactly one cleanup restart completed with cause/status 3. Trace epoch 3
  retained 105 events without overflow.

## IDLE retention and new epoch

A new full diagnostic capture was taken about 158 seconds after the 10-second
sequence-3 run completed. The overview, all lane records, all four complete
256-bit profiles, platform diagnostics, restart record, and every retained
trace slot matched the original publication exactly. In particular, lane 12
still contained the same nonzero elapsed count and two-cycle event; no
same-epoch zero-elapsed overwrite occurred.

Sequence/run ID 4 then ran cleanly and passed. It replaced the prior fault
epoch with four equal profiles of 3,222,603,337 RX cycles and zero errors.
All lanes remained selected/locked with zero lock losses; exactly one cleanup
completed and trace epoch 4 retained 106 events without overflow. This proves
the retained same-epoch protection did not prevent a genuinely new accepted
epoch from publishing.

The online operator saved evidence before validation. Copied JSON files passed
independent local validation, and local/Apollo hashes match. No retry, reload,
FireFly write, optical outage, CPU halt, reset, or sequence 5 request occurred.

## Health and evidence

During the retention interval, required reference/generated clocks remained
present and the managed RX monitor was 322.260 MHz. Final regulator status
words were clear. F1/F2 were 25.5/24.5 C; both x4 modules were 38 C with
outputs enabled. The familiar raw byte-3/byte-5 `FF/FF` behavior was unchanged.

- `build/diagnostic_archive/v271-run3-pulse.json`:
  `d0d26130ea3671b0c5f132767521cb1fcc427800304392a5704b24e535a76f7c`
- `build/diagnostic_archive/v271-run3-retained.json`:
  `1f0005b07582d52b8095ae9e2d9d51f9b11075883bd3a73755baf85e05b52ec6`
- `build/diagnostic_archive/v271-run4-clean.json`:
  `9b594153367ccef71c2c3bab63606892b6719e4e74cc5c9015785231a0744f43`
- `build/v271-run3-xsdb.log`:
  `0d1ada6202d12523896d7947f03a9dcc114bdfabdacd2cf78d6e413f2dd5a688`
- `build/diagnostic_archive/v271-profile-hardware-gate.tar.gz`:
  `e090fd220911becf55e23a7ae5ca47abd6a851ba9667e22b417225c15917a31d`

F1 remains v271 healthy IDLE at request/response/run ID 4. This supplies
hardware support for the profile repair within the tested scenarios. It does
not prove metastability behavior, reconstruct the original v270 glitch, or
make v271 a qualification candidate. The next engineering task is a separate
runtime-integrity candidate based on sustained PRBS failure and missing-clock
detection rather than native `RXCDRLOCK`/`RXPRBSLOCKED` alone.
