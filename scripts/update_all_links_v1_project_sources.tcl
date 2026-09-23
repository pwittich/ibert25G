set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
source [file join $script_dir all_links_v1_left_support_manifest.tcl]
set xpr [file join $repo_dir build gt_test_all_links_v1 gt_test_all_links_v1.xpr]
open_project $xpr
foreach name {all_links_v1_quad_aggregate all_links_v1_slr_bank gt_test_direct_quad_v6_core} {
  set f [file join $repo_dir src ${name}.sv]
  if {[llength [get_files -quiet $f]] == 0} {add_files -norecurse $f}
}
add_files -norecurse [all_links_v1_left_support_manifest $repo_dir]
foreach {quad xdc} [all_links_v1_left_xdc_manifest $repo_dir] {
  add_files -fileset constrs_1 -norecurse $xdc
  set xf [get_files $xdc]
  set_property SCOPED_TO_REF all_links_v1_q${quad}_gt_topology $xf
  set_property PROCESSING_ORDER EARLY $xf
}
set board [get_files -quiet [file join $repo_dir constraints board_pins.xdc]]
if {[llength $board] != 1} {error "Expected canonical board_pins.xdc"}
set_property IS_ENABLED true $board
set failed_keep_hierarchy_xdc [get_files -quiet \
  [file join $repo_dir constraints all_links_v1_keep_hierarchy.xdc]]
if {[llength $failed_keep_hierarchy_xdc]} {
  remove_files -fileset constrs_1 $failed_keep_hierarchy_xdc
}
set_property STEPS.OPT_DESIGN.TCL.PRE \
  [file join $script_dir apply_all_links_v1_constraints.tcl] [get_runs impl_1]
update_compile_order -fileset sources_1
puts "PASS: updated all-links v1 support, topology scopes, full-board pins, and implementation pre-hook; failed KEEP_HIERARCHY experiment inactive"
