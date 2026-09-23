set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set name gt_test_direct_quad_v6_f2
set project_dir [file join $repo_dir build $name]
set reference [file join $repo_dir build diagnostic_archive direct-v6-f2-00020402-no-rx-override-20260917T033400Z gt_test_direct_quad_v6_f2_routed.dcp]
if {![file isfile $reference]} {error "Missing preserved rejected route: $reference"}
open_project [file join $project_dir ${name}.xpr]
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Completed synthesis is required"}
reset_run impl_1
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs impl_1]
set_property INCREMENTAL_CHECKPOINT $reference [get_runs impl_1]
set_property STEPS.OPT_DESIGN.TCL.PRE [file join $script_dir apply_direct_quad_v6_descriptor_cdc.tcl] [get_runs impl_1]
puts "PASS: F2 implementation reset; q233 override hook and rejected route reference installed"
