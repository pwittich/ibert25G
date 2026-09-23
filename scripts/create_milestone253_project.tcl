set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]

set isolated_smoke 1
set project_name_override gt_test_milestone253
set firmware_elf_override [file join $repo_dir build firmware253 \
  gt_test_milestone253.elf]
# 0x00020103 is decimal 131331.
set top_generics_override {
  HARDWARE_VERSION=131331
  STAGED_RX_ACQUISITION=1
  REQUIRE_ERROR_FREE_QUALIFICATION=0
}
source [file join $script_dir create_milestone3_project.tcl]
