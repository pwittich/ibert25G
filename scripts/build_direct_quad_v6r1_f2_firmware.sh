#!/usr/bin/env bash
# Fixed F2 repair firmware; the failed 0x00020402 product must be archived first.
set -euo pipefail
if (( $# != 0 )); then
  echo "Usage: bash scripts/build_direct_quad_v6r1_f2_firmware.sh" >&2
  exit 2
fi
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(cd "$script_dir/.." && pwd)
out_dir="$repo_dir/build/firmware_direct_quad_v6_f2"
archive="$repo_dir/build/diagnostic_archive/direct-v6-f2-00020402-pma-lane105-failure-20260917T035300Z/firmware_direct_quad_v6_f2/gt_test_direct_quad_v6_f2.elf"
if [[ ! -f "$archive" ]]; then
  echo "Missing preserved failed F2 ELF: $archive" >&2
  exit 1
fi
if [[ -e "$out_dir" ]]; then
  echo "Refusing existing $out_dir; move the preserved directory before rebuilding." >&2
  exit 1
fi
source /nfs/opt/Xilinx/Vivado/2023.2/settings64.sh
mkdir "$out_dir"
flags=(-mcpu=v11.0 -mlittle-endian -mxl-soft-mul -mxl-barrel-shift -Os -ffreestanding -fno-builtin -nostdlib)
definitions=(-DGTTE_ENABLE_TX_SESSION=1 -DGTTE_FIRMWARE_VERSION=0x00020403u
  -DGTTE_MANAGED_MASK0=0u -DGTTE_MANAGED_MASK1=0u
  -DGTTE_MANAGED_MASK2=0u -DGTTE_MANAGED_MASK3=0x00000f00u)
mb-gcc "${flags[@]}" -c -I"$repo_dir/firmware" "$repo_dir/firmware/gt_test_milestone2_start.S" -o "$out_dir/start.o"
mb-gcc "${flags[@]}" -c -I"$repo_dir/firmware" "${definitions[@]}" "$repo_dir/firmware/gt_test_milestone2.c" -o "$out_dir/supervisor.o"
elf="$out_dir/gt_test_direct_quad_v6_f2.elf"
mb-gcc -mcpu=v11.0 -mlittle-endian -mxl-soft-mul -mxl-barrel-shift -nostdlib \
  -Wl,-T,"$repo_dir/firmware/gt_test_milestone2.ld" -Wl,--no-relax \
  "$out_dir/start.o" "$out_dir/supervisor.o" -o "$elf"
mb-size "$elf"
sha256sum "$elf"
echo "FIRMWARE_COMPLETE site=f2 version=0x00020403u"
