set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set milestone3_create_script [file join $script_dir create_milestone3_v13_project.tcl]
set milestone3_report_dir [file join $repo_dir build gt_test_milestone3_v13_reports]
set milestone3_version_label v13
set milestone3_synth_check [file join $script_dir check_milestone3_v13_synth.tcl]
source [file join $script_dir build_milestone3_bitstream.tcl]
