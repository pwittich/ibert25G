source [file join [file dirname [file normalize [info script]]] milestone273_config.tcl]
set diagnostic_reference_project [file join $repo_dir build gt_test_milestone272 gt_test_milestone272.xpr]
set diagnostic_reference_dcp [file join $repo_dir build gt_test_milestone272 gt_test_milestone272.runs impl_1 gt_test_milestone25_top_routed.dcp]
set diagnostic_reference_sha256 237986f4032c2753fa2d1a104b62a64e2145101f3fe37d4848252d004b0b31e9
source [file join $script_dir create_diagnostic_incremental.tcl]
remove_files [get_files */gt_test_milestone272_board.xdc]
add_files -fileset constrs_1 -norecurse [file join $repo_dir constraints gt_test_milestone273_board.xdc]
set_property STEPS.OPT_DESIGN.TCL.PRE [file join $script_dir apply_descriptor_cdc.tcl] [get_runs impl_1]
