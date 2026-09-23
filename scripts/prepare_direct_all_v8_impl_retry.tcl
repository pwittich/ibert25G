set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set name gt_test_direct_all_v7r3
set project_dir [file join $repo_dir build $name]
set project [file join $project_dir ${name}.xpr]
set run_dir [file join $project_dir ${name}.runs impl_1]
set routed [file join $project_dir ${name}_routed.dcp]
set bit [file join $run_dir gt_test_direct_all_v7_top.bit]
set timing [file join $repo_dir build direct_all_v7_reports timing_summary_routed.rpt]
set archive [file join $repo_dir build diagnostic_archive \
  direct-all-v8-0x00020405-first-timing-failure]
set reference [file join $repo_dir build diagnostic_archive \
  direct-all-v7-0x00020404-failed-pma gt_test_direct_all_v7r3_routed.dcp]
if {[file exists $archive]} {error "Refusing existing v8 timing-failure archive $archive"}
foreach f [list $project $routed $bit $timing $reference] {
  if {![file isfile $f]} {error "Missing required retry artifact $f"}
}

open_project $project
if {[get_property PROGRESS [get_runs synth_1]] ne "100%" ||
    [get_property PROGRESS [get_runs impl_1]] ne "100%"} {
  error "Expected completed synthesis and rejected completed implementation"
}
open_run impl_1
set failing [get_timing_paths -quiet -slack_lesser_than 0.000 -max_paths 1]
if {![llength $failing]} {error "Refusing to reset timing-clean implementation"}
puts "DIRECT_ALL_V8_RETRY rejected_wns=[get_property SLACK [lindex $failing 0]]"
close_design
file mkdir $archive
foreach f [list $routed $bit $timing] {file copy $f $archive}
reset_run impl_1
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs impl_1]
set_property INCREMENTAL_CHECKPOINT $reference [get_runs impl_1]
close_project
puts "PASS: preserved failed v8 route and prepared timing-clean v7 incremental reference"
