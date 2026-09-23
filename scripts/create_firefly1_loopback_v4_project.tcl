set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set isolated_smoke 1
set firefly1_functional 1
set project_name_override gt_test_firefly1_loopback_v4
set firmware_elf_override [file join $repo_dir build firmware_firefly1_loopback_v4 gt_test_firefly1_loopback_v4.elf]
set top_name_override gt_test_firefly1_loopback_v2_top
set board_constraint_override [file join $repo_dir constraints board_pins.xdc]
set top_generics_override {HARDWARE_VERSION=131843 FIREFLY1_FUNCTIONAL=1 STAGED_RX_ACQUISITION=1 REQUIRE_ERROR_FREE_QUALIFICATION=0}
source [file join $script_dir create_milestone3_project.tcl]
# Incremental reuse omitted new cleanup acknowledgement logic in this target;
# require fresh synthesis and the structural audit for controller repairs.
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]
set_property INCREMENTAL_CHECKPOINT {} [get_runs synth_1]
add_files -fileset constrs_1 -norecurse [file join $repo_dir constraints firefly1_reference_clocks.xdc]
set_property STEPS.OPT_DESIGN.TCL.PRE [file join $script_dir apply_firefly1_descriptor_cdc.tcl] [get_runs impl_1]
