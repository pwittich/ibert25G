set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]

set project_name_override gt_test_milestone256
set firmware_elf_override [file join $repo_dir build firmware256 \
  gt_test_milestone256.elf]
# 0x00020106 is decimal 131334. This is a diagnostic target, not full M3 v13.
set top_generics_override {
  HARDWARE_VERSION=131334
  STAGED_RX_ACQUISITION=1
  REQUIRE_ERROR_FREE_QUALIFICATION=0
  USE_EXACT_ERROR_COUNTS=0
  DIAGNOSTIC_RX_CLOCK_MONITOR=1
  EXTERNAL_RX_RECOVERY=1
  POST_CAPTURE_RX_REQUAL=1
}
source [file join $script_dir create_milestone255_project.tcl]
