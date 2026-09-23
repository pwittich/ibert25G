source [file join [file dirname [file normalize [info script]]] milestone272_config.tcl]
set diagnostic_reference_project [file join $repo_dir build gt_test_milestone271 gt_test_milestone271.xpr]
set diagnostic_reference_dcp [file join $repo_dir build gt_test_milestone271 gt_test_milestone271.runs impl_1 gt_test_milestone25_top_routed.dcp]
set diagnostic_reference_sha256 b0e540051b786051ec898211ac3092ad2eac125af124c4e11b46a52b068361d4
source [file join $script_dir create_diagnostic_incremental.tcl]
# This module is newer than the immutable v271 reference project, so it cannot
# be discovered by the clone helper's reference-file inventory.
if {![llength [get_files -all -quiet */gt_runtime_integrity_monitor.sv]]} {
  add_files -norecurse [file join $repo_dir src gt_runtime_integrity_monitor.sv]
}
remove_files [get_files */gt_test_milestone271_board.xdc]
add_files -fileset constrs_1 -norecurse [file join $repo_dir constraints gt_test_milestone272_board.xdc]
set_property STEPS.OPT_DESIGN.TCL.PRE [file join $script_dir apply_descriptor_cdc.tcl] [get_runs impl_1]
