# Full Milestone 3 v15 — programming/interface failure

## Audited artifact

Full v15 (`0x0002000F`) is a separately versioned full-Milestone-3 candidate
with the same runtime policy as v14.  The complete simulation suite, matching
firmware, compressed implementation, and independent routed audit passed on
2026-09-14.  The audit passed timing, routing, routed DRC, bus-skew, 112-owner
GT placement, managed-channel properties, descriptor bounds, direct profile
sources, and runtime-integrity structure checks.  Existing generated-IP and
intentional CDC/methodology findings remain reviewed caveats; this is not a
claim of global CDC cleanliness.

- Bitstream SHA-256:
  `789c668c7bcf2bf30ac9046b6a6546819c64e4f64c8d81955431245a8a14b7f3`
- Firmware SHA-256:
  `b62b160c483aac2a7d323d2e1307977bdb39483bbc117f9e3f09c6a269006391`
- Routed audit reports: `build/gt_test_milestone3_v15_audit/`

## Attempted hardware gate — 2026-09-15

Before reconfiguration, the designated read-only helper preserved F1's v14
healthy IDLE state at request/response/run ID 2 and its four clean lane
records.  The serialized MCU preflight reported F1 at 54.3125 C, valid clock
monitor status (`0x434da501`), and the required 100.000- and 325.000-MHz
monitor clocks.

The designated v15 deploy helper copied and SHA-256 verified its fixed
external-smoke bundle on `apollo3010-1`.  The designated programming helper
verified both v15 artifact hashes, selected F1 as the required JTAG target 1,
and began `fpga -file` through `TCP:apollo3010-1:2542`.  It did **not** emit
its required `PROGRAM_F1_COMPLETE` marker.  The immediate post-program
mailbox identity read failed at `0xA0` with MCU `ADDR_ACK_ERROR`; the F1
generic interface was unavailable.  A second read-only clock capture failed
the same way at `0x9C`.  The read-only JTAG helper printed its XVC endpoint
begin marker but did not reach its target-list return/end markers.

No v15 mailbox request was written, no run ID was incremented, and no smoke
test was started.  This is a programming/JTAG-or-generic-interface failure,
not a failed v15 test and not evidence about the candidate's PRBS or
runtime-integrity behavior.  Do not retry programming, reset, or issue a test
request silently.

Failure-context telemetry was captured before any further hardware change:

- MCU: F1 temperature 35.5 C, AVTT 1.20020 V, AVCC 0.90137 V, VCCINT
  0.85059 V.
- F1 AVTT and AVCC regulator status words were clear; telemetry was 1.20605 V
  / -1.86719 A / 35.0625 C and 0.90503 V / -0.62988 A / 36.125 C,
  respectively.  The current sign is raw/unvalidated.
- F1_5 and F1_6 retained the pre-existing page-0 alarm bytes `03=FF`,
  `05=FF`, `62=FF`; no module stimulus was performed.

The next action requires restoring a responsive XVC/JTAG and F1 generic
interface, then a new explicit decision on whether to make one fresh v15
programming attempt.  The fixed v15 test helper remains constrained to
sequence 1 after 0, then sequence 2 after 1, with evidence logs and no retry
path.

## Explicitly authorized repeat — 2026-09-15

The user explicitly authorized one repeat of the programming attempt.  The
same designated, hash-pinned helper again verified the v15 artifact hash and
selected F1 target 1, but again did not emit `PROGRAM_F1_COMPLETE`.  The
immediate mailbox identity read again failed at `0xA0` with `ADDR_ACK_ERROR`.
No v15 request was issued.  This reproduces the programming/JTAG-or-generic-
interface failure; it does not authorize further programming attempts or test
requests without new direction.

## Final post-power-cycle attempt — 2026-09-15

After the user power-cycled the board, the designated helper saw two bare
`xcvu13p` JTAG targets, consistent with unconfigured FPGAs, verified the same
v15 hash, and selected F1 target 1. It again did not emit
`PROGRAM_F1_COMPLETE`; the immediate mailbox identity read again failed at
`0xA0` with `ADDR_ACK_ERROR`. The power cycle therefore did not restore the
programming path or generic interface. No v15 test request was written.

## Manual-load hardware gate — 2026-09-15

The user subsequently loaded the exact v15 bitstream manually. The read-only
mailbox helper then verified firmware/hardware `0x0002000F`, healthy IDLE, and
a fresh sequence/run ID 0. This proves that the image itself and the F1 generic
interface are usable when configuration is performed outside the failing XSDB
helper path.

Two fixed, hash-verified, 60-second external PRBS31 requests were run without
any FPGA programming operation. Both were unique and completed normally:

- Sequence/run ID 1: normal response/summary `0x00040401`; all four managed
  lanes recorded 1,546,848,140,880 tested bits and 19,335,601,761 valid cycles,
  with zero errors and zero native lock losses (`BER95 < 1.939e-12`).
- Sequence/run ID 2: normal response/summary `0x00040401`; all four managed
  lanes recorded 1,546,848,008,240 tested bits and 19,335,600,103 valid cycles,
  with zero errors and zero native lock losses (`BER95 < 1.939e-12`).

The engine returned to healthy IDLE at sequence/run ID 2. No retained
first-fault snapshot is valid. Final MCU telemetry reported F1 at 53.5625 C,
AVTT at 1.20117 V, and valid monitor status `0x434da501`, including 100.000-
and 325.000-MHz monitor clocks and managed clocks near 322.26 MHz. This is a
clean initial external hardware gate, not full qualification and not evidence
about optical LOS, native CDR loss, or missing shared RXUSRCLK2. The earlier
automatic-programming failure remains a tooling/transport issue to resolve
independently; do not infer an image failure from it.

## Sequence-3 12-hour external soak — started 2026-09-15

The version-matched, hash-verified v15 soak helper accepted exact v15 IDLE
state after sequence/run ID 2, read back the external PRBS31 descriptor, and
committed the unique sequence-3 43,200,000-ms request. The engine entered RUN;
the published response/run ID correctly remains 2 while measurement is active.
The start evidence is `build/diagnostic_archive/v15-soak3-start.log`. Do not
reprogram, reset, disturb the optical path, or submit another request. Use
only the helper's read-only status operation until results are due.

## Sequence-3 12-hour external soak — completed 2026-09-15

The fixed sequence-3 soak completed normally with matching request/response/run
ID 3 and summary `0x00040401`. Each managed lane 12–15 recorded exactly
1,113,730,550,445,760 tested bits and 13,921,631,880,572 valid cycles, with
zero errors and zero native lock losses (`BER95 < 2.694e-15`). The engine is
healthy IDLE and no retry, reload, or reset occurred. Final MCU telemetry was
F1 54.4375 C and AVTT 1.203125 V; monitor status was valid and required
100/325-MHz plus managed clocks were present. Evidence is
`build/diagnostic_archive/v15-soak3-results.log`.
