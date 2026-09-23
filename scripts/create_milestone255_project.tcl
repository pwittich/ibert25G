set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]

set isolated_smoke 1
if {![info exists project_name_override]} {
  set project_name_override gt_test_milestone255
}
if {![info exists firmware_elf_override]} {
  set firmware_elf_override [file join $repo_dir build firmware255 \
    gt_test_milestone255.elf]
}
# 0x00020105 is decimal 131333. This is a diagnostic target, not full M3 v13.
if {![info exists top_generics_override]} {
  set top_generics_override {
    HARDWARE_VERSION=131333
    STAGED_RX_ACQUISITION=1
    REQUIRE_ERROR_FREE_QUALIFICATION=0
    USE_EXACT_ERROR_COUNTS=0
    DIAGNOSTIC_RX_CLOCK_MONITOR=1
    EXTERNAL_RX_RECOVERY=1
  }
}
source [file join $script_dir create_milestone3_project.tcl]
