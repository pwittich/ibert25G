set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]

set isolated_smoke 1
set project_name_override gt_test_milestone251
set firmware_elf_override [file join $repo_dir build firmware251 \
  gt_test_milestone251.elf]
# 0x00020101 is decimal 131329. Decimal avoids Tcl/Verilog quote escaping in
# the fileset generic string.
set top_generics_override {HARDWARE_VERSION=131329 STAGED_RX_ACQUISITION=1}
source [file join $script_dir create_milestone3_project.tcl]
