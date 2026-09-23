set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set name gt_test_direct_all_v7r3
set project_dir [file join $repo_dir build $name]
set project [file join $project_dir ${name}.xpr]
set run_dir [file join $project_dir ${name}.runs impl_1]
set synth_dcp [file join $project_dir ${name}_synth.dcp]
set routed [file join $project_dir ${name}_routed.dcp]
set source_bit [file join $run_dir gt_test_direct_all_v7_top.bit]
set output_bit [file join $project_dir ${name}.bit]
set archive [file join $repo_dir build diagnostic_archive \
  direct-all-v10-0x00020407-pipelined-incremental-abandoned]
set report_dir [file join $repo_dir build direct_all_v10_clean_reports]

foreach f [list $project $synth_dcp] {
  if {![file isfile $f]} {error "Missing clean-implementation input $f"}
}
if {[file exists $archive]} {error "Refusing existing pipelined incremental archive $archive"}

open_project $project
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
  error "V10 pipelined synthesis is not complete"
}

# Preserve the useful checkpoints from the explicitly abandoned incremental
# route before resetting only implementation.  The route was stopped after
# reporting WNS -0.844 ns with localized congestion; it was never a candidate.
file mkdir $archive
foreach leaf {gt_test_direct_all_v7_top_placed.dcp gt_test_direct_all_v7_top_physopt.dcp runme.log} {
  set source [file join $run_dir $leaf]
  if {[file isfile $source]} {file copy $source $archive}
}
file copy $synth_dcp $archive

reset_run impl_1
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs impl_1]
set_property INCREMENTAL_CHECKPOINT {} [get_runs impl_1]
puts "DIRECT_ALL_V10_CLEAN launching non-incremental implementation from pipelined synthesis"
launch_runs impl_1 -to_step write_bitstream -jobs 12
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
  error "V10 clean implementation failed; run artifacts retained"
}

file mkdir $report_dir
open_run impl_1
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {
  error "V10 bitstream compression is disabled"
}
set channels [get_cells -hier -filter {REF_NAME == GTYE4_CHANNEL && IS_PRIMITIVE}]
set commons [get_cells -hier -filter {REF_NAME == GTYE4_COMMON && IS_PRIMITIVE}]
if {[llength $channels] != 56} {error "Expected 56 routed channels, got [llength $channels]"}
if {[llength $commons] != 14} {error "Expected 14 routed commons, got [llength $commons]"}

set timing_text [report_timing_summary -return_string \
  -file [file join $report_dir timing_summary.rpt]]
report_route_status -file [file join $report_dir route_status.rpt]
report_drc -file [file join $report_dir drc.rpt]
report_bus_skew -file [file join $report_dir bus_skew.rpt]
write_checkpoint -force $routed
if {![string match {*All user specified timing constraints are met.*} $timing_text]} {
  set failing [get_timing_paths -quiet -slack_lesser_than 0.000 -max_paths 1]
  puts "DIRECT_ALL_V10_CLEAN final_wns=[get_property SLACK [lindex $failing 0]]"
  error "V10 clean implementation did not close timing"
}
if {![file isfile $source_bit]} {error "Missing clean generated bitstream $source_bit"}
file copy -force $source_bit $output_bit
puts "PASS: v10 clean implementation meets timing and wrote compressed candidate"
