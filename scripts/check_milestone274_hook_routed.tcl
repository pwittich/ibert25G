# V274-only proof that the diagnostic control is preserved in the routed
# heartbeat-monitor input cone.  This distinguishes an implemented test hook
# from a control register that survived only because it also drives TX error
# injection.
set heartbeat_meta_cells [get_cells -hier -quiet -regexp \
  {.*u_runtime_integrity_monitor/heartbeat_meta_reg}]
if {[llength $heartbeat_meta_cells] != 1} {
  error "Expected one routed heartbeat meta register; found [llength $heartbeat_meta_cells]"
}

set heartbeat_meta_d [get_pins -quiet -of_objects $heartbeat_meta_cells \
  -filter {REF_PIN_NAME == D}]
if {[llength $heartbeat_meta_d] != 1} {
  error "Expected one heartbeat meta D pin; found [llength $heartbeat_meta_d]"
}

set heartbeat_startpoints [all_fanin -flat -startpoints_only -to $heartbeat_meta_d]
set heartbeat_source_cells [get_cells -quiet -of_objects $heartbeat_startpoints]
set heartbeat_test_controls [filter $heartbeat_source_cells \
  {NAME =~ */u_engine/u_core/tx_error_inject_toggle_reg[15]}]
if {[llength $heartbeat_test_controls] != 1} {
  error "V274 heartbeat control is absent from routed monitor fanin: $heartbeat_source_cells"
}

puts "V274 routed heartbeat-test hook fanin verified: $heartbeat_test_controls -> $heartbeat_meta_cells"
