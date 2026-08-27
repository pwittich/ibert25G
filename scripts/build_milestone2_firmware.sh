#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(cd "$script_dir/.." && pwd)
out_dir="$repo_dir/build/firmware"
mkdir -p "$out_dir"

mb-gcc -mcpu=v11.0 -mlittle-endian \
  -mxl-soft-mul -mxl-barrel-shift \
  -Os -ffreestanding -fno-builtin -nostdlib -c \
  -I"$repo_dir/firmware" \
  "$repo_dir/firmware/gt_test_milestone2_start.S" \
  -o "$out_dir/gt_test_milestone2_start.o"

mb-gcc -mcpu=v11.0 -mlittle-endian \
  -mxl-soft-mul -mxl-barrel-shift \
  -Os -ffreestanding -fno-builtin -nostdlib -c \
  -I"$repo_dir/firmware" \
  "$repo_dir/firmware/gt_test_milestone2.c" \
  -o "$out_dir/gt_test_milestone2_supervisor.o"

# Explicit object names keep the ELF symbol table reproducible. Invoking the
# compiler and linker in one step otherwise records a random temporary object
# name even though the loadable firmware bytes are unchanged.
mb-gcc -mcpu=v11.0 -mlittle-endian \
  -mxl-soft-mul -mxl-barrel-shift -nostdlib \
  -Wl,-T,"$repo_dir/firmware/gt_test_milestone2.ld" \
  -Wl,--no-relax \
  -Wl,-Map,"$out_dir/gt_test_milestone2.map" \
  "$out_dir/gt_test_milestone2_start.o" \
  "$out_dir/gt_test_milestone2_supervisor.o" \
  -o "$out_dir/gt_test_milestone2.elf"

mb-size "$out_dir/gt_test_milestone2.elf"

# Vivado's MicroBlaze automation configures this subsystem little-endian.  A
# big-endian ELF can still be accepted by the memory updater, but the processor
# will fetch byte-swapped instructions and never reach the firmware-alive AXI
# write.  Fail the build before bitstream generation if the ABI drifts.
if ! mb-readelf -h "$out_dir/gt_test_milestone2.elf" | \
    grep -q "2's complement, little endian"; then
  echo "error: MicroBlaze firmware is not little-endian" >&2
  exit 1
fi

if ! mb-objdump -s -j .vectors "$out_dir/gt_test_milestone2.elf" | \
    grep -Eq '^[[:space:]]*0010[[:space:]]+000000b0[[:space:]]+[[:xdigit:]]{4}08b8'; then
  echo "error: linked MicroBlaze interrupt branch is not at vector 0x10" >&2
  exit 1
fi
