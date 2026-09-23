set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set report_dir [file join $repo_dir build all_links_v1_reports keep_hierarchy]
file mkdir $report_dir
source [file join $script_dir verify_all_links_v1_keep_hierarchy_placed.tcl]
set timing [report_timing_summary -delay_type min_max -max_paths 100 -report_unconstrained \
  -return_string -file [file join $report_dir timing_routed.rpt]]
if {![string match {*All user specified timing constraints are met.*} $timing]} {
  error "Routed timing constraints are not all met"
}
foreach kind {max min} {
  set paths [get_timing_paths -quiet -delay_type $kind -max_paths 1]
  if {[llength $paths] != 1 || [get_property SLACK [lindex $paths 0]] < 0} {
    error "Routed $kind timing failed or has no path"
  }
}
set routing [report_route_status -return_string -file [file join $report_dir route_status_routed.rpt]]
if {![regexp {# of nets with routing errors[. ]*:[ ]*0} $routing] ||
    ![regexp {# of unrouted nets[. ]*:[ ]*0} $routing] ||
    ![regexp {# of nets with some unrouted pins[. ]*:[ ]*0} $routing]} {
  error "Routed design has routing/unrouted/partial nets"
}
report_drc -file [file join $report_dir drc_routed.rpt]
foreach violation [get_drc_violations -quiet] {
  if {[get_property SEVERITY $violation] eq "Error"} {error "Routed DRC error $violation"}
}
set skew [report_bus_skew -warn_on_violation -return_string \
  -file [file join $report_dir bus_skew_routed.rpt]]
if {[regexp -all {Slack \(MET\)} $skew] != 28 || [string match {*VIOLATED*} $skew]} {
  error "Expected exactly 28 passing routed bus-skew groups"
}
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {
  error "Bitstream compression disabled"
}
puts "PASS: routed KEEP_HIERARCHY gate; all setup/hold groups met, 28 bus-skew groups met, routing and DRC clean"
