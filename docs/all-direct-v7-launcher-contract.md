# All-direct fixed launcher contract

Date: 2026-09-17

## 2026-09-18 v12 completion

The current fixed contract pins symmetric v12 / `0x00020409` with BIT/DCP/ELF
SHA-256 `5bce735128e22f3be029972e0290bf8a552dc196e08258a071b7ef31b30c5697`,
`68d0e0535f4eb8f4b17169545a0f171415222da342a2bd1170a8942523454260`,
and `a2370f4b0b6132bffef5323aca834b5a4c174dfedeb4b0c113df6a0bc6a3c163`.
The retained v12 contract and programmer resolve those pins only from
`build/diagnostic_archive/direct-all-v12-0x00020409-scoped-pass/artifacts/`;
the adjacent manifest covers all cited build and hardware evidence.
Its exclusive remote namespace is `/tmp/all-direct-v12-20260918`. Public
stages are only `status`, `pma-f1`, `pma-f2`, and `external`; the historical
resume path is not exposed.

All fixed stages passed and are consumed. Both all-56 PMA gates passed, then
the simultaneous bidirectional external gate passed all 54 fitted lanes per
site with zero errors/native lock losses. Safe stops consumed sequence 4 and
left both endpoints healthy IDLE at run 2 with stable publications and no
retained fault. Do not reuse the namespace or any stage sentinel. See
`docs/direct-all-v12-hardware-gate.md`.

## 2026-09-18 v10 addendum

The historical symmetric v10 image is `0x00020407`, with BIT/DCP/ELF SHA-256
`220e27906cb3433527420615b9e3fa61a26cf2954c365596394cb6e4f615f458`,
`09e3e226f9aeaf0716f3a444f47d8eb4412d466ad4f3233eae1064db8e51b185`,
and `c4893050ae26e28ad09b1bd85f7dbce106812400d50dc658052a53fe6917a151`.
Its clean implementation and independent audit pass at signoff WNS/WHS
+0.084/+0.010 ns. The applied-session acknowledgement, its physical SLR-group
pipeline, all 14 CDC pairs, all 14 cleanup guards, and all 56 cleanup lane
acknowledgements are present in the routed design.

Both one-shot 56-lane PMA stages passed. The first v10 external launcher
attempt consumed only F1 sequence 2: hardware correctly reported active plus
applied/ready as `0x00320000`, but the launcher expected the old
active-without-ready value `0x00120000`. It failed before starting F2 and
before either RX request, so there is no external measurement to interpret.
The exact evidence is
`build/diagnostic_archive/all-direct-v10-external-1789729763630531.log`.

The repaired launcher requires both status bits 17 and 21 in active state and
tests that omission of ready is rejected. It uses the new non-overwriting
remote directory `/tmp/all-direct-v10r1-20260918`; the consumed v10 directory
must not be reused. This repair does not authorize a retry, reload, reset, or
new measurement. A later read-only snapshot confirmed the 180-second lease
expired normally: F1 is IDLE at sequence/ack 2, run 1 with state `0x00140000`
(capability plus expiry latch), while F2 remains IDLE at sequence/ack/run 1
with state `0x00100000`.

## Historical v7 launcher baseline

The remainder of this file records the original released launcher contract
for expanding the completed v6 one-quad gate to every fitted direct F1<->F2
connection. The launchers are intentionally
fail-closed: `scripts/all_direct_v7_contract.py` has exact endpoint programming
choices and BIT/DCP/ELF hashes.  The symmetric firmware identity is
`0x00020404`; its shared ELF is pinned as
`fc3d71793950d5ab161b23c842daffbbc08a3dde3e92644047ec919acd77ffb4`.
The compressed bitstream is
`d16d6be685087abcff281319c2def2bba195793ae8c6fd7756bb0dd14c46a75f`
and the routed DCP is
`ff2fedc90a0791c1f7edc3b53e6aa44c4a355cfe4ea1d4d81e7f17fea3379cc8`.
The independent audit passed at WNS/WHS +0.060/+0.010 ns with zero route/DRC
errors, compression, all 56 golden GT properties and all 14 refclk/skew checks.
The launcher still fails closed on any local or deployed hash mismatch.

The corrected, non-overwriting namespace is `all_direct_v7r1`; its fixed remote
directory is `/tmp/all-direct-v7r1-20260917`.  It does not extend or reuse the
consumed v6 directory or the original v7 directory.  The original v7 PMA-F1
launcher stopped before submitting a request because its preflight incorrectly
included `r13`/`0x34` (`rt_r0_l`) among the direct-link references.  Both
endpoints remained fresh at sequence/run 0.  V7r1 checks the routed design's
exact six references N, P, B, E, G and I and explicitly excludes `0x34`.

## Lane selections

The design owns all 56 direct GT channels, global lanes 56-111, with mask
words:

```
00000000 FF000000 FFFFFFFF 0000FFFF
```

That exact mask is used for both near-end PMA gates and for each bounded TX
session.  It excludes every 10-Gb/s AXI C2C lane.

Only 54 receive paths are physically fitted in each direction.  Schematic
page 81/sheet 9.05 shows that F1 P/q224 to F2 G/q231 has only two of four
lane pairs populated, while the reciprocal F1 G/q231 to F2 P/q224 direction
has all four.  Therefore the external receive masks are endpoint-specific:

- F1 measures every managed lane except q224 channels 2-3, global 70-71.
- F2 measures every managed lane except q231 channels 0-1, global 96-97.

Both external results consequently require normal 54-lane summary
`0x00363601`.  PMA requires normal 56-lane summary `0x00383801`.  The release
contract derives each four-word receive mask from its explicit lane tuple and
rejects a count, range, duplicate or lane/mask mismatch.

## Fixed stages

After release, the only local entry point is:

```
python3 scripts/board_all_direct_v7.py deploy|status|pma-f1|pma-f2|external
```

The ordered one-shot state machine is:

1. `deploy` creates the new remote directory exclusively, copies the three
   fixed files, and verifies every remote SHA-256.  It also verifies both
   endpoint BIT/ELF hashes locally.  It does not program hardware.
2. Separate, hash-pinned programming choices must program F1 and F2 only after
   both routed audits pass.  Those choices are recorded independently in the
   shared contract even if review approves a single symmetric image.
3. `pma-f1` requires both endpoints fresh at sequence/run 0, then consumes F1
   sequence/run 1 for a ten-second all-56-lane near-end PMA test.  F2 remains
   untouched.
4. `pma-f2` requires and revalidates F1's preserved run 1, then consumes F2
   sequence/run 1 for the equivalent all-56-lane PMA test.
5. `external` requires both preserved PMA passes.  It starts bounded 180-second
   all-56 TX sessions at sequence 2, submits endpoint-specific fitted-RX
   ten-second PRBS31 requests at sequence 3/run 2, and requires an actual
   observed simultaneous RUN interval.  Both complete publications and all
   108 selected lane records are captured and validated before either TX
   session is stopped.  Safe stops consume sequence 4 without changing run 2,
   and the final publications must remain stable.

Every hardware stage has an exclusive creation sentinel; there is no replay,
retry, reset, reload, arbitrary mask, duration, path, host or command.  The
remote process holds a nonblocking ownership lock for its entire MCU session.
The `cm_interface` FPGA objects continue to provide the per-transaction I2C5
software semaphore and one-site mux selection.

All required generated clocks and the six direct REFCLK0 monitor values
(`r11`, `r12`, and `r14`-`r17`) must be valid on both endpoints.  Every selected record must be
nonzero, have an exact 80-bit/cycle denominator, zero errors, zero native lock
losses and the correct global-lane ID.  Failures preserve evidence and attempt
only an exact-state safe TX stop; lease expiry bounds any transmitter that
cannot be proved safe to stop.  Nothing performs programming, reset, optical
stimulus, automatic recovery or a second measurement.

This gate provides broad direct-link functional coverage.  It is not channel
requalification or a long-BER qualification.

## Completed release checks

- F1/F2 identity values were frozen after source review.
- Endpoint program choices and BIT/DCP/ELF paths and exact SHA-256 pins are in
  `scripts/all_direct_v7_contract.py`.
- Matching fixed choices and the existing two-device/F1-target-1/F2-target-4
  topology guards are in the existing programmer; raw programming remains out
  of this launcher.
- Simulation, compressed build, independent routed audit and golden-property
  comparison passed before `RELEASED = True`.
- Offline launcher tests pass with the released contract.
- Narrow command approval and separate hardware authorization remain required before
  invoking any programming or one-shot gate.
