set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set routed_checkpoint [file join $repo_dir build gt_test_milestone254 \
  gt_test_milestone254.runs impl_1 gt_test_milestone25_top_routed.dcp]
set report_dir [file join $repo_dir build gt_test_milestone254_audit]

if {![file exists $routed_checkpoint]} {
  error "Milestone-2.5.4 routed checkpoint is missing: $routed_checkpoint"
}
file mkdir $report_dir
open_checkpoint $routed_checkpoint
if {[get_property PART [current_design]] ne "xcvu13p-flga2577-2-e"} {
  error "Milestone-2.5.4 routed checkpoint targets the wrong part"
}
if {![string equal -nocase \
      [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] "TRUE"]} {
  error "Milestone-2.5.4 bitstream compression is not enabled"
}

set channels [get_cells -hier -filter {REF_NAME == GTYE4_CHANNEL}]
if {[llength $channels] != 4} {
  error "Expected four managed GT channels; found [llength $channels]"
}
set sites {}
foreach channel $channels { lappend sites [get_property SITE $channel] }
set sites [lsort $sites]
set expected_sites [list GTYE4_CHANNEL_X0Y16 GTYE4_CHANNEL_X0Y17 \
  GTYE4_CHANNEL_X0Y18 GTYE4_CHANNEL_X0Y19]
if {$sites ne $expected_sites} {
  error "Managed quad occupies $sites, expected $expected_sites"
}
set golden_rx_properties [list \
  ADAPT_CFG1 16'hF81C RXCDR_CFG3 16'h0012 RXDFE_GC_CFG2 16'hFFF0 \
  RX_DEGEN_CTRL 3'b100 RX_DFE_AGC_CFG1 2 \
  RX_SUM_DEGEN_AVTT_OVERITE 0 RX_SUM_VCMTUNE 4'b0011]
foreach channel $channels {
  foreach {property expected} $golden_rx_properties {
    if {[get_property $property $channel] ne $expected} {
      error "$channel $property differs from the golden value $expected"
    }
  }
}

report_timing_summary -file [file join $report_dir timing_summary_routed.rpt]
report_route_status -file [file join $report_dir route_status.rpt]
report_drc -file [file join $report_dir drc_routed.rpt]
report_cdc -details -file [file join $report_dir cdc_routed.rpt]
report_methodology -file [file join $report_dir methodology_routed.rpt]
report_clock_utilization -file [file join $report_dir clock_utilization.rpt]
report_bus_skew -file [file join $report_dir bus_skew.rpt]
foreach {clock_name expected_period} {clk_100_raw 10.000 clk_325_raw 3.077} {
  set clock_object [get_clocks -quiet $clock_name]
  if {[llength $clock_object] != 1} {
    error "Expected exactly one implemented $clock_name clock"
  }
  set actual_period [get_property PERIOD $clock_object]
  if {abs($actual_period - $expected_period) > 0.001} {
    error "$clock_name period is $actual_period ns, expected $expected_period ns"
  }
}
set timing_text [report_timing_summary -return_string]
if {[regexp {Timing constraints are not met} $timing_text]} {
  error "Milestone-2.5.4 routed timing constraints are not met"
}
set route_text [report_route_status -return_string]
if {![regexp {# of nets with routing errors[^0-9]*0} $route_text]} {
  error "Milestone-2.5.4 routed design does not report zero routing errors"
}
set drc_errors [get_drc_violations -quiet -filter {SEVERITY == Error}]
if {[llength $drc_errors] != 0} {
  error "Milestone-2.5.4 routed design has [llength $drc_errors] DRC errors"
}
puts "Milestone-2.5.4 routed audit passed"
puts "Managed GT sites: $sites"
puts "Reports: $report_dir"
