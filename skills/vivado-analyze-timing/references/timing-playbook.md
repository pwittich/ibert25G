# Timing playbook

## Triage order

1. `check_timing`: missing clocks, unconstrained endpoints, loops, multiple clocks, and invalid generated clocks.
2. Clock report: periods, waveforms, generated-clock sources, and propagated clocks.
3. Clock interaction: asynchronous and partially constrained clock pairs.
4. Timing summary: setup, hold, and pulse width by path group.
5. Detailed worst paths: logic depth, routing share, fanout, skew, uncertainty, and physical distance.
6. Exception coverage: confirm each exception reaches exactly the intended paths.

## Common responses

- High logic delay: pipeline or restructure priority/mux/arithmetic logic.
- High routing delay: reduce fanout, improve hierarchy/placement, register replication, or relieve congestion.
- Hold failure: let implementation repair it; inspect clock skew and over-broad constraints before manual delay insertion.
- Cross-clock path: use a correct synchronizer/FIFO/handshake and constrain the relationship accurately.
- Missing generated clock: define it at the actual clock-transforming output and verify its master/source.
- Apparently impossible period: confirm units and source frequency before editing constraints.

## Sign-off

Require non-negative setup and hold slack, no unintended unconstrained paths, explainable clock interactions, reviewed exception coverage, and stable results at the routed stage. For this design, explicitly verify the 200-MHz board clock, 50-MHz divided IBERT debug clock, and all configured 322.265625-MHz GT reference clocks.

