# Continue the unique timing-hardened v2 experiment after correcting only a
# read-only structural-query spelling error.  Reuse the one fresh synthesis;
# implementation must still be fresh and nonincremental.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set name gt_test_all_links_v2_timing_hardened
set project_dir [file join $repo_dir build $name]
set project_file [file join $project_dir ${name}.xpr]
set report_dir [file join $repo_dir build all_links_v2_timing_hardened_reports]
set elf [file join $repo_dir build firmware_all_links_v2 gt_test_all_links_v2.elf]
foreach f [list $project_file $elf] {if {![file isfile $f]} {error "Missing $f"}}
if {![string match "2023.2*" [version -short]]} {error "All-links v2 requires Vivado 2023.2"}
file mkdir $report_dir
open_project $project_file
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Fresh synthesis is not complete"}
if {[get_property PROGRESS [get_runs impl_1]] ne "0%"} {error "Implementation is not fresh"}
foreach run {synth_1 impl_1} {
  set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs $run]
  set_property INCREMENTAL_CHECKPOINT {} [get_runs $run]
}
open_run synth_1
source [file join $script_dir check_all_links_v1_synth.tcl]
# The shared checker uses a scratch variable named "name" while walking cells.
# Restore this flow's artifact stem before emitting checkpoints.
set name gt_test_all_links_v2_timing_hardened
report_utilization -file [file join $report_dir utilization_synth.rpt]
report_cdc -details -file [file join $report_dir cdc_synth.rpt]
report_methodology -file [file join $report_dir methodology_synth.rpt]
write_checkpoint -force [file join $project_dir ${name}_synth.dcp]
close_design
puts "ALL_LINKS_V2_HARDENED: structural preflight passed; launching one normal implementation"
launch_runs impl_1 -to_step route_design -jobs 12
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Implementation failed"}
open_run impl_1
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {
  error "Bitstream compression disabled"
}
set routed_dcp [file join $project_dir ${name}_routed.dcp]
write_checkpoint -force $routed_dcp
set timing [report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose \
  -return_string -file [file join $report_dir timing_summary_routed.rpt]]
set routing [report_route_status -return_string -file [file join $report_dir route_status.rpt]]
report_drc -file [file join $report_dir drc_routed.rpt]
report_bus_skew -file [file join $report_dir bus_skew_routed.rpt]
report_cdc -details -file [file join $report_dir cdc_routed.rpt]
if {![regexp {# of nets with routing errors[. ]*:[ ]*0} $routing]} {error "Routing errors"}
foreach v [get_drc_violations -quiet] {
  if {[get_property SEVERITY $v] eq "Error"} {error "Routed DRC error $v"}
}
if {![string match {*All user specified timing constraints are met.*} $timing]} {
  error "Timing-hardened all-links v2 route misses timing; evidence preserved"
}
puts "PASS: timing-hardened all-links v2 clean normal route; independent audit required"
