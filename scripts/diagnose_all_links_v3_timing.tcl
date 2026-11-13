set repo [file dirname [file dirname [file normalize [info script]]]]
set report_dir [file join $repo build all_links_v3_timing_diagnosis_[clock microseconds]]
file mkdir $report_dir
open_checkpoint [file join $repo build gt_test_all_links_v3 gt_test_all_links_v3.runs impl_1 gt_test_all_links_v3_top_routed.dcp]
report_timing -delay_type max -max_paths 100 -nworst 1 -file [file join $report_dir setup.rpt]
foreach pattern {*u_lane/lock_meta_reg/D *u_lane/rx_error_sample_reg*/D *local_session_tag_reg*/D *u_config*/*_reg*/D} {
  set pins [get_pins -hier -quiet -filter "NAME =~ $pattern"]
  if {[llength $pins]} {report_timing -delay_type max -to $pins -max_paths 10 -file [file join $report_dir [string map {* any / _} $pattern].rpt]}
}
puts "TIMING_DIAGNOSIS=$report_dir"
