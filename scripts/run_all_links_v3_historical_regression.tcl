# Run unchanged historical tests in new directories, preserving old evidence.
set suite_dir [file dirname [file normalize [info script]]]
set stamp [clock microseconds]
foreach script {
  run_all_links_v2_participation_sim.tcl run_all_links_v2_result_copy_sim.tcl
  run_all_links_v1_aggregate_sim.tcl run_all_links_v1_subset_sim.tcl
  run_all_links_v1_focused_sim.tcl run_all_links_v1_rearm_sim.tcl
  run_prbs_pma_regression.tcl
} {
  set f [open [file join $suite_dir $script] r]; set body [read $f]; close $f
  # This substitution affects only each runner's generated work directory.
  set body [string map [list \
    all_links_v2_participation_sim all_links_v2_participation_sim_v3_regression_$stamp \
    all_links_v2_result_copy_sim all_links_v2_result_copy_sim_v3_regression_$stamp \
    all_links_v1_aggregate_sim all_links_v1_aggregate_sim_v3_regression_$stamp \
    all_links_v1_subset_sim all_links_v1_subset_sim_v3_regression_$stamp \
    all_links_v1_focused_sim all_links_v1_focused_sim_v3_regression_$stamp \
    all_links_v1_rearm_sim all_links_v1_rearm_sim_v3_regression_$stamp \
    prbs_pma_regression prbs_pma_regression_v3_regression_$stamp \
    {file delete -force $work} {if {[file exists $work]} {error "Refusing existing regression work directory"}}] $body]
  # Keep info-script-based roots absolute after preceding runners change cwd.
  set body [string map [list {[info script]} [list [file join $suite_dir $script]]] $body]
  puts "HISTORICAL_REGRESSION $script"
  eval $body
}
puts "PASS: v3 historical regressions in isolated generated directories"
