# All-direct topology manifest

Date: 2026-09-17; current implementation record updated 2026-09-18

This is the design input for the native q221--q234 image.  The authoritative
board source is `Cornell_CM_Rev3_HW/Schematic/6089-127-RevA_23Jan2025.pdf`,
PDF pages 77--81 (sheets 9.01--9.05), checked against
`constraints/board_pins.xdc` and the golden right-IBERT packing in
`src/ibert_top.vhd`.  It is not inferred from a global `y -> 167-y` rule.

Both FPGA sites use the same VU13P package pins and the image owns every direct
quad, so one symmetric bitstream and firmware identity is sufficient.  The
endpoint-specific difference belongs in the external-test lane masks, not the
FPGA image. The original v7 identity was `0x00020404`, historical v10 was
`0x00020407`, and current v12 is `0x00020409`. All use the same managed/PMA/
TX-session mask, exactly global lanes 56--111. V10's historical record is in
`docs/direct-all-v10-hardware-gate.md`.

The schematic proves 54 fitted bidirectional links, not 56.  Sheets 9.01--9.04
contain twelve complete four-lane mappings.  Sheet 9.05 contains a complete
F1 G/q231 to F2 P/q224 mapping and only two fitted pairs in the reciprocal
F1 P/q224 to F2 G/q231 mapping; it explicitly says PCB space supports two of
four pairs.  Therefore an external receive test selects all managed lanes
except F1 globals 70/71 and all managed lanes except F2 globals 96/97.  PMA
loopback still selects all 56 local GT channels.

All fitted nets preserve P-to-P and N-to-N polarity through AC coupling.  The
remote GT channel is reversed within every connector quartet.  The last column
is the remote connector and remote GT channel, not merely a naming suffix.

| Connector | GT channel | Global | Site | RX P/N package | TX P/N package | REFCLK0 source/route | Remote connector/channel |
|---|---:|---:|---|---|---|---|---|
| M | 0 | 56 | X1Y4 | BK18/BK17 | BL15/BL14 | N south | J/3 |
| M | 1 | 57 | X1Y5 | BL20/BL19 | BK13/BK12 | N south | J/2 |
| M | 2 | 58 | X1Y6 | BL6/BL5 | BL11/BL10 | N south | J/1 |
| M | 3 | 59 | X1Y7 | BJ6/BJ5 | BK9/BK8 | N south | J/0 |
| N | 0 | 60 | X1Y8 | BH4/BH3 | BG11/BG10 | N local | I/3 |
| N | 1 | 61 | X1Y9 | BG2/BG1 | BJ11/BJ10 | N local | I/2 |
| N | 2 | 62 | X1Y10 | BG6/BG5 | BH9/BH8 | N local | I/1 |
| N | 3 | 63 | X1Y11 | BF4/BF3 | BF9/BF8 | N local | I/0 |
| O | 0 | 64 | X1Y12 | BE2/BE1 | BE7/BE6 | N north | H/3 |
| O | 1 | 65 | X1Y13 | BD4/BD3 | BD9/BD8 | N north | H/2 |
| O | 2 | 66 | X1Y14 | BC2/BC1 | BC7/BC6 | N north | H/1 |
| O | 3 | 67 | X1Y15 | BB4/BB3 | BB9/BB8 | N north | H/0 |
| P | 0 | 68 | X1Y16 | BA2/BA1 | BA7/BA6 | P local | G/3, fitted only F1-to-F2-G direction |
| P | 1 | 69 | X1Y17 | AY4/AY3 | AY9/AY8 | P local | G/2, fitted only F1-to-F2-G direction |
| P | 2 | 70 | X1Y18 | AW2/AW1 | AW7/AW6 | P local | G/1, unfitted on F1 P receive |
| P | 3 | 71 | X1Y19 | AV4/AV3 | AV9/AV8 | P local | G/0, unfitted on F1 P receive |
| A | 0 | 72 | X1Y20 | AU2/AU1 | AU7/AU6 | B south | F/3 |
| A | 1 | 73 | X1Y21 | AT4/AT3 | AT9/AT8 | B south | F/2 |
| A | 2 | 74 | X1Y22 | AR2/AR1 | AR7/AR6 | B south | F/1 |
| A | 3 | 75 | X1Y23 | AP4/AP3 | AP9/AP8 | B south | F/0 |
| B | 0 | 76 | X1Y24 | AN2/AN1 | AN7/AN6 | B local | E/3 |
| B | 1 | 77 | X1Y25 | AM4/AM3 | AM9/AM8 | B local | E/2 |
| B | 2 | 78 | X1Y26 | AL2/AL1 | AL7/AL6 | B local | E/1 |
| B | 3 | 79 | X1Y27 | AK4/AK3 | AK9/AK8 | B local | E/0 |
| C | 0 | 80 | X1Y28 | AJ2/AJ1 | AJ7/AJ6 | B north | D/3 |
| C | 1 | 81 | X1Y29 | AH4/AH3 | AH9/AH8 | B north | D/2 |
| C | 2 | 82 | X1Y30 | AG2/AG1 | AG7/AG6 | B north | D/1 |
| C | 3 | 83 | X1Y31 | AF4/AF3 | AF9/AF8 | B north | D/0 |
| D | 0 | 84 | X1Y32 | AE2/AE1 | AE7/AE6 | E south | C/3 |
| D | 1 | 85 | X1Y33 | AD4/AD3 | AD9/AD8 | E south | C/2 |
| D | 2 | 86 | X1Y34 | AC2/AC1 | AC7/AC6 | E south | C/1 |
| D | 3 | 87 | X1Y35 | AB4/AB3 | AB9/AB8 | E south | C/0 |
| E | 0 | 88 | X1Y36 | AA2/AA1 | AA7/AA6 | E local | B/3 |
| E | 1 | 89 | X1Y37 | Y4/Y3 | Y9/Y8 | E local | B/2 |
| E | 2 | 90 | X1Y38 | W2/W1 | W7/W6 | E local | B/1 |
| E | 3 | 91 | X1Y39 | V4/V3 | V9/V8 | E local | B/0 |
| F | 0 | 92 | X1Y40 | U2/U1 | U7/U6 | E north | A/3 |
| F | 1 | 93 | X1Y41 | T4/T3 | T9/T8 | E north | A/2 |
| F | 2 | 94 | X1Y42 | R2/R1 | R7/R6 | E north | A/1 |
| F | 3 | 95 | X1Y43 | P4/P3 | P9/P8 | E north | A/0 |
| G | 0 | 96 | X1Y44 | N2/N1 | N7/N6 | G local | P/3, unfitted on F2 G receive |
| G | 1 | 97 | X1Y45 | M4/M3 | M9/M8 | G local | P/2, unfitted on F2 G receive |
| G | 2 | 98 | X1Y46 | L2/L1 | L7/L6 | G local | P/1, fitted partial pair |
| G | 3 | 99 | X1Y47 | K4/K3 | K9/K8 | G local | P/0, fitted partial pair |
| H | 0 | 100 | X1Y48 | J2/J1 | J7/J6 | I south | O/3 |
| H | 1 | 101 | X1Y49 | H4/H3 | H9/H8 | I south | O/2 |
| H | 2 | 102 | X1Y50 | G2/G1 | G7/G6 | I south | O/1 |
| H | 3 | 103 | X1Y51 | F4/F3 | F9/F8 | I south | O/0 |
| I | 0 | 104 | X1Y52 | E2/E1 | D9/D8 | I local | N/3 |
| I | 1 | 105 | X1Y53 | D4/D3 | B9/B8 | I local | N/2 |
| I | 2 | 106 | X1Y54 | E6/E5 | C11/C10 | I local | N/1 |
| I | 3 | 107 | X1Y55 | C6/C5 | E11/E10 | I local | N/0 |
| J | 0 | 108 | X1Y56 | A6/A5 | A11/A10 | I north | M/3 |
| J | 1 | 109 | X1Y57 | A20/A19 | B13/B12 | I north | M/2 |
| J | 2 | 110 | X1Y58 | B18/B17 | A15/A14 | I north | M/1 |
| J | 3 | 111 | X1Y59 | C20/C19 | C15/C14 | I north | M/0 |

The six physical REFCLK0 inputs are N `AY13/AY12`, P `AT13/AT12`,
B `AM13/AM12`, E `AA11/AA10`, G `U11/U10`, and I `N11/N10` in
`constraints/board_pins.xdc`.  The intended dedicated routes are
q221=N-south, q222=N-local, q223=N-north; q224=P-local;
q225=B-south, q226=B-local, q227=B-north; q228=E-south,
q229=E-local, q230=E-north; q231=G-local; and q232=I-south,
q233=I-local, q234=I-north.  QPLL0 is selected in every quad, so only the
`GTYE4_COMMON` primitive consumes the corresponding `GTSOUTHREFCLK00`,
`GTREFCLK00`, or `GTNORTHREFCLK00` dedicated input. Each channel's direct
REFCLK primitive pins are intentionally unused; its `QPLL0CLK` and
`QPLL0REFCLK` must instead be driven directly by that quad common's
`QPLL0OUTCLK` and `QPLL0OUTREFCLK`. The routed audit proves all 14 physical
common routes and all 112 common-to-channel QPLL0 connections, rejecting any
fabric clock element.

## Historical v7 build and independent audit

The symmetric identity is `0x00020404`. Firmware and all engine, aggregate,
dual-endpoint, and descriptor-transfer regressions pass. The final compressed
routed image independently audits at WNS/WHS +0.060/+0.010 ns, zero routing
or DRC errors, and fourteen passing descriptor bus-skew constraints (worst
+1.809 ns). All 56 `GTYE4_CHANNEL_X1Y4`--`X1Y59` primitives match the golden
IBERT at 2,801 shared non-metadata properties per site (156,856 comparisons,
zero mismatches).

Final SHA-256 values:

- bit: `d16d6be685087abcff281319c2def2bba195793ae8c6fd7756bb0dd14c46a75f`
- routed DCP: `ff2fedc90a0791c1f7edc3b53e6aa44c4a355cfe4ea1d4d81e7f17fea3379cc8`
- ELF: `fc3d71793950d5ab161b23c842daffbbc08a3dde3e92644047ec919acd77ffb4`

This establishes build and routed-audit readiness only. No v7 image has been
programmed and no v7 hardware request has been issued.
