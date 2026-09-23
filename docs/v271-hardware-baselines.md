# V271 hardware baseline gate

Date: 2026-09-12. F1 was explicitly programmed with isolated diagnostic v271 /
2.5.21, firmware and hardware identity `0x00020115`. The fixed programming
helper verified bitstream SHA-256
`54b4d2cebe0b09422a9713a534c3100b8d6371ef8aac022d00943417c1e76f83`
and matching ELF SHA-256
`3235e58340f1f7624831a47e2db0453ca757809d08c536f3f588c828c939bd96`
before programming F1 only. The JTAG chain re-enumerated F1 as target 1 and its
MicroBlaze as target 3.

## Preflight

The existing v270 publication was read before reconfiguration and remained a
healthy, preserved sequence/run ID 1 result. After programming, v271 reported
matching firmware/hardware identities, IDLE, and zero request, response, and
run IDs. Both regulator status words were clear. F1/F2 were cool and all
required reference/generated clocks were present. The managed monitor was
322.262 MHz after programming. Both x4 FireFly outputs were enabled; the known
raw byte-3/byte-5 `FF/FF` behavior persisted and was not used as a clean-link
predicate.

## Two clean external baselines

Two consecutive 10-second, four-lane external PRBS31 requests passed without a
reload or retry.

| Run | Sequence / run ID | RX cycles per profile | Errors | Lock losses | Cleanup | Trace |
| --- | --- | ---: | ---: | ---: | --- | --- |
| 1 | 1 / 1 | 3,222,603,289 | 0 on all lanes | 0 | one completed restart, cause 3 | 93 events, no overflow |
| 2 | 2 / 2 | 3,222,603,223 | 0 on all lanes | 0 | one completed restart, cause 3 | 104 events, no overflow |

For each run, lanes 12–15 were selected and locked at stop, hardware summary
and response code were `0x00040401`, the response sequence matched the unique
request, and the hardware run ID incremented exactly once. All four profiles
were valid, nonzero, mutually equal within each run, and free of the v270
zero-elapsed signature. The two requests exercised opposite toggle phases.
The matching operator validated each capture online; both copied JSON files
also passed independent local validation.

The RX monitor read approximately 322.01 MHz at each initial IDLE preflight and
322.261/322.262 MHz after the run/cleanup sequence. Final frequency monitoring
showed 200.000, 100.000, 325.001, primary 322.260–322.261, and managed 322.262
MHz. Final regulator status remained clear. F1/F2 temperatures were 25.0/24.5
C; both x4 modules were 38 C with outputs still enabled.

## Evidence and state

- `build/diagnostic_archive/v271-run1-clean.json`:
  `e8cd30a436ef0301d349ea1beb0691d6d80d2f34ead9325b4f5cbb2593fb4872`
- `build/diagnostic_archive/v271-run2-clean.json`:
  `777afca64d4ac3eb90cd025a242bc7ef5c096a5630829d83d26de11cc906e90f`
- `build/diagnostic_archive/v271-hardware-baselines.tar.gz`:
  `ed954ac2335fd58e470f7d6bb21d4c9892f7f41a4644780d9e79859bb65faf88`

Local and Apollo JSON hashes match. Apollo originals are
`/tmp/v270-diagnostic-20260912/v271-run{1,2}-clean.json`; the directory name is
historical, while the filenames, embedded arguments, and FW/HW identities are
v271-specific.

This baseline gate ended with F1 at request/response/run ID 2. A subsequent
[profile-repair hardware gate](v271-profile-hardware-gate.md) passed a targeted
lane-12 pulse, retained-IDLE comparison, and clean replacement run. F1 now
remains v271 healthy IDLE at request/response/run ID 4. Neither result makes
v271 a qualification candidate.
