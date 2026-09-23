set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
open_project [file join $repo_dir build gt_test_all_links_v1 gt_test_all_links_v1.xpr]
open_run synth_1
set actual_channels {}
foreach cell [get_cells -hier -quiet -filter {REF_NAME == GTYE4_CHANNEL && IS_PRIMITIVE}] {
  lappend actual_channels [get_property LOC $cell]
}
set actual_commons {}
foreach cell [get_cells -hier -quiet -filter {REF_NAME == GTYE4_COMMON && IS_PRIMITIVE}] {
  lappend actual_commons [get_property LOC $cell]
}
puts "CHANNEL_SITES [lsort -dictionary $actual_channels]"
puts "COMMON_SITES [lsort -dictionary $actual_commons]"
foreach cell [lsort [get_cells -hier -quiet -filter {
  NAME =~ *g_left_quad*0*u_prbs_test_controller/state_reg* && REF_NAME =~ FD*}]] {
  puts "Q0_PRBS_STATE [get_property NAME $cell] REF=[get_property REF_NAME $cell] FSM=[get_property FSM_ENCODING $cell]"
}
foreach cell [lsort [get_cells -hier -quiet -filter {REF_NAME =~ gt_prbs_test_controller*}]] {
  puts "CONTROLLER [get_property NAME $cell] REF=[get_property REF_NAME $cell]"
}
foreach cell [lsort [get_cells -hier -quiet -filter {
  REF_NAME =~ managed_all_links_left_quad_wrapper* ||
  REF_NAME =~ managed_direct_quad_v6_wrapper*}]] {
  puts "WRAPPER [get_property NAME $cell] REF=[get_property REF_NAME $cell]"
}
close_project
