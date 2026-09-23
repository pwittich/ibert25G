set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set name gt_test_direct_all_v7r3
set project_dir [file join $repo_dir build $name]
set project [file join $project_dir ${name}.xpr]
set run_dir [file join $project_dir ${name}.runs impl_1]
set source_bit [file join $run_dir gt_test_direct_all_v7_top.bit]
set routed [file join $project_dir ${name}_routed.dcp]
set timing [file join $repo_dir build direct_all_v7_reports timing_summary_routed.rpt]
set archive [file join $repo_dir build diagnostic_archive \
  direct-all-v10-0x00020407-incremental-timing-failure]
set report_dir [file join $repo_dir build direct_all_v10_clean_reports]

foreach f [list $project $source_bit $routed $timing] {
  if {![file isfile $f]} {error "Missing failed v10 artifact $f"}
}

open_project $project
if {[get_property PROGRESS [get_runs synth_1]] ne "100%" ||
    [get_property PROGRESS [get_runs impl_1]] ne "100%"} {
  error "Expected completed synthesis and rejected completed implementation"
}
open_run impl_1
set failing [get_timing_paths -quiet -slack_lesser_than 0.000 -max_paths 1]
if {![llength $failing]} {error "Refusing to reset timing-clean implementation"}
puts "DIRECT_ALL_V10_CLEAN_RETRY rejected_wns=[get_property SLACK [lindex $failing 0]]"
close_design

if {[file exists $archive]} {
  # A prior wrapper invocation may have completed the non-destructive archive
  # and stopped before reset.  Resume only if all three primary artifacts are
  # present; never overwrite or silently repair an ambiguous archive.
  foreach f [list $source_bit $routed $timing] {
    set archived [file join $archive [file tail $f]]
    if {![file isfile $archived]} {error "Incomplete existing v10 archive: $archived"}
  }
  puts "DIRECT_ALL_V10_CLEAN_RETRY using complete existing failure archive"
} else {
  file mkdir $archive
  foreach f [list $source_bit $routed $timing] {file copy $f $archive}
  foreach report [glob -nocomplain [file join $repo_dir build direct_all_v7_reports *.rpt]] {
    set destination [file join $archive [file tail $report]]
    if {![file exists $destination]} {file copy $report $destination}
  }
}

reset_run impl_1
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs impl_1]
set_property INCREMENTAL_CHECKPOINT {} [get_runs impl_1]
puts "DIRECT_ALL_V10_CLEAN_RETRY launching clean implementation"
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
  set still_failing [get_timing_paths -quiet -slack_lesser_than 0.000 -max_paths 1]
  puts "DIRECT_ALL_V10_CLEAN_RETRY final_wns=[get_property SLACK [lindex $still_failing 0]]"
  error "V10 clean implementation did not close timing"
}
if {![file isfile $source_bit]} {error "Missing clean generated bitstream $source_bit"}
file copy -force $source_bit [file join $project_dir ${name}.bit]
puts "PASS: v10 clean implementation meets timing and wrote compressed candidate"
