set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set project_name_override gt_test_firefly1_loopback_v5
set firmware_elf_override [file join $repo_dir build firmware_firefly1_loopback_v5 gt_test_firefly1_loopback_v5.elf]
set top_generics_override {HARDWARE_VERSION=131844 FIREFLY1_FUNCTIONAL=1 STAGED_RX_ACQUISITION=1 REQUIRE_ERROR_FREE_QUALIFICATION=0 ENABLE_TX_SESSION=1}
set diagnostic_reference_project [file join $repo_dir build gt_test_firefly1_loopback_v4 gt_test_firefly1_loopback_v4.xpr]
set diagnostic_reference_dcp [file join $repo_dir build gt_test_firefly1_loopback_v4 gt_test_firefly1_loopback_v4_routed.dcp]
set diagnostic_reference_sha256 c029bd5d51085decd65801b62211db2e3adea9671a098995817246f2a626a835
source [file join $script_dir create_firefly1_checkpoint_clone.tcl]
set_property STEPS.OPT_DESIGN.TCL.PRE [file join $script_dir apply_firefly1_descriptor_cdc.tcl] [get_runs impl_1]
