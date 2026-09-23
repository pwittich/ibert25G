set r [file dirname [file dirname [file normalize [info script]]]]
open_checkpoint [file join $r build gt_test_firefly1_loopback_v4 gt_test_firefly1_loopback_v4_routed.dcp]
foreach c [get_cells -hier -filter {NAME =~ *cleanup* || NAME =~ *reset_seen*}] {
  puts "CLEANUP_CELL $c [get_property REF_NAME $c]"
}
foreach c [get_cells -hier -filter {NAME =~ *g_quad?0?*u_prbs_test_controller* && REF_NAME =~ FD*}] {
  puts "CONTROLLER_FF $c"
}
write_verilog -force -mode funcsim [file join $r build gt_test_firefly1_loopback_v4_audit cleanup_netlist.v]
