# Golden reference and existing-v5 subset review — 2026-09-16

## Decision

**Simulation gate GO; hardware prerequisite not yet complete.** No new RTL,
firmware, or bitstream is required by the tested reduced-mask behavior.
Both FPGAs remain user-loaded golden; this review did not reset/program them,
clear IBERT counters, change patterns/loopback, or manipulate optical modules.
Do not call this eleven-lane or twelve-lane hardware qualification.

The intended next experiment keeps F1 golden as the continuous known-good TX,
replaces F2 only with the exact audited v5, starts its required bounded local
TX session (mask FFF), and measures F2 RX with mask **0DFF**. The physical
connection is F1_1 TX → F2_1 RX only. F2 TX settings cannot affect that optical
input; its own TX-session dependency is a v5 command-policy requirement.

## Golden reference: facts and missing evidence

User reports golden PRBS31 working on eleven external lanes, TXDIFFCTRL
01001 (GUI 630 mV), zero precursor/postcursor, with no new errors after the
mapping test's restored masks and manual IBERT counter reset. X0Y13 alone
fails externally but passes F2 near-end PMA; it maps to weak optical Rx02.
See [mapping evidence](firefly1-rx-channel-mapping.md).

This is not a timed/bit-counted baseline. No counter denominator or final
per-lane loopback/pattern dump has yet been captured, including the final
X0Y13 loopback setting after PMA. These remain prerequisites before reloading
F2 and losing the current golden receiver reference.

New fixed `scripts/capture_firefly1_golden_readonly.tcl` requests existing
q121–123 GT/RX/TX properties twice, separated by ten seconds. It does not
create links, commit controls, program, or
reset counters. Interpret actual monotonic counter deltas and configuration
before accepting a baseline; script completion alone is not a pass.

Its first execution failed before opening any target:
`build/logs/capture_firefly1_golden_readonly-20260916T202346Z.log`.
The fixed historical endpoint `TCP:lnx4189:3121` was unreachable. Subsequent
read-only process inspection on lnx4189 found the existing user's GUI Vivado
PID4097909 and hardware server PID4098231. The latter is launched with
`-s TCP:127.0.0.1:3121`: **it is bound to loopback only**, not absent.
No process was started/stopped during that discovery. The user subsequently
rejected dependence on the incidental GUI server. Parent added
`python3 scripts/board_golden_xvc.py capture`: it runs on lnx4189, owns a
temporary private localhost43121 bridge, and opens the board explicitly with
`open_hw_target -xvc_url apollo3010-1:2542`. The GUI server is untouched.
Vivado IBERT requires this bridge; XSDB programming already uses direct XVC.
The first independent bridge started successfully but opening the XVC target
timed out, before device discovery. Log:
`build/logs/capture_firefly1_golden_readonly-20260916T204924Z.log`.
The launcher cleaned up its bridge. No FPGA controls changed; no timed
baseline was captured. A competing GUI connection is possible, not proven.

## Offline golden/v5 routed settings comparison

Entry point: `scripts/compare_firefly1_golden_v5_settings.tcl`, using the
approved Vivado helper. Complete log:
`build/logs/compare_firefly1_golden_v5_settings-20260916T202309Z.log`.
Both routed checkpoints were opened read-only; no saved artifact changed.

- Golden DCP SHA256:
  `d16b17be6dde7fe53698a4e3779f4ae0759b8e2935e768f9a9637102a26cc618`.
- V5 DCP SHA256:
  `7d29be615970170d32abfd2e6ca2c497e9494d5117749e9cfeb2c3b80f5123d1`.

For all twelve X0Y4–15 channels:

| Setting | Golden | Routed v5 |
|---|---|---|
| TXDIFFCTRL | Runtime-programmable; user reports 9 / 01001 | Constant **24 / 11000** |
| TXPRECURSOR / TXPOSTCURSOR | Runtime-programmable; user reports 0 / 0 | Constant 0 / 0 |
| RX/TX polarity | Runtime-programmable; live values not captured | Constant 0 / 0 |
| RXLPMEN | Runtime-programmable; live value not captured | Constant 1 (LPM) |
| ADAPT_CFG1 | F81C | F81C |
| RXCDR_CFG3 | 0012 | 0012 |
| RXDFE_GC_CFG2 | FFF0 | FFF0 |
| RX_DEGEN_CTRL | 100 | 100 |
| RX_DFE_AGC_CFG1 | 2 | 2 |
| RX_SUM_DEGEN_AVTT_OVERITE | 0 | 0 |
| RX_SUM_VCMTUNE | 0011 | 0011 |
| RX/TX_DATA_WIDTH | 80 / 80 | 80 / 80 |
| RX/TX_INT_DATAWIDTH | 2 / 2 | 2 / 2 |

Static properties match in this selected comparison, but this is not an
exhaustive GT-property comparison or a live golden DRP readback. Golden's
dynamic controls cannot be inferred from its checkpoint. The TX swing
difference is concrete and relevant to later managed-transmitter testing;
it does not require changing F2's unconnected transmitter for the proposed
one-way receiver-isolation experiment.

## Existing-v5 three-quad subset simulation

Sources: `sim/tb_firefly1_v5_subset.sv` and
`scripts/run_firefly1_v5_subset_sim.tcl`. Passed log:
`build/logs/run_firefly1_v5_subset_sim-20260916T202251Z.log`.

The test instantiates the actual v5 engine, twelve actual managed lane
engines with asynchronous XPM snapshot crossings, three actual
`gt_prbs_test_controller` instances, three actual `gt_quad_controller`
instances, and three actual lane-reset policies. It mirrors the group
wrapper's AND-ready/AND-capture/OR-fault reductions and v5 scalar-reset
broadcast; it does not instantiate the full generated GT wrappers. RX clocks
are independent. Analog GT behavior, healthy external PRBS source, DRP data
and CPU register transport are modeled, not hardware-validated.

The actual 200,000-management-cycle acquisition observation remains intact.
Supervisor reset/init and operation timeout constants are shortened for
simulation; receiver measurement uses 1000 management cycles rather than
the ten-second hardware duration. Existing v5 recovery/integrity switches
retain their native wrapper defaults (off), staged acquisition on, mandatory
error-free qualification off. No RTL parameter or production source changed.

Checks that passed:

1. External descriptor without a local TX session is rejected, no run ID.
2. Lane9 remains PRBS-unlocked and continuously error-active. Two consecutive
   0DFF measurements each finish with exactly eleven selected/pass records,
   summary **000B0B01**, nonzero bits/cycles, zero errors/native lock losses.
3. Excluded lane9's published 256-bit record is exactly integer9: lane ID only,
   all status/counter fields zero. Both handshake phases and publication banks
   are exercised. All three controllers return healthy IDLE; session stays on.
4. Explicit idle session stop succeeds without altering the receive result.
5. A missing lock on **selected lane0** still times out and publishes exactly
   eleven requested synthetic failures, **0B000B04**, with quad0 PRBS fault.
   Existing v5 aggregate-fault TX termination remains unchanged.
6. Physical RX-reset-done loss on **excluded lane9** still faults quad123's
   supervisor: PRBS masking does not bypass physical reset/clock readiness.

The first compile caught a testbench-only reserved identifier (`checker`);
renaming it to `checker_enable` fixed compilation. No product RTL change was
needed. The failed compile log is retained separately at
`run_firefly1_v5_subset_sim-20260916T202202Z.log`.

## Remaining gate

Obtain live golden controls and counter deltas for all eleven healthy F2 RX
lanes while preserving F1 TX. Verify external loopback/patterns, nonzero bit
deltas, no new errors or lost lock, and unambiguous physical device order.
Then parent may review the new fixed one-way launcher and the fresh F2-only
hash-pinned programmer. Do not replay consumed v5 PMA/external launchers.
