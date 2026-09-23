set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set report_dir [file join $repo_dir build all_links_v1_reports slr_bank]
file mkdir $report_dir
set timing [report_timing_summary -delay_type min_max -max_paths 100 -report_unconstrained \
  -return_string -file [file join $report_dir timing_routed.rpt]]
if {![regexp {Setup\s*:\s*([0-9]+)\s+Failing Endpoints,\s+Worst Slack\s+([-0-9.]+)ns} $timing -> setup_failed wns]} {
  error "Cannot parse routed setup summary"
}
if {![regexp {Hold\s*:\s*([0-9]+)\s+Failing Endpoints,\s+Worst Slack\s+([-0-9.]+)ns} $timing -> hold_failed whs]} {
  error "Cannot parse routed hold summary"
}
if {$setup_failed != 0 || $hold_failed != 0 || $wns < 0 || $whs < 0} {
  error "Routed timing failed: setup $wns/$setup_failed hold $whs/$hold_failed"
}
set routing [report_route_status -return_string -file [file join $report_dir route_status_routed.rpt]]
if {![regexp {# of nets with routing errors[. ]*:[ ]*0} $routing] ||
    ![regexp {# of unrouted nets[. ]*:[ ]*0} $routing] ||
    ![regexp {# of nets with some unrouted pins[. ]*:[ ]*0} $routing] ||
    ![regexp {# of nets with resource conflicts[. ]*:[ ]*0} $routing]} {
  error "Routed net status is not clean"
}
set skew [report_bus_skew -warn_on_violation -return_string -file [file join $report_dir bus_skew_routed.rpt]]
if {[regexp -all {Slack \(MET\)} $skew] != 28 || [string match {*VIOLATED*} $skew]} {
  error "Expected 28 passing routed bus-skew groups"
}
report_drc -file [file join $report_dir drc_routed.rpt]
foreach violation [get_drc_violations -quiet] {
  if {[get_property SEVERITY $violation] eq "Error"} {error "Routed DRC error $violation"}
}
for {set slr 0} {$slr < 4} {incr slr} {
  set boundary [get_cells -quiet -of_objects [get_pblocks all_links_v1_control_slr$slr]]
  if {[llength $boundary] != 8} {error "SLR$slr boundary pblock count [llength $boundary], expected 8"}
  foreach cell $boundary {
    set actual [get_property NAME [get_slrs -quiet -of_objects [get_sites -quiet -of_objects $cell]]]
    if {$actual ne "SLR$slr"} {error "Boundary cell escaped SLR$slr: $cell actual=$actual"}
  }
}
puts "PASS: routed SLR-bank signoff WNS=$wns WHS=$whs, 0 failing endpoints, 28 bus-skew groups, clean routing/DRC"
