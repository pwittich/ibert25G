# Resume the one clean v2 build after the reporting-only synthesized-DCP name
# collision.  The fresh synth run and its exact preflight passed; impl_1 has
# never launched.  This script refuses any other run state.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set v2_name gt_test_all_links_v2
set project_dir [file join $repo_dir build $v2_name]
set project_file [file join $project_dir ${v2_name}.xpr]
set report_dir [file join $repo_dir build all_links_v2_reports]
open_project $project_file
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
  error "Fresh synthesis is not complete"
}
if {[get_property PROGRESS [get_runs impl_1]] ne "0%"} {
  error "Implementation has already launched; refuse resume"
}
open_run synth_1
source [file join $script_dir check_all_links_v1_synth.tcl]
write_checkpoint [file join $project_dir ${v2_name}_synth.dcp]
close_design
puts "ALL_LINKS_V2_BUILD_RESUME: launching the sole normal implementation"
launch_runs impl_1 -to_step route_design -jobs 12
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
  error "All-links v2 implementation failed"
}
open_run impl_1
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {
  error "Bitstream compression disabled"
}
set routed_dcp [file join $project_dir ${v2_name}_routed.dcp]
write_checkpoint $routed_dcp
set timing [report_timing_summary -delay_type min_max -report_unconstrained \
  -check_timing_verbose -return_string \
  -file [file join $report_dir timing_summary_routed.rpt]]
set routing [report_route_status -return_string \
  -file [file join $report_dir route_status.rpt]]
report_drc -file [file join $report_dir drc_routed.rpt]
report_bus_skew -file [file join $report_dir bus_skew_routed.rpt]
report_cdc -details -file [file join $report_dir cdc_routed.rpt]
if {![regexp {# of nets with routing errors[. ]*:[ ]*0} $routing]} {
  error "Routed design has routing errors"
}
foreach v [get_drc_violations -quiet] {
  if {[get_property SEVERITY $v] eq "Error"} {error "Routed DRC error $v"}
}
if {![string match {*All user specified timing constraints are met.*} $timing]} {
  error "All-links v2 normal route misses timing; preserve for classification"
}
puts "PASS: all-links v2 clean normal route; independent audit required before bit"
