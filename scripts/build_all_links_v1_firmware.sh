#!/usr/bin/env bash
# Source milestone only: build the matching all-112-lane supervisor ELF.
set -euo pipefail
if (( $# != 0 )); then
  echo "Usage: bash scripts/build_all_links_v1_firmware.sh" >&2
  exit 2
fi
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(cd "$script_dir/.." && pwd)
source /nfs/opt/Xilinx/Vivado/2023.2/settings64.sh
out_dir="$repo_dir/build/firmware_all_links_v1"
if [[ -e "$out_dir" ]]; then
  echo "Refusing existing firmware_all_links_v1." >&2
  exit 1
fi
mkdir "$out_dir"
flags=(-mcpu=v11.0 -mlittle-endian -mxl-soft-mul -mxl-barrel-shift -Os
  -ffreestanding -fno-builtin -nostdlib)
definitions=(-DGTTE_ENABLE_TX_SESSION=1 -DGTTE_FIRMWARE_VERSION=0x00020500u
  -DGTTE_MANAGED_MASK0=0xffffffffu -DGTTE_MANAGED_MASK1=0xffffffffu
  -DGTTE_MANAGED_MASK2=0xffffffffu -DGTTE_MANAGED_MASK3=0x0000ffffu)
echo "BUILD_FIRMWARE target=all_links_v1 version=0x00020500 masks=ffffffff,ffffffff,ffffffff,0000ffff TX_SESSION=1"
mb-gcc "${flags[@]}" -c -I"$repo_dir/firmware" \
  "$repo_dir/firmware/gt_test_milestone2_start.S" -o "$out_dir/start.o"
mb-gcc "${flags[@]}" -c -I"$repo_dir/firmware" "${definitions[@]}" \
  "$repo_dir/firmware/gt_test_milestone2.c" -o "$out_dir/supervisor.o"
elf="$out_dir/gt_test_all_links_v1.elf"
mb-gcc -mcpu=v11.0 -mlittle-endian -mxl-soft-mul -mxl-barrel-shift -nostdlib \
  -Wl,-T,"$repo_dir/firmware/gt_test_milestone2.ld" -Wl,--no-relax \
  "$out_dir/start.o" "$out_dir/supervisor.o" -o "$elf"
mb-size "$elf"
sha256sum "$elf"
echo "FIRMWARE_COMPLETE target=all_links_v1"
