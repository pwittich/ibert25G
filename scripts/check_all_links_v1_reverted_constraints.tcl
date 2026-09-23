set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set dcp [file join $repo_dir build gt_test_all_links_v1 gt_test_all_links_v1_synth.dcp]
open_checkpoint $dcp
set ::all_links_v1_checkpoint_resume 1
source [file join $script_dir apply_all_links_v1_constraints.tcl]
foreach pattern {all_links_v1_quads_slr* all_links_v1_locality_slr* all_links_v1_kh_locality_slr*} {
  if {[llength [get_pblocks -quiet $pattern]] != 0} {error "Failed pblocks remain: $pattern"}
}
foreach kind {control descriptor} expected {{7 7 7 7} {96 128 128 96}} {
  for {set slr 0} {$slr < 4} {incr slr} {
    set count [llength [get_cells -quiet -of_objects [get_pblocks all_links_v1_${kind}_slr$slr]]]
    if {$count != [lindex $expected $slr]} {error "$kind SLR$slr count $count"}
  }
}
set stale [get_cells -hier -quiet -filter {
  USER_SLR_ASSIGNMENT != "" &&
  (REF_NAME =~ managed_all_links_left_quad_wrapper* ||
   REF_NAME =~ managed_direct_quad_v6_wrapper* ||
   REF_NAME =~ gt_prbs_test_controller* ||
   REF_NAME =~ direct_all_v7_quad_group_aggregate* ||
   REF_NAME == all_links_v1_quad_aggregate)}]
if {[llength $stale]} {error "Stale USER_SLR_ASSIGNMENT cells $stale"}
set kept_controllers [get_cells -hier -quiet -filter {
  REF_NAME =~ gt_prbs_test_controller* && KEEP_HIERARCHY == 1}]
if {[llength $kept_controllers]} {
  error "Failed KEEP_HIERARCHY property remains on [llength $kept_controllers] controllers"
}
puts "PASS: failed all-links locality pblocks/advisories/KEEP_HIERARCHY reverted; control and descriptor pblocks retained"
close_design
