# One clean, nonincremental synthesis and normal implementation for all-links
# v2.  Stop at routed DCP; independent audit must pass before bit generation.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set v2_name [expr {$argc == 1 ? [lindex $argv 0] : "gt_test_all_links_v2"}]
if {$v2_name ni {gt_test_all_links_v2 gt_test_all_links_v2_timing_hardened}} {
  error "Unsupported all-links v2 project name $v2_name"
}
set project_dir [file join $repo_dir build $v2_name]
set project_file [file join $project_dir ${v2_name}.xpr]
set elf [file join $repo_dir build firmware_all_links_v2 gt_test_all_links_v2.elf]
set report_leaf [expr {$v2_name eq "gt_test_all_links_v2" ?
  "all_links_v2_reports" : "all_links_v2_timing_hardened_reports"}]
set report_dir [file join $repo_dir build $report_leaf]
foreach f [list $project_file $elf] {if {![file isfile $f]} {error "Missing $f"}}
if {![string match "2023.2*" [version -short]]} {error "All-links v2 requires Vivado 2023.2"}
file mkdir $report_dir
open_project $project_file
if {[get_property PART [current_project]] ne "xcvu13p-flga2577-2-e"} {error "Wrong part"}
if {[get_property TOP [get_filesets sources_1]] ne "gt_test_all_links_v1_top"} {error "Wrong reusable top"}
if {[get_property GENERIC [get_filesets sources_1]] ne {HARDWARE_VERSION=32'h00020501}} {
  error "Wrong v2 hardware generic: [get_property GENERIC [get_filesets sources_1]]"
}
set external_elfs {}
foreach f [get_files -all -quiet *.elf] {if {![get_property IS_GENERATED $f]} {lappend external_elfs $f}}
if {[llength $external_elfs] != 1 ||
    [file normalize [lindex $external_elfs 0]] ne [file normalize $elf] ||
    [get_property SCOPED_TO_REF [lindex $external_elfs 0]] ne "gt_test_milestone3_bd" ||
    [get_property SCOPED_TO_CELLS [lindex $external_elfs 0]] ne "microblaze_0"} {
  error "ELF association is not exact: $external_elfs"
}
foreach run {synth_1 impl_1} {
  if {[get_property PROGRESS [get_runs $run]] ne "0%"} {error "$run is not fresh"}
  set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs $run]
  set_property INCREMENTAL_CHECKPOINT {} [get_runs $run]
}
puts "ALL_LINKS_V2_BUILD: launching fresh clean nonincremental synthesis"
launch_runs synth_1 -jobs 12
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "All-links v2 synthesis failed"}
open_run synth_1
source [file join $script_dir check_all_links_v1_synth.tcl]
report_utilization -file [file join $report_dir utilization_synth.rpt]
report_cdc -details -file [file join $report_dir cdc_synth.rpt]
report_methodology -file [file join $report_dir methodology_synth.rpt]
write_checkpoint [file join $project_dir ${v2_name}_synth.dcp]
close_design
puts "ALL_LINKS_V2_BUILD: launching one normal implementation through route_design"
launch_runs impl_1 -to_step route_design -jobs 12
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "All-links v2 implementation failed"}
open_run impl_1
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {
  error "Bitstream compression disabled"
}
set routed_dcp [file join $project_dir ${v2_name}_routed.dcp]
write_checkpoint $routed_dcp
set timing [report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose \
  -return_string -file [file join $report_dir timing_summary_routed.rpt]]
set routing [report_route_status -return_string -file [file join $report_dir route_status.rpt]]
report_drc -file [file join $report_dir drc_routed.rpt]
report_bus_skew -file [file join $report_dir bus_skew_routed.rpt]
report_cdc -details -file [file join $report_dir cdc_routed.rpt]
if {![regexp {# of nets with routing errors[. ]*:[ ]*0} $routing]} {error "Routed design has routing errors"}
foreach v [get_drc_violations -quiet] {if {[get_property SEVERITY $v] eq "Error"} {error "Routed DRC error $v"}}
if {![string match {*All user specified timing constraints are met.*} $timing]} {
  error "All-links v2 normal route misses timing; preserved for reviewed classification"
}
puts "PASS: all-links v2 clean normal route; independent audit required before bit"
