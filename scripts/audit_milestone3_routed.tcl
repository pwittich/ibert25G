set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set routed_checkpoint [file join $repo_dir build gt_test_milestone3 \
  gt_test_milestone3.runs impl_1 gt_test_milestone3_top_routed.dcp]
set report_dir [file join $repo_dir build gt_test_milestone3_reports]

if {![file exists $routed_checkpoint]} {
  error "Milestone-3 routed checkpoint is missing: $routed_checkpoint"
}
file mkdir $report_dir
open_checkpoint $routed_checkpoint

if {[get_property PART [current_design]] ne "xcvu13p-flga2577-2-e"} {
  error "Milestone-3 routed checkpoint targets the wrong part"
}
if {![string equal -nocase \
      [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] "TRUE"]} {
  error "Milestone-3 bitstream compression is not enabled"
}

set channels [get_cells -hier -filter {REF_NAME == GTYE4_CHANNEL}]
set commons [get_cells -hier -filter {REF_NAME == GTYE4_COMMON}]
set managed_channels [get_cells -hier -filter {
  REF_NAME == GTYE4_CHANNEL && NAME =~ *u_managed_quad124/*
}]
set left_channels [get_cells -hier -filter {
  REF_NAME == GTYE4_CHANNEL && NAME =~ *u_ibert_left/*
}]
set right_channels [get_cells -hier -filter {
  REF_NAME == GTYE4_CHANNEL && NAME =~ *u_ibert_right/*
}]
if {[llength $channels] != 112 || [llength $commons] != 28 ||
    [llength $managed_channels] != 4 || [llength $left_channels] != 52 ||
    [llength $right_channels] != 56} {
  error "Unexpected GT counts: channels=[llength $channels], commons=[llength $commons], managed=[llength $managed_channels], left=[llength $left_channels], right=[llength $right_channels]"
}

set managed_sites {}
foreach channel $managed_channels {
  lappend managed_sites [get_property SITE $channel]
}
set managed_sites [lsort $managed_sites]
set expected_sites [list GTYE4_CHANNEL_X0Y16 GTYE4_CHANNEL_X0Y17 \
  GTYE4_CHANNEL_X0Y18 GTYE4_CHANNEL_X0Y19]
if {$managed_sites ne $expected_sites} {
  error "Managed quad occupies $managed_sites, expected $expected_sites"
}

set golden_rx_properties [list \
  ADAPT_CFG1 16'hF81C \
  RXCDR_CFG3 16'h0012 \
  RXDFE_GC_CFG2 16'hFFF0 \
  RX_DEGEN_CTRL 3'b100 \
  RX_DFE_AGC_CFG1 2 \
  RX_SUM_DEGEN_AVTT_OVERITE 0 \
  RX_SUM_VCMTUNE 4'b0011]
foreach channel $managed_channels {
  foreach {property expected} $golden_rx_properties {
    set actual [get_property $property $channel]
    if {$actual ne $expected} {
      error "$channel $property=$actual; golden quad-124 value is $expected"
    }
  }
}

report_timing_summary -file [file join $report_dir timing_summary_routed.rpt]
report_route_status -file [file join $report_dir route_status.rpt]
report_drc -file [file join $report_dir drc_routed.rpt]
report_cdc -details -file [file join $report_dir cdc_routed.rpt]
report_clock_utilization -file [file join $report_dir clock_utilization.rpt]
report_bus_skew -file [file join $report_dir bus_skew.rpt]

set timing_text [report_timing_summary -return_string]
if {[regexp {Timing constraints are not met} $timing_text]} {
  error "Milestone-3 routed timing constraints are not met"
}
puts "Milestone-3 routed audit passed"
puts "Managed GT sites: $managed_sites"
puts "Reports: $report_dir"
