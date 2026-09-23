set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set archive [file join $repo_dir build diagnostic_archive all-links-v1-enumerated-leaf-locality-attempt]
set report_dir [file join $repo_dir build all_links_v1_reports]
foreach f [list \
    [file join $report_dir locality_preflight.rpt] \
    [file join $report_dir locality_attempt locality_placement.rpt]] {
  if {![file isfile $f]} {error "Missing evidence $f"}
  file copy -force $f [file join $archive [file tail $f]]
}
foreach pattern {
  preflight_all_links_v1_locality-20260918T201144Z.log
  run_all_links_v1_locality_impl-20260918T201554Z.log
  archive_all_links_v1_locality_placed_failure-20260918T203936Z.log
  check_all_links_v1_reverted_constraints-20260918T204225Z.log
} {
  set f [file join $repo_dir build logs $pattern]
  if {![file isfile $f]} {error "Missing log $f"}
  file copy -force $f [file join $archive $pattern]
}
# reset_run left prior routed products in the run directory.  Preserve them,
# but segregate them so they cannot be mistaken for outputs of this attempt.
set stale_names {
  gt_test_all_links_v1_top_physopt.dcp
  gt_test_all_links_v1_top_routed.dcp
  gt_test_all_links_v1_top_bus_skew_routed.rpt
  gt_test_all_links_v1_top_clock_utilization_routed.rpt
  gt_test_all_links_v1_top_drc_routed.rpt
  gt_test_all_links_v1_top_methodology_drc_routed.rpt
  gt_test_all_links_v1_top_power_routed.rpt
  gt_test_all_links_v1_top_route_status.rpt
  gt_test_all_links_v1_top_timing_summary_routed.rpt
}
set stale_dir [file join $archive pre_attempt_stale_impl_outputs]
file mkdir $stale_dir
foreach name $stale_names {
  set archived [file join $archive $name]
  if {[file isfile $archived]} {file rename -force $archived [file join $stale_dir archived_$name]}
  set run_copy [file join $repo_dir build gt_test_all_links_v1 gt_test_all_links_v1.runs impl_1 $name]
  if {[file isfile $run_copy]} {file rename -force $run_copy [file join $stale_dir run_dir_$name]}
}
set run_dir [file join $repo_dir build gt_test_all_links_v1 gt_test_all_links_v1.runs impl_1]
foreach pattern {*_routed.pb *_routed.rpx *power_summary_routed.pb} {
  foreach f [glob -nocomplain -directory $run_dir $pattern] {
    file rename -force $f [file join $stale_dir run_dir_[file tail $f]]
  }
}
puts "PASS: all-links v1 locality failure archive finalized"
