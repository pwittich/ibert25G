# v6 direct-quad plan — scoped gate complete

Outcome: the final audited F1 `0x00020400` / F2 `0x00020403` pair passed both
PMA gates and two overlapping bidirectional ten-second PRBS31 windows.  See
`docs/v6-direct-quad-qualification.md`; its final state and consumed-sequence
rules supersede the historical progress notes at the end of this plan.

User scope: one complete direct F1↔F2 quad, four lanes each direction.
This covers the direct electrical link category; channels are previously
qualified. No new channel qualification, long soak, MCU implementation,
optical stimulus, or expansion to other quads in this gate.

## Critique and revised physical target

Independent agent critique: conditional GO for implementation, not hardware
deployment before audit. q222 on both devices is wrong. Use endpoint-specific
artifacts sharing common logic, each enabling only its requested four lanes.
The structural right221–223 proofs lack functional PRBS/MCU and cannot serve
as ready-made test images. Preserve TX-session fault policy initially, but
simulate peer contamination when a local fault terminates its transmitter.

Primary board source: Cornell_CM_Rev3_HW/Schematic/
6089-127-RevA_23Jan2025.pdf, sheet77 (9.01), checked against board_pins.xdc.
F1 N/q222 uses X1Y8–11 and local REFCLK0 rt_r0_n (AY13/AY12).
F2 I/q233 uses X1Y52–55 and local REFCLK0 rt_r0_i (N11/N10).
P nets connect P and N nets connect N; do not introduce speculative polarity
inversion. Schematic F2 net suffixes are reversed relative to GT channel
indices and this repository's package-pin-based port indexing.

| F1 physical channel / global lane | F2 physical channel / global lane |
|---|---|
| X1Y8 /60 | X1Y55 /107 |
| X1Y9 /61 | X1Y54 /106 |
| X1Y10 /62 | X1Y53 /105 |
| X1Y11 /63 | X1Y52 /104 |

Mapping applies in both directions. Preserve the existing global-lane ABI;
endpoint selection masks must reflect each endpoint's own four channels.
Do not include 10-Gb/s AXI C2C lanes.

## Execution gates

1. Generate separate functional q222/q233 Wizard IP from Tcl:25.78125Gb/s,
   322.265625MHz local REFCLK0,QPLL0,80-bit interfaces. Export native PRBS,
   reset/status and drive/polarity controls. Preserve all older generated IP.
2. Implement shared four-lane managed wrapper and endpoint-specific v6 tops,
   firmware identities/masks, versioned build and fixed launcher choices.
   Preserve mailbox ABI,100/325MHz monitors, staged acquisition/post-lock
   counter reset, explicit four-lane reset fanout and stable diagnostics.
3. Simulate actual wrapper/controller wiring, reversed dual-endpoint lane map,
   PMA cleanup, staggered startup/completion, independent TX persistence,
   expiry/fault coupling and consecutive requests with atomic results.
4. Clean synthesis (no automatic incremental synthesis), retain checkpoints,
   implement compressed bits. Reuse only compatible IP/checkpoints. Audit
   both endpoints independently: four channels/one common, local refclk and
   correct pins, timing/routing/DRC, CDC/descriptor bounds/bus skew/reset fanout.
5. Only after audited matching artifacts and reviewed hash-pinned launchers:
   preserve current v5 state, program exact site-specific images, verify
   identity and clocks, one10s PMA gate per endpoint with sessions off.
6. If both PMA pass: start bounded TX sessions on both, submit overlapping
   10s PRBS31 receive windows, capture both publications before either stop.
   Require eight clean nonzero records and healthy final IDLE. Then one
   separately sequenced short repeat for reuse; on failure preserve both ends
   and stop, no silent reload/reset/retry. No channel BER requalification.

Historical planning state: hardware was audited v5 F1seq17/run0 F2seq25/run8
healthy IDLE with sessions off, before any v6 bitstream or hardware test.  The
qualification report above supersedes this state.

First implementation step COMPLETE: approved Vivado helper generated both
functional cores under build/direct_quad_v6_ip. Log:
build/logs/create_direct_quad_v6_ip-20260917T021448Z.log. Exit0; IP status
reports both direct_v6_q222_gt and direct_v6_q233_gt up-to-date, no changes
required. Native PRBS/reset/status and explicit drive/polarity ports present.
This is IP generation only, not application simulation or bitstream signoff.
Next implementation work is shared managed RTL/endpoint tops and firmware.
