# Fast diagnostic build; use the separate _clean entry for independent rebuild.
set milestone_build_suffix 269
set milestone_synth_check_script check_milestone269_trace.tcl
set milestone_build_label "2.5.19"
set milestone_create_script create_milestone269_incremental.tcl
source [file join [file dirname [file normalize [info script]]] build_milestone258_bitstream.tcl]
report_incremental_reuse -file [file join $report_dir incremental_reuse.rpt]
set f [open [file join $report_dir incremental_reference.txt] w]
puts $f "DCP=$diagnostic_reference_dcp\nSHA256=$diagnostic_reference_sha256"
puts $f "SETUP_SECONDS=$incremental_setup_seconds"
close $f
