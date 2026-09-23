# All-direct v12 build and hardware gate

Date: 2026-09-18

## Outcome

All-direct v12, FW/HW `0x00020409`, passed its scoped hardware gate on both
FPGAs. Each endpoint passed one all-56-lane, 10-second near-end PMA PRBS31
measurement. One overlapping bidirectional external measurement then passed
all 54 physically fitted receive lanes at each endpoint. Every selected record
had a nonzero denominator, zero errors, and zero native lock losses. Both
bounded TX sessions stopped successfully and both endpoints finished healthy
IDLE at sequence/ack 4 and run ID 2, with no retained platform fault.

This is broad functional coverage of every fitted direct link. It is not a
long-BER qualification and does not requalify channels already qualified by
the project.

## Repair and verification

V11 produced clean external publications but F1 later timed out in
`POST_CAPTURE_RX_REQUAL`: the Wizard-wide aggregate remained low even though
all selected primitive `RXRESETDONE` and `RXPMARESETDONE` indications and the
quad supervisor were healthy. V12 qualifies that state with the selected
per-lane RX and PMA acknowledgements. The Wizard aggregate remains diagnostic.

The updated recovery simulation explicitly holds the Wizard aggregate low
after restoring the selected per-lane acknowledgements and requires clean
return to IDLE. The complete managed-engine regression passed; its frozen log
is `build/diagnostic_archive/direct-all-v12-0x00020409-scoped-pass/build-logs/run_milestone3_unit_sim-20260918T125834Z.log`.

The compressed implementation and independent audits passed:

- signoff WNS/WHS `+0.019/+0.006 ns`, with zero failing endpoints;
- zero unrouted or partially routed nets and zero routed DRC errors;
- all fourteen 3-ns bus-skew constraints met, worst slack `+1.746 ns`;
- all 56 managed channels matched the golden GT primitive properties;
- all 14 dedicated common REFCLK routes and 112 QPLL0 connections matched;
- 14 controllers, 14 Wizard cleanup registers, 56 per-lane cleanup registers,
  14 post-cleanup IDLE guards, and 28 session synchronizer registers survived
  routing; and
- bitstream compression and MicroBlaze ELF population were confirmed.

The v12 implementation actually reused the archived v10 routed checkpoint
because the build Tcl still overrode the v11 reference prepared by the archive
helper. This was visible in the implementation log and is not hidden. Full
synthesis, implementation, and the independent audits still ran. The build
Tcl has since been corrected to select the archived v11 checkpoint for a v12
rebuild.

Principal logs:

- `build/diagnostic_archive/direct-all-v12-0x00020409-scoped-pass/build-logs/build_direct_all_v7_bitstream-20260918T130113Z.log`;
- `build/diagnostic_archive/direct-all-v12-0x00020409-scoped-pass/build-logs/audit_direct_all_v7_routed-20260918T133323Z.log`;
- `build/diagnostic_archive/direct-all-v12-0x00020409-scoped-pass/build-logs/inspect_direct_all_v7_cleanup_structure-20260918T133940Z.log`.

Artifact SHA-256 values:

- bitstream: `5bce735128e22f3be029972e0290bf8a552dc196e08258a071b7ef31b30c5697`;
- routed DCP: `68d0e0535f4eb8f4b17169545a0f171415222da342a2bd1170a8942523454260`;
- firmware ELF: `a2370f4b0b6132bffef5323aca834b5a4c174dfedeb4b0c113df6a0bc6a3c163`.

The exact BIT, routed DCP, ELF, and all evidence cited here are frozen under
`build/diagnostic_archive/direct-all-v12-0x00020409-scoped-pass/`; its
`MANIFEST.md` records original paths, archived paths, sizes, and hashes. The
retained v12 contract and programmer point only to those archived artifacts.

## Hardware record

The exact audited bitstream was programmed once on each FPGA through
`direct_all_v12_f1` and `direct_all_v12_f2`. Fresh status showed matching
FW/HW identity, sequence/run 0, healthy IDLE, valid reset acknowledgements,
and no retained fault.

F1 PMA sequence/run 1 passed all 56 lanes with summary `0x00383801`, about
257,808,204,560 tested bits per lane, zero errors, and zero lock losses. F2
then passed the equivalent gate with about 257,808,203,760 bits per lane while
F1's publication remained intact.

The external stage established bounded TX sessions at sequence 2 and submitted
the two sequence-3/run-2 measurements. Simultaneous RUN was observed. Both
sites returned summary `0x00363601`; all 108 selected records contained about
257,808,199,840--257,808,199,920 tested bits, zero errors, and zero lock
losses. F1 excludes unfitted lanes 70--71 and F2 excludes unfitted lanes
96--97. Stop sequence 4 succeeded on F2 and then F1. Both final states are
healthy IDLE at sequence/ack 4, run 2, state `0x00100000`, platform
`0x00000040`, with zero retained fault counter. The publications remained
stable across both stops.

Evidence:

- `build/diagnostic_archive/direct-all-v12-0x00020409-scoped-pass/hardware-logs/firefly1-v12-F1-program-1789740901787326.log`;
- `build/diagnostic_archive/direct-all-v12-0x00020409-scoped-pass/hardware-logs/firefly1-v12-F2-program-1789740968948376.log`;
- `build/diagnostic_archive/direct-all-v12-0x00020409-scoped-pass/hardware-logs/all-direct-v12-status-1789741026244775.log`;
- `build/diagnostic_archive/direct-all-v12-0x00020409-scoped-pass/hardware-logs/all-direct-v12-pma-f1-1789741039162442.log`;
- `build/diagnostic_archive/direct-all-v12-0x00020409-scoped-pass/hardware-logs/all-direct-v12-pma-f2-1789741070179165.log`;
- `build/diagnostic_archive/direct-all-v12-0x00020409-scoped-pass/hardware-logs/all-direct-v12-external-1789741106173900.log`.

All v12 hardware stages and their sentinels are consumed. Do not replay,
reload, reset, or issue a later request without a new explicit direction and a
reviewed launcher.
