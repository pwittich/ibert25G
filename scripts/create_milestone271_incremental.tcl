source [file join [file dirname [file normalize [info script]]] milestone271_config.tcl]
set diagnostic_reference_project [file join $repo_dir build gt_test_milestone270 gt_test_milestone270.xpr]
set diagnostic_reference_dcp [file join $repo_dir build gt_test_milestone270 gt_test_milestone270.runs impl_1 gt_test_milestone25_top_routed.dcp]
set diagnostic_reference_sha256 866d9112343417449e2201a15d60d032f6ae395db85511b25fddf030c3e34400
source [file join $script_dir create_diagnostic_incremental.tcl]
remove_files [get_files */gt_test_milestone270_board.xdc]
add_files -fileset constrs_1 -norecurse [file join $repo_dir constraints gt_test_milestone271_board.xdc]
set_property STEPS.OPT_DESIGN.TCL.PRE [file join $script_dir apply_descriptor_cdc.tcl] [get_runs impl_1]
