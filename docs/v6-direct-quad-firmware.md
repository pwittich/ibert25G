# V6 direct-quad firmware build

Both MicroBlaze firmware artifacts built successfully with the Cornell
Vivado 2023.2 toolchain using the fixed versioned entry point:

```sh
bash scripts/build_direct_quad_v6_firmware.sh
```

The helper builds both sites, accepts no arguments, and refuses existing
endpoint output directories. Do not rerun it to overwrite these products.
It uses the same compiler options, startup assembly, linker script and
supervisor source as v5. No FPGA programming or MCU access occurs.

| Site | FW/HW identity | Managed mask words 0–3 | ELF |
|---|---|---|---|
| F1 q222 | `0x00020400` | `0, F0000000, 0, 0` | `build/firmware_direct_quad_v6_f1/gt_test_direct_quad_v6_f1.elf` |
| F2 q233 | `0x00020403` | `0, 0, 0, 00000F00` | `build/firmware_direct_quad_v6_f2/gt_test_direct_quad_v6_f2.elf` |

F1 covers global lanes60–63; F2 covers104–107. Both enable independent
bounded TX sessions. Identities must match the separately built FPGA tops;
this firmware build alone is not FPGA audit or hardware acceptance.

ELF SHA-256:

- F1: `262bbdf17844694d124e345b0f71b599dd57800dbf93ecc8c8ea35bb25611568`
- F2: `ea7d79aca4e5edde9f0cf3ccd45644e9ceb722a71706ba077af35d432cf7a52a`

The table records the final F2 repair.  Historical `0x00020401` and partial
`0x00020402` firmware/products are preserved with their failed hardware
evidence; they must not be substituted for the final audited bitstream.  See
`docs/v6-direct-quad-qualification.md`.

F1 text/data/bss sizes are884/0/8 bytes; F2 sizes888/0/8 bytes. Both are
32-bit little-endian MicroBlaze executables within the unchanged32-KiB memory.

## Necessary shared-source repair

The v5 TX-session branch hardcoded mask `FFF,0,0,0`. Reusing that check
unchanged would reject every v6 start/stop request. The check now compares
all four mailbox mask words to the existing `GTTE_MANAGED_MASK0..3` macros.
V5's macro values equal its old literals, preserving its behavior. Historical
targets without `GTTE_ENABLE_TX_SESSION` still exclude this entire branch.
No lease, state, sequence, response, measurement-mask or mailbox ABI changed.

`python3 -m unittest discover -s scripts -p test_direct_quad_v6_firmware.py`
passes all three endpoint-profile tests. Tests compile and execute the actual
C session branch with mocked register access, exercising start/stop, every
single-bit mask mutation, invalid durations, nonzero timeout, duplicate start,
busy and retained-fault states. V5's old and new branches generate identical
host assembly. This is not a MicroBlaze runtime simulation; the actual
MicroBlaze compilation and linkage pass separately above.

`bash -n scripts/build_direct_quad_v6_firmware.sh` and whitespace checks pass.
Existing v5 products and hardware state are unchanged.
