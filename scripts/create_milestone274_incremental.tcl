source [file join [file dirname [file normalize [info script]]] milestone274_config.tcl]
set diagnostic_reference_project [file join $repo_dir build gt_test_milestone273 gt_test_milestone273.xpr]
set diagnostic_reference_dcp [file join $repo_dir build gt_test_milestone273 gt_test_milestone273.runs impl_1 gt_test_milestone25_top_routed.dcp]
set diagnostic_reference_sha256 b31c17fbb6825aa650ffaa8f2e1f5775b1e5dae429fcb50a6f0f6be64a56e6ae
source [file join $script_dir create_diagnostic_incremental.tcl]
remove_files [get_files */gt_test_milestone273_board.xdc]
add_files -fileset constrs_1 -norecurse [file join $repo_dir constraints gt_test_milestone274_board.xdc]
set_property STEPS.OPT_DESIGN.TCL.PRE [file join $script_dir apply_descriptor_cdc.tcl] [get_runs impl_1]
