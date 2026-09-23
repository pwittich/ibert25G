set root [file dirname [file dirname [file normalize [info script]]]]
open_checkpoint [file join $root build gt_test_firefly1_loopback_v5 gt_test_firefly1_loopback_v5_routed.dcp]
foreach cell [get_cells -hier -filter {NAME =~ *u_lane_reset_policy/reset_pipe_reg* && REF_NAME =~ FD*}] {
  puts "RESET_SOURCE $cell"
  puts "RESET_ENDPOINTS [all_fanout -flat -endpoints_only -from [get_pins $cell/Q]]"
}
puts "LANE_RESET_NETS [get_nets -hier -filter {NAME =~ *lane_rx_reset* || NAME =~ *rx_reset}]"
