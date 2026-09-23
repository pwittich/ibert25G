# Prove that the qualification target uses the physical divided heartbeat
# directly and that v274's lane-15 diagnostic control is absent from its cone.
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
set physical_heartbeat_sources [filter $heartbeat_source_cells \
  {NAME =~ */u_managed_quad124/rx_clock_heartbeat_divider_reg[15]}]
set diagnostic_controls [filter $heartbeat_source_cells \
  {NAME =~ */u_engine/u_core/tx_error_inject_toggle_reg[15]}]
if {[llength $physical_heartbeat_sources] != 1 ||
    [llength $diagnostic_controls] != 0} {
  error "V275 heartbeat fanin is not physical-only: $heartbeat_source_cells"
}
puts "V275 routed heartbeat policy verified: physical divider only"
