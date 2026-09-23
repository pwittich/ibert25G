set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]

set isolated_smoke 1
set project_name_override gt_test_milestone254
set firmware_elf_override [file join $repo_dir build firmware254 \
  gt_test_milestone254.elf]
# 0x00020104 is decimal 131332. This is a diagnostic target, not full M3 v13.
set top_generics_override {
  HARDWARE_VERSION=131332
  STAGED_RX_ACQUISITION=1
  REQUIRE_ERROR_FREE_QUALIFICATION=0
  USE_EXACT_ERROR_COUNTS=0
  DIAGNOSTIC_RX_CLOCK_MONITOR=1
}
source [file join $script_dir create_milestone3_project.tcl]
