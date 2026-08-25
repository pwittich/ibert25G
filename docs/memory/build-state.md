# VU13P IBERT Build State

Last updated: 2026-08-24

## Last validated implementation

The clean documented batch run completed on 2026-08-24 at 19:23 and wrote a
valid, uncompressed bitstream. Routing had 800,029 fully routed nets and no
failed, unrouted, partially routed, or overlapping nets.

- Overall setup: WNS `+0.258 ns`, TNS `0`, no failing endpoints.
- Overall hold: WHS `+0.009 ns`, THS `0`.
- Pulse width: WPWS `+0.251 ns`, TPWS `0`.
- Routed clock report: `clk_200` 200.000 MHz, `clk_100_raw` 100.000 MHz,
  `clk_325_raw` 325.000 MHz, and `ibert_debug_clk_50` 50.000 MHz.
- The overall worst setup path is an IBERT RX/TX user-clock relationship, not the 200-MHz or debug network.
- Bitstream: `build/vu13p_ibert_25g.runs/impl_1/top.bit`.
- Bitstream SHA-256: `e65f72902fa6f27276fcbc2369d37c6c07d2ffd56b26bc889ce7fa9c00abc0a2`.
- Timing report: `build/vu13p_ibert_25g.runs/impl_1/top_timing_summary_routed.rpt`.
- All four reported bus-skew constraints pass; the smallest slack is
  `+19.250 ns`.

## Root cause and resolution

The original timing failure was not caused by ordinary 200-MHz monitor/I2C logic. The generated IBERT debug/DRP network had been attached to the board's 200-MHz fabric clock even though vendor constraints expected 50 MHz. Its worst path crossed SLRs from the debug hub to IBERT XSDB logic with roughly 2,045 fanout and about 5.8 ns of routing against a 5-ns period.

The fix was to retain 200 MHz for application logic and create a physical 50-MHz `BUFGCE_DIV` clock for `dbg_hub` and IBERT XSDB/DRP. Correct application of all 28 vendor quad pblocks was also required.

## Remaining review items before hardware use

- Routed DRC has no errors. It reports three generated debug-hub PDCN-1569
  violations, one RPBF-3 violation on bidirectional `i2c_scl_f_generic`, one
  RTSTAT-10 violation for generated debug/IBERT nets with no routable loads,
  and 672 generated-IP power advisories.
- Methodology reports contain many generated-IBERT warnings, notably TIMING-7 for related dynamically generated clocks, TIMING-17 for non-clocked sequential cells, and TIMING-54 scoped false paths. Timing passes, but these warnings should be dispositioned before programming hardware.
- GT routing reports north/south reference-clock pin swaps onto physically equivalent resources. Keep this in the hardware-review checklist.

## Working tree

The source changes associated with this build were not committed when this
file was last updated. Do not discard unrelated work or commit generated
products. The modifications cover pin/lane corrections, local IP generation,
synthesized-design validation, hierarchical floorplan hooks, the 50-MHz debug
clock, the 100/325-MHz MMCM, the generic-I2C register remap and direct-kHz
scaling, SysMon addressing, build timing checks, and documentation.
