set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set dcp [file join $repo_dir build gt_test_direct_all_v7r3 \
  gt_test_direct_all_v7r3_routed.dcp]
if {![file isfile $dcp]} {error "Missing routed v7 checkpoint $dcp"}

open_checkpoint $dcp
set wizard [get_cells -hier -quiet -filter {
  NAME =~ *cleanup_wizard_reset_seen* && REF_NAME =~ FD*}]
set lanes [get_cells -hier -quiet -filter {
  NAME =~ *cleanup_lane_reset_seen* && REF_NAME =~ FD*}]
set idle_guards [get_cells -hier -quiet -filter {
  NAME =~ *post_cleanup_idle_guard* && REF_NAME =~ FD*}]
set session_applied [get_cells -hier -quiet -filter {
  (NAME =~ *session_applied_meta_reg || NAME =~ *session_applied_sync_reg) &&
  REF_NAME =~ FD*}]
puts "DIRECT_ALL_V7_CLEANUP wizard_registers=[llength $wizard] lane_registers=[llength $lanes] idle_guards=[llength $idle_guards]"
foreach c $wizard {puts "CLEANUP_WIZARD $c [get_property REF_NAME $c]"}
foreach c $lanes {puts "CLEANUP_LANE $c [get_property REF_NAME $c]"}

set controllers [get_cells -hier -quiet -filter {REF_NAME =~ gt_prbs_test_controller*}]
puts "DIRECT_ALL_V7_CLEANUP controllers=[llength $controllers]"
if {[llength $controllers] != 14} {error "Expected 14 PRBS controllers"}
if {[llength $wizard] != 14} {
  error "Expected one routed Wizard cleanup acknowledgement register per quad"
}
if {[llength $lanes] != 56} {
  error "Expected four routed lane cleanup acknowledgement registers per quad"
}
if {[llength $idle_guards] != 14} {
  error "Expected one routed post-cleanup IDLE guard register per quad"
}
if {[llength $session_applied] != 28} {
  error "Expected two routed TX-session applied acknowledgement registers per quad"
}
puts "PASS: all-direct routed cleanup acknowledgement and IDLE-guard structure"
