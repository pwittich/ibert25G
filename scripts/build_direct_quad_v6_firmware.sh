#!/usr/bin/env bash
# Fixed site-specific v6 firmware; no hardware access or overwrite of products.
set -euo pipefail
if (( $# != 0 )); then
  echo "Usage: bash scripts/build_direct_quad_v6_firmware.sh" >&2
  exit 2
fi
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(cd "$script_dir/.." && pwd)
source /nfs/opt/Xilinx/Vivado/2023.2/settings64.sh
for site in f1 f2; do
  if [[ -e "$repo_dir/build/firmware_direct_quad_v6_$site" ]]; then
    echo "Refusing existing firmware_direct_quad_v6_$site; preserve and review before rebuilding." >&2
    exit 1
  fi
done
flags=(-mcpu=v11.0 -mlittle-endian -mxl-soft-mul -mxl-barrel-shift -Os -ffreestanding -fno-builtin -nostdlib)
for site in f1 f2; do
  out_dir="$repo_dir/build/firmware_direct_quad_v6_$site"
  mkdir "$out_dir"
  if [[ "$site" == f1 ]]; then
    version=0x00020400u
    mask1=0xf0000000u
    mask3=0u
  else
    version=0x00020401u
    mask1=0u
    mask3=0x00000f00u
  fi
  definitions=(-DGTTE_ENABLE_TX_SESSION=1 "-DGTTE_FIRMWARE_VERSION=$version"
    -DGTTE_MANAGED_MASK0=0u "-DGTTE_MANAGED_MASK1=$mask1"
    -DGTTE_MANAGED_MASK2=0u "-DGTTE_MANAGED_MASK3=$mask3")
  echo "BUILD_FIRMWARE site=$site version=$version masks=0,$mask1,0,$mask3 TX_SESSION=1"
  mb-gcc "${flags[@]}" -c -I"$repo_dir/firmware" "$repo_dir/firmware/gt_test_milestone2_start.S" -o "$out_dir/start.o"
  mb-gcc "${flags[@]}" -c -I"$repo_dir/firmware" "${definitions[@]}" "$repo_dir/firmware/gt_test_milestone2.c" -o "$out_dir/supervisor.o"
  elf="$out_dir/gt_test_direct_quad_v6_$site.elf"
  mb-gcc -mcpu=v11.0 -mlittle-endian -mxl-soft-mul -mxl-barrel-shift -nostdlib \
    -Wl,-T,"$repo_dir/firmware/gt_test_milestone2.ld" -Wl,--no-relax \
    "$out_dir/start.o" "$out_dir/supervisor.o" -o "$elf"
  mb-size "$elf"
  sha256sum "$elf"
  echo "FIRMWARE_COMPLETE site=$site"
done
