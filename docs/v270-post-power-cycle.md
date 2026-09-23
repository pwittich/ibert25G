# V270 after user power cycle — 2026-09-12

## Subsequent authorized diagnostic baseline: PASS

The user explicitly authorized one clean diagnostic baseline despite persistent
module FF/FF alarms. The matching v270 operator and five dependencies were
SHA-256 matched between local sources and Apollo before execution.
One 10-second external PRBS31 request, sequence 1 after 0 / expected run ID 1,
completed with response and hardware summary 0x00040401. All four lanes 12–15
were selected/locked, each had zero errors and zero lock losses, and each
recorded 3,222,603,371 cycles / 257,808,269,680 tested bits. Native profiles also
had zero errors. Engine returned to IDLE, quad ready, with exactly one cause-3
cleanup restart; trace retained 102 events without overflow, epoch 1. Remote
validation and independent local offline validation both passed.

Managed RX clock before/after: 322262/322262 kHz. Post-run FPGA temperatures
F1/F2 were 25.5/24.0 C (`build/temperature-postcycle270-run1.log`). Supply
statuses remained zero; Vout 1.20263671875/0.905029296875 V, regulator
temperatures 32.5625 C. Raw currents -0.5771484375/-0.15478515625 A remain
unvalidated. F1_5 was 38 C with LOS/CDR LOL FF/FF, status 00, TX disable 00,
CDR enable FF after completion.

Apollo raw evidence: `/tmp/v270-diagnostic-20260912/postcycle-run1-clean.json`.
Local copy: `build/diagnostic_archive/v270-postcycle-run1-clean.json`.
Both SHA-256: `de6bea2c3f51bcfd5479c780f4fd615f1c40be5ba0ab525ef6f66182eb841cbe`.
No second run, optical stimulus or historical-image reload was issued.
F1 remains v270 IDLE at sequence/run ID 1; the earlier run-zero statements
below describe the pre-baseline state.

This confirms clean data transport during this window, not general hardware
qualification or correct module alarm behavior. Proposed next comparison is
the previously successful golden IBERT image on the same four external links,
without changing cabling, clock configuration or FireFly settings. Preserve
this v270 evidence before any separately authorized reconfiguration. Golden
success alone would not prove all hardware is good or isolate a specific RTL
bug, especially since v270 also passed this baseline.

The user reported completing the board power cycle. No agent power-control
operation was issued. Preprogram JTAG enumeration on lnx4189 showed only two
xcvu13p targets (1 and 2), without MicroBlaze targets.

## Preflight and reload

F1AVTT/CC status fields were all zero on both pages. Vin was 11.9375/11.96875 V,
Vout 1.2060546875/0.905029296875 V, and regulator temperatures 32.0625 C.
Raw current values were -1.70703125/-0.5908203125 A (not validated).
F1_5/F1_6 module temperatures were 38/39 C; LOS/CDR LOL were FF/FF,
TX disable 00, CDR enable FF and rate select 00 on both modules.

JTAG SysMon temperatures: F1 25.0 C, F2 24.5 C. Full log:
`build/temperature-postcycle270.log`.

`build/program270.tcl` ran with XSDB on lnx4189 after target enumeration. Its
bitstream SHA-256 check passed against
`72f3a2fa5b97f30cd503631fa16af03715a165a1865d7278fd5a249874bdefe4`.
Matching ELF was independently checked as
`0f91bee392bb1de414834cb03f6cd5f63a503cd8401b8365f599f81ac60677cf`.
Only F1 was programmed with the existing audited compressed bitstream and
embedded firmware. Programming exited successfully. The resulting chain was
F1 target 1, MDM 3, running MicroBlaze 4, F2 target 2. Do not reuse the earlier
pre-cycle MicroBlaze target number.

## Postprogram readback

Firmware and hardware both read 0x00020114. Engine state, request sequence,
response sequence/code, run ID and summary all read zero. No baseline request
or optical stimulus was issued.

The frequency reader validated r39=0x434DA501. Values are direct kHz, without
x2 scaling. In this diagnostic image r38 is managed RXUSRCLK2 (the generic
reader still labels it lf_r1_ab).

| Clocks | Measured kHz |
| --- | ---: |
| Board reference r02 | 200000 |
| LHC/TCDS r03/r04 | 40080 / 40080 |
| Fabric x4/x12 references r05–r08 | 322260 |
| Generated r09/r10 | 100000 / 325000 |
| Primary GT references r11–r23 except r13 | 322260–322261 |
| r13 rt_r0_l | 200000 |
| Other references r24–r37 | 320637–320639 |
| Managed RXUSRCLK2 r38 | 322262 |

The managed RX clock is now close to the primary reference, unlike the
pre-cycle 322009–322010 kHz readings. This observation cannot distinguish the
effect of power cycling from the subsequent FPGA reload. The approximately
320638-kHz reference group is unchanged and its intended configuration remains
to be checked.

F1_5 postprogram status byte 2 was 00, LOS/CDR LOL remained FF/FF, TX disable
00 and CDR enable FF. Thus the alarm precondition remains unresolved despite
the improved RX clock. A new baseline remains on hold rather than silently
treating the alarms as healthy. If a diagnostic baseline is explicitly chosen
despite these flags, use fresh sequence 1 after 0 / expected run ID 1 only
after rechecking current state; do not reuse pre-cycle sequence 4.
