set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
source [file join $script_dir create_firefly1_loopback_v3_project.tcl]
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} { error "FireFly-1 loopback v3 implementation failed" }
open_run impl_1
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] "TRUE"]} { error "Bitstream compression is not enabled" }
set report_dir [file join $repo_dir build gt_test_firefly1_loopback_v3_reports]
file mkdir $report_dir
report_timing_summary -file [file join $report_dir timing_summary.rpt]
report_route_status -file [file join $report_dir route_status.rpt]
report_drc -file [file join $report_dir drc.rpt]
set timing [report_timing_summary -return_string]
if {![string match {*All user specified timing constraints are met.*} $timing]} { error "Timing constraints are not met" }
set bit [file join [get_property DIRECTORY [get_runs impl_1]] [get_property TOP [get_filesets sources_1]].bit]
if {![file exists $bit]} { error "Missing bitstream: $bit" }
file copy -force $bit [file join $repo_dir build gt_test_firefly1_loopback_v3 gt_test_firefly1_loopback_v3.bit]
puts "PASS: FireFly-1 loopback v3 bitstream [file join $repo_dir build gt_test_firefly1_loopback_v3 gt_test_firefly1_loopback_v3.bit]"
