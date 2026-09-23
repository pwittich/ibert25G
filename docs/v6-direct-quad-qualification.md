# V6 direct-quad scoped hardware gate

Date: 2026-09-17

The scoped one-quad F1↔F2 gate is complete and passed.  It covers F1 N/q222
(`X1Y8`–`X1Y11`, global lanes 60–63) against F2 I/q233 (`X1Y52`–`X1Y55`,
global lanes 104–107), four lanes in both directions at 25.78125 Gb/s.  The
physical mapping reverses lane order: 60/61/62/63 ↔ 107/106/105/104.

This is category coverage for one direct electrical quad.  It is not an
all-channel qualification, a long BER soak, or channel requalification.

## Final artifacts

F1 remains the independently audited original v6 endpoint:

- FW/HW identity `0x00020400`
- bitstream SHA-256
  `06501f6d69a84d80fb47521b8835ea542dab3b6edaca42c8defa742f51b83dcc`
- ELF SHA-256
  `262bbdf17844694d124e345b0f71b599dd57800dbf93ecc8c8ea35bb25611568`
- routed WNS/WHS +0.413/+0.010 ns

F2 uses the final complete golden-q233 primitive match:

- FW/HW identity `0x00020403`
- bitstream SHA-256
  `5a7e5f3dabd7165baeb25ad920652bd9bfa017f741371ef1f1c82516cc37cfa9`
- routed DCP SHA-256
  `067782afcae42d2e16c7ddf65761153717d761db864bfcc76c94a151c900a842`
- ELF SHA-256
  `ea7d79aca4e5edde9f0cf3ccd45644e9ceb722a71706ba077af35d432cf7a52a`
- routed WNS/WHS +0.361/+0.010 ns

Both bitstreams are compressed.  The final F2 bit generation explicitly
populated the matching ELF.  Independent F2 routed audit passed timing,
routing, DRC, endpoint ownership and pin/refclk checks, descriptor timing and
bus skew, reset fanout, polarity, and every q233 primitive property that
differs from the left-bank Wizard profile.  The incremental route emitted one
temporary `Route 35-4475` incomplete-guidance warning while reconstructing the
changed design; final routing verification, route status, DRC, timing and the
independent checkpoint audit all passed.

Build and audit evidence:

- `build/logs/build_direct_quad_v6_f2_bitstream-20260917T035339Z.log`
- `build/logs/audit_direct_quad_v6_f2_routed-20260917T040237Z.log`
- `build/logs/report_direct_quad_v6_f2_golden_params-20260917T034736Z.log`

## Preserved failures and repair

The first F2 image (`0x00020401`) inherited the managed left-bank Wizard RX
profile.  Its one-shot PMA gate failed in `LOCK_WAIT`; `X1Y55` never locked.
The partial seven-property repair (`0x00020402`) recovered all locks but its
one-shot PMA measurement preserved saturated errors on lane 105/`X1Y53`, with
zero native lock losses; the other three lanes were clean.  Neither failed
request was replayed.

The final `0x00020403` repair compares the routed q233 primitive against the
golden full IBERT and matches all remaining non-metadata differences, including
the other CDR-generation and RX programmable-divider properties.  Prior
products and routed evidence are preserved under:

- `build/diagnostic_archive/direct-v6-f2-pma-failure-20260917T032200Z/`
- `build/diagnostic_archive/direct-v6-f2-00020402-pma-lane105-failure-20260917T035300Z/`

## Hardware results

F1's original sequence/run 1 PMA result was preserved throughout.  The final
F2-only PMA repair gate used fresh F2 sequence/run 1 and passed:

- F1 lanes 60–63: 257,808,272,320 bits each, zero errors/losses.
- F2 lanes 104–107: 257,808,272,800 bits each, zero errors/losses.
- normal summary `0x00040401`, healthy IDLE, no retained platform fault.

Evidence: `build/diagnostic_archive/direct-v6-pma-f2-repair-1789617888613559.log`.

The fixed external gate then started independent bounded TX sessions at
sequence 2 on both endpoints and observed simultaneous RUN for each receive
window.  Two separate ten-second bidirectional PRBS31 measurements passed:

- sequence 3 / run 2: all eight records nonzero, approximately
  257,808,270,240–320 bits per lane, zero errors and native lock losses;
- sequence 4 / run 3: all eight records nonzero, approximately
  257,808,268,560–640 bits per lane, zero errors and native lock losses.

Both TX sessions were stopped with sequence 5.  Publications remained stable
across stop.  Final F1 and F2 state is healthy IDLE, sequence/response 5,
run ID 3, sessions off, required 100/325/322.266-MHz clocks valid, no retained
fault, and the run-3 `0x00040401` measurement retained.  Evidence:

- `build/diagnostic_archive/direct-v6-external-1789617918546536.log`
- `build/diagnostic_archive/direct-v6-status-1789617977012135.log`

Sequences 1–5 and runs 1–3 are consumed on both endpoints.  Do not reload,
reset, replay these launchers, or issue a later request without an explicitly
reviewed next gate.  Expansion to the other direct quads is the next design
decision, not part of this completed test.
