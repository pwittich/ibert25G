set milestone_build_suffix 275
set milestone_build_label "2.5.25"
set milestone_create_script create_milestone275_incremental.tcl
set milestone_synth_check_script check_milestone275_synth.tcl
source [file join [file dirname [file normalize [info script]]] build_milestone258_bitstream.tcl]
report_incremental_reuse -file [file join $report_dir incremental_reuse.rpt]
source [file join $script_dir check_descriptor_routed.tcl]
source [file join $script_dir check_profile_control_routed.tcl]
source [file join $script_dir check_runtime_integrity_routed.tcl]
source [file join $script_dir check_milestone275_policy_routed.tcl]
