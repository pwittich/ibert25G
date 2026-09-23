set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]

set isolated_smoke 1
set project_name_override gt_test_milestone252
set firmware_elf_override [file join $repo_dir build firmware252 \
  gt_test_milestone252.elf]
# 0x00020102 is decimal 131330.
set top_generics_override {
  HARDWARE_VERSION=131330
  STAGED_RX_ACQUISITION=1
  REQUIRE_ERROR_FREE_QUALIFICATION=0
}
source [file join $script_dir create_milestone3_project.tcl]
