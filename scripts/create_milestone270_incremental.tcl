source [file join [file dirname [file normalize [info script]]] milestone270_config.tcl]
set diagnostic_reference_project [file join $repo_dir build gt_test_milestone269 gt_test_milestone269.xpr]
set diagnostic_reference_dcp [file join $repo_dir build gt_test_milestone269 gt_test_milestone269.runs impl_1 gt_test_milestone25_top_routed.dcp]
set diagnostic_reference_sha256 68dfd31508e696cb30f7cbe06dea1eabe6f67b7d598c6454be0a315b66f4738f
source [file join $script_dir create_diagnostic_incremental.tcl]
remove_files [get_files */gt_test_milestone25_board.xdc]
add_files -fileset constrs_1 -norecurse [file join $repo_dir constraints gt_test_milestone270_board.xdc]
set_property STEPS.OPT_DESIGN.TCL.PRE [file join $script_dir apply_descriptor_cdc.tcl] [get_runs impl_1]
