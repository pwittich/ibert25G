set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set isolated_smoke 1
set firefly1_functional 1
set project_name_override gt_test_firefly1_loopback_v2
set firmware_elf_override [file join $repo_dir build firmware_firefly1_loopback_v2 gt_test_firefly1_loopback_v2.elf]
set top_name_override gt_test_firefly1_loopback_v2_top
set board_constraint_override [file join $repo_dir constraints board_pins.xdc]
# 0x00020301 distinguishes the first image whose synthesis top forwards the
# functional FireFly-1 parameter from the invalid v1 artifact.
set top_generics_override {HARDWARE_VERSION=131841 FIREFLY1_FUNCTIONAL=1 STAGED_RX_ACQUISITION=1 REQUIRE_ERROR_FREE_QUALIFICATION=0}
source [file join $script_dir create_milestone3_project.tcl]
