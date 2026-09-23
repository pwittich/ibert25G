#!/usr/bin/env bash
set -euo pipefail
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(cd "$script_dir/.." && pwd)
source /nfs/opt/Xilinx/Vivado/2023.2/settings64.sh
out_dir="$repo_dir/build/firmware_firefly1_loopback_v5"
mkdir -p "$out_dir"
flags=(-mcpu=v11.0 -mlittle-endian -mxl-soft-mul -mxl-barrel-shift -Os -ffreestanding -fno-builtin -nostdlib)
mb-gcc "${flags[@]}" -c -I"$repo_dir/firmware" "$repo_dir/firmware/gt_test_milestone2_start.S" -o "$out_dir/start.o"
mb-gcc "${flags[@]}" -c -I"$repo_dir/firmware" -DGTTE_ENABLE_TX_SESSION=1 -DGTTE_FIRMWARE_VERSION=0x00020304u -DGTTE_MANAGED_MASK0=0x00000fffu -DGTTE_MANAGED_MASK1=0u -DGTTE_MANAGED_MASK2=0u -DGTTE_MANAGED_MASK3=0u "$repo_dir/firmware/gt_test_milestone2.c" -o "$out_dir/supervisor.o"
mb-gcc -mcpu=v11.0 -mlittle-endian -mxl-soft-mul -mxl-barrel-shift -nostdlib -Wl,-T,"$repo_dir/firmware/gt_test_milestone2.ld" -Wl,--no-relax "$out_dir/start.o" "$out_dir/supervisor.o" -o "$out_dir/gt_test_firefly1_loopback_v5.elf"
