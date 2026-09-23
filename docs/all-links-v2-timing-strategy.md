# All-links v2 timing-closure strategy

## Outcome

All-links v2 (`0x00020501`) ultimately closed timing by changing the RTL
architecture and relaxing a non-functional locality assumption—not by adding
timing exceptions or repeatedly changing implementation directives.

The successful design:

- replaced the central 112-to-1 result-publication mux with four registered
  result-copy banks;
- split each lane's 256-bit snapshot transfer into four 64-bit handshakes;
- added cycle-matched local reset release at every quad; and
- hard-contained only the eight real control/reset boundary registers per SLR.

Result-copy bank placement was left soft. In the final route, the SLR0 copy
bank naturally split 24/233 cells across SLR0/SLR1, while the other three banks
were resident in SLR1/SLR2/SLR3. This placement is functionally valid and is
reported by the audit rather than rejected.

The normal nonincremental implementation passes setup/hold at WNS/WHS
`+0.046/+0.009 ns`, routes all 220,150 routable nets, has zero routing or
Error-DRC failures, and meets all 476 bus-skew constraints. The independent
audit passes the exact 112-channel/28-common/12-REFCLK topology, CDC and
descriptor/session behavior, and strict 6/8/8/6 participation/reset-boundary
residency. Evidence is frozen under
`build/diagnostic_archive/all-links-v2-timing-hardened-control-boundary-clean/`.

## Relevant v1 precursor attempts

V1 established what not to repeat. A whole-wrapper 6/8/8/6 hard pblock made
setup worse (`-1.412 ns`). Enumerated-leaf and `KEEP_HIERARCHY` approaches
improved estimated timing but failed mandatory locality proofs, with 506 and
257 optimized leaves escaping their expected SLRs. The later four-bank v1
structure reduced the routed failure to only 22 `clk_200` endpoints at
`-0.034 ns`; one controlled post-route `phys_opt_design` closed it at
`+0.001 ns`. That artifact was nevertheless unusable for the final goal
because v1's all-quad acquisition/capture reductions deadlocked direct-only
requests. V2 first repaired that functional defect, then required fresh timing
closure.

## Attempts that did not close the build

| Attempt | Result | Why it was rejected |
|---|---:|---|
| Original normal v2 route | WNS/TNS `-0.158/-26.399 ns`, 580 endpoints in 18 clock groups | The failure was broad, so v1's narrow post-route closeout recipe was not justified. |
| Incremental implementation from the timing-clean v1 routed DCP | WNS/TNS `-0.119/-5.883 ns`, 93 `clk_200` endpoints | Reused 98.94% of cells and 97.08% of nets and improved timing substantially, but still failed signoff. |
| One hash-pinned plain post-route `phys_opt_design` on that incremental route | Still WNS/TNS `-0.119/-5.883 ns` | No legal margin was recovered; no reroute, directive sweep, seed change, exception, or retry followed. |
| First source-level banked/split-copy implementation | Timing clean at WNS/WHS `+0.034/+0.009 ns` | The audit incorrectly required every result-copy bank to reside wholly in its nominal SLR; the SLR0 bank's valid 24/233 SLR0/SLR1 placement failed that diagnostic policy. |
| Hard-pblock the result-copy stages to satisfy that locality rule | WNS/TNS `-0.103/-7.373 ns`, 218 endpoints | The hard locality constraint removed useful placement freedom and made timing worse. |

Operational preflight/query retries are archived separately; they did not
represent alternative timing strategies and did not change the design.

## Why the final strategy worked

The original problem combined a wide centralized publication path with
high-fanout cross-SLR control. Banking and narrowing the copy transfer reduced
the physical span and combinational width at the source. Local reset release
removed another avoidable cross-SLR control path. Hard placement was then used
only where physical residency was a real interface invariant; the placer was
free to optimize the large publication-only copy structures.

The reusable lesson is: first remove centralized wide/fanout structures in
RTL, then constrain only genuine physical boundaries. Treat convenient
hierarchy-to-SLR alignment as an observation unless functionality requires
it. Do not manufacture closure with speculative false paths, repeated seeds,
or hard pblocks around large data structures.

Final compressed artifact SHA-256 values are:

- BIT: `163172d938f5aa87fd606061e75e058f5d7040916d86d4744a206309f970b66f`
- routed DCP: `323ff58252ae66a81e42c84d38b528ce053561804cdc7eeecb99d3066107993a`
- ELF: `d947fd47e684a1e0be08296d34b4de1b1e28d7c056ecabffcbfb681786730f9c`
