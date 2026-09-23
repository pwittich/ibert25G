set milestone269_clean_build 1
set milestone_synth_check_script check_milestone269_trace.tcl
set milestone_build_suffix 269_clean
set milestone_build_label "2.5.19 clean"
set milestone_create_script create_milestone269_project.tcl
source [file join [file dirname [file normalize [info script]]] build_milestone258_bitstream.tcl]
