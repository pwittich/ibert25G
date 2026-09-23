set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
if {![info exists endpoint]} {set endpoint 1}
set name gt_test_direct_quad_v6_f${endpoint}
open_checkpoint [file join $repo_dir build $name ${name}_routed.dcp]
puts "RESET_CELLS"
foreach c [get_cells -hier -filter {NAME =~ *reset* && REF_NAME =~ FD*}] {
  puts "$c REF=[get_property REF_NAME $c] ASYNC=[get_property ASYNC_REG $c]"
}
puts "POLICY_CELLS"
foreach c [get_cells -hier -filter {NAME =~ *lane_reset_policy*}] {puts "$c REF=[get_property REF_NAME $c]"}
