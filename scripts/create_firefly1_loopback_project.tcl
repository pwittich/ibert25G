set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set isolated_smoke 1
set firefly1_functional 1
set project_name_override gt_test_firefly1_loopback_v1
set firmware_elf_override [file join $repo_dir build firmware_firefly1_loopback_v1 gt_test_firefly1_loopback_v1.elf]
set top_generics_override {HARDWARE_VERSION=131840 FIREFLY1_FUNCTIONAL=1 STAGED_RX_ACQUISITION=1 REQUIRE_ERROR_FREE_QUALIFICATION=0}
source [file join $script_dir create_milestone3_project.tcl]
