set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]

source [file join $script_dir create_milestone2_project.tcl]
export_ip_user_files -of_objects [get_ips] -no_script -sync -force -quiet

launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
  error "Milestone-2 synthesis failed"
}

set report_dir [file join $repo_dir build gt_test_milestone2_reports]
file mkdir $report_dir
report_ip_status -file [file join $report_dir ip_status.rpt]
open_run synth_1
report_utilization -file [file join $report_dir utilization_synth.rpt]
report_cdc -details -file [file join $report_dir cdc_synth.rpt]
report_methodology -file [file join $report_dir methodology_synth.rpt]
close_design

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
  error "Milestone-2 implementation failed"
}

open_run impl_1
set bitstream_compress [get_property BITSTREAM.GENERAL.COMPRESS [current_design]]
if {![string equal -nocase $bitstream_compress "TRUE"]} {
  error "Milestone-2 bitstream compression is not enabled"
}
report_timing_summary -file [file join $report_dir timing_summary_routed.rpt]
report_route_status -file [file join $report_dir route_status.rpt]
report_drc -file [file join $report_dir drc_routed.rpt]
report_cdc -details -file [file join $report_dir cdc_routed.rpt]
report_clock_utilization -file [file join $report_dir clock_utilization.rpt]
report_bus_skew -file [file join $report_dir bus_skew.rpt]

set timing_text [report_timing_summary -return_string]
if {[regexp {Timing constraints are not met} $timing_text]} {
  error "Milestone-2 implementation completed, but timing failed"
}

set impl_dir [get_property DIRECTORY [get_runs impl_1]]
set bitstream [file join $impl_dir gt_test_milestone2_top.bit]
if {![file exists $bitstream]} {
  error "Milestone-2 bitstream was not generated: $bitstream"
}

puts "Milestone-2 timing constraints met"
puts "Milestone-2 bitstream compression: $bitstream_compress"
puts "Milestone-2 bitstream: $bitstream"
puts "Milestone-2 reports: $report_dir"
