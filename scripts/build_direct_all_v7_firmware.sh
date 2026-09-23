#!/usr/bin/env bash
# Fixed symmetric all-direct-lane v7 firmware; no hardware access or overwrite.
set -euo pipefail
if (( $# != 0 )); then
  echo "Usage: bash scripts/build_direct_all_v7_firmware.sh" >&2
  exit 2
fi
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(cd "$script_dir/.." && pwd)
source /nfs/opt/Xilinx/Vivado/2023.2/settings64.sh
out_dir="$repo_dir/build/firmware_direct_all_v7"
if [[ -e "$out_dir" ]]; then
  echo "Refusing existing firmware_direct_all_v7; preserve and review before rebuilding." >&2
  exit 1
fi
mkdir "$out_dir"
flags=(-mcpu=v11.0 -mlittle-endian -mxl-soft-mul -mxl-barrel-shift -Os
  -ffreestanding -fno-builtin -nostdlib)
definitions=(-DGTTE_ENABLE_TX_SESSION=1 -DGTTE_FIRMWARE_VERSION=0x00020409u
  -DGTTE_MANAGED_MASK0=0u -DGTTE_MANAGED_MASK1=0xff000000u
  -DGTTE_MANAGED_MASK2=0xffffffffu -DGTTE_MANAGED_MASK3=0x0000ffffu)
echo "BUILD_FIRMWARE target=direct_all_v7 version=0x00020409 masks=0,ff000000,ffffffff,0000ffff TX_SESSION=1"
mb-gcc "${flags[@]}" -c -I"$repo_dir/firmware" \
  "$repo_dir/firmware/gt_test_milestone2_start.S" -o "$out_dir/start.o"
mb-gcc "${flags[@]}" -c -I"$repo_dir/firmware" "${definitions[@]}" \
  "$repo_dir/firmware/gt_test_milestone2.c" -o "$out_dir/supervisor.o"
elf="$out_dir/gt_test_direct_all_v7.elf"
mb-gcc -mcpu=v11.0 -mlittle-endian -mxl-soft-mul -mxl-barrel-shift -nostdlib \
  -Wl,-T,"$repo_dir/firmware/gt_test_milestone2.ld" -Wl,--no-relax \
  "$out_dir/start.o" "$out_dir/supervisor.o" -o "$elf"
mb-size "$elf"
sha256sum "$elf"
echo "FIRMWARE_COMPLETE target=direct_all_v7"
