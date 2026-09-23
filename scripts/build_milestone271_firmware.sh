#!/usr/bin/env bash
set -euo pipefail
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(cd "$script_dir/.." && pwd)
out_dir="$repo_dir/build/firmware271"
if [[ -e "$out_dir" ]]; then
  echo "error: refusing to overwrite existing firmware271 evidence" >&2
  exit 1
fi
mkdir -p "$out_dir"
common_flags=(-mcpu=v11.0 -mlittle-endian -mxl-soft-mul -mxl-barrel-shift
  -Os -ffreestanding -fno-builtin -nostdlib)
mb-gcc "${common_flags[@]}" -c -I"$repo_dir/firmware" \
  "$repo_dir/firmware/gt_test_milestone2_start.S" \
  -o "$out_dir/gt_test_milestone271_start.o"
mb-gcc "${common_flags[@]}" -c -I"$repo_dir/firmware" \
  -DGTTE_FIRMWARE_VERSION=0x00020115u \
  -DGTTE_MANAGED_MASK0=0x0000f000u -DGTTE_MANAGED_MASK1=0u \
  -DGTTE_MANAGED_MASK2=0u -DGTTE_MANAGED_MASK3=0u \
  "$repo_dir/firmware/gt_test_milestone2.c" \
  -o "$out_dir/gt_test_milestone271_supervisor.o"
mb-gcc -mcpu=v11.0 -mlittle-endian -mxl-soft-mul -mxl-barrel-shift \
  -nostdlib -Wl,-T,"$repo_dir/firmware/gt_test_milestone2.ld" \
  -Wl,--no-relax -Wl,-Map,"$out_dir/gt_test_milestone271.map" \
  "$out_dir/gt_test_milestone271_start.o" \
  "$out_dir/gt_test_milestone271_supervisor.o" \
  -o "$out_dir/gt_test_milestone271.elf"
mb-size "$out_dir/gt_test_milestone271.elf"
if ! mb-readelf -h "$out_dir/gt_test_milestone271.elf" | \
    grep -q "2's complement, little endian"; then
  echo "error: MicroBlaze firmware is not little-endian" >&2
  exit 1
fi
if ! mb-objdump -s -j .vectors "$out_dir/gt_test_milestone271.elf" | \
    grep -Eq '^[[:space:]]*0010[[:space:]]+000000b0[[:space:]]+[[:xdigit:]]{4}08b8'; then
  echo "error: linked MicroBlaze interrupt branch is not at vector 0x10" >&2
  exit 1
fi
