# Resume the immutable full-v13 project after a synthesis-checker-only stop.
# This script does not recreate/reset synthesis or alter firmware inputs.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set project_dir [file join $repo_dir build gt_test_milestone3_v13]
set report_dir [file join $repo_dir build gt_test_milestone3_v13_reports]
set project_file [file join $project_dir gt_test_milestone3_v13.xpr]
if {![file isfile $project_file]} { error "Missing full-v13 project: $project_file" }
open_project $project_file
if {[get_property PROGRESS [get_runs synth_1]] ne "100%" ||
    [get_property PROGRESS [get_runs impl_1]] ne "0%"} {
  error "Resume requires completed synthesis and unstarted implementation"
}

file mkdir $report_dir
report_ip_status -file [file join $report_dir ip_status.rpt]
open_run synth_1
source [file join $script_dir check_milestone3_v13_synth.tcl]
set managed_channels [get_cells -hier -filter {
  REF_NAME == GTYE4_CHANNEL && NAME =~ *u_managed_quad124/*
}]
if {[llength $managed_channels] != 4} {
  error "Expected exactly four synthesized managed GTYE4_CHANNEL cells"
}
set golden_rx_properties [list \
  ADAPT_CFG1 16'hF81C RXCDR_CFG3 16'h0012 RXDFE_GC_CFG2 16'hFFF0 \
  RX_DEGEN_CTRL 3'b100 RX_DFE_AGC_CFG1 2 \
  RX_SUM_DEGEN_AVTT_OVERITE 0 RX_SUM_VCMTUNE 4'b0011]
foreach channel $managed_channels {
  foreach {property expected} $golden_rx_properties {
    set actual [get_property $property $channel]
    if {$actual ne $expected} {
      error "$channel $property=$actual; golden quad-124 value is $expected"
    }
  }
}
report_utilization -file [file join $report_dir utilization_synth.rpt]
report_cdc -details -file [file join $report_dir cdc_synth.rpt]
report_methodology -file [file join $report_dir methodology_synth.rpt]
close_design

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
  error "Full Milestone 3 v13 implementation failed"
}
open_run impl_1
if {![string equal -nocase \
      [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] "TRUE"]} {
  error "Full Milestone 3 v13 bitstream compression is not enabled"
}
report_timing_summary -file [file join $report_dir timing_summary_routed.rpt]
report_route_status -file [file join $report_dir route_status.rpt]
report_drc -file [file join $report_dir drc_routed.rpt]
report_cdc -details -file [file join $report_dir cdc_routed.rpt]
report_clock_utilization -file [file join $report_dir clock_utilization.rpt]
report_bus_skew -file [file join $report_dir bus_skew.rpt]
if {[regexp {Timing constraints are not met} \
    [report_timing_summary -return_string]]} {
  error "Full Milestone 3 v13 implementation completed, but timing failed"
}
set run_dir [get_property DIRECTORY [get_runs impl_1]]
set bitstream [file join $run_dir gt_test_milestone3_top.bit]
if {![file isfile $bitstream]} { error "Bitstream was not generated: $bitstream" }
set named_bitstream [file join $run_dir gt_test_milestone3_v13.bit]
file copy -force $bitstream $named_bitstream
puts "Full Milestone 3 v13 resumed build passed"
puts "Full Milestone 3 v13 bitstream: $named_bitstream"
puts "Full Milestone 3 v13 reports: $report_dir"
