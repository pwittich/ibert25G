set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set name gt_test_direct_all_v7r3
set project_dir [file join $repo_dir build $name]
set input_dcp [file join $project_dir ${name}_routed.dcp]
set output_dcp [file join $project_dir ${name}_postroute_aggressive.dcp]
set output_bit [file join $project_dir ${name}.bit]
set report_dir [file join $repo_dir build direct_all_v9_postroute]
set archive [file join $repo_dir build diagnostic_archive \
  direct-all-v9-0x00020406-incremental-near-timing]
set source_bit [file join $project_dir ${name}.runs impl_1 gt_test_direct_all_v7_top.bit]
set source_timing [file join $repo_dir build direct_all_v7_reports timing_summary_routed.rpt]

foreach f [list $input_dcp $source_bit $source_timing] {
  if {![file isfile $f]} {error "Missing near-timing artifact $f"}
}
if {[file exists $archive]} {error "Refusing existing v9 near-timing archive $archive"}
file mkdir $archive
foreach f [list $input_dcp $source_bit $source_timing] {file copy $f $archive}
file mkdir $report_dir

open_checkpoint $input_dcp
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {
  error "Compression disabled in input checkpoint"
}
set before [get_timing_paths -quiet -slack_lesser_than 0.000 -max_paths 1]
if {![llength $before]} {error "Input checkpoint already meets timing"}
puts "DIRECT_ALL_V9_POSTROUTE initial_wns=[get_property SLACK [lindex $before 0]]"

phys_opt_design -directive AggressiveExplore
set timing_text [report_timing_summary -return_string \
  -file [file join $report_dir timing_summary.rpt]]
report_route_status -file [file join $report_dir route_status.rpt]
report_drc -file [file join $report_dir drc.rpt]
write_checkpoint -force $output_dcp
if {![string match {*All user specified timing constraints are met.*} $timing_text]} {
  set failing [get_timing_paths -quiet -slack_lesser_than 0.000 -max_paths 1]
  puts "DIRECT_ALL_V9_POSTROUTE final_wns=[get_property SLACK [lindex $failing 0]]"
  error "Post-route aggressive physical optimization did not close timing"
}

file copy -force $output_dcp $input_dcp
write_bitstream -force $output_bit
puts "PASS: v9 post-route aggressive physical optimization closed timing and wrote compressed candidate"
