set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set project_file [file join $repo_dir build gt_test_milestone3 \
  gt_test_milestone3.xpr]
set opt_checkpoint [file join $repo_dir build gt_test_milestone3 \
  gt_test_milestone3.runs impl_1 gt_test_milestone3_top_opt.dcp]

if {![file exists $project_file]} {
  error "Milestone-3 project is missing: $project_file"
}
if {![file exists $opt_checkpoint]} {
  error "Milestone-3 optimized checkpoint is missing: $opt_checkpoint"
}

open_project $project_file
reset_runs impl_1 -from_step place_design
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
  error "Milestone-3 implementation continuation failed"
}

open_run impl_1
if {![string equal -nocase \
      [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] "TRUE"]} {
  error "Milestone-3 bitstream compression is not enabled"
}
puts "Milestone-3 implementation continuation completed"
