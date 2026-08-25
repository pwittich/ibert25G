proc require_count {description objects expected} {
  set actual [llength $objects]
  if {$actual != $expected} {
    error "Expected $expected $description, found $actual"
  }
  puts "Validated $description: $actual"
}

require_count "left IBERT quads" \
  [get_cells -quiet -hier -filter {
    NAME =~ u_ibert/u_ibert_left/u_ibert_gty_core/inst/QUAD*.u_q}] 14
require_count "right IBERT quads" \
  [get_cells -quiet -hier -filter {
    NAME =~ u_ibert/u_ibert_right/u_ibert_gty_core/inst/QUAD*.u_q}] 14
require_count "GTYE4_CHANNEL primitives" \
  [get_cells -quiet -hier -filter {REF_NAME == GTYE4_CHANNEL}] 112

require_count "IBERT debug-clock divider" \
  [get_cells -quiet u_ibert_debug_clk_bufg] 1
require_count "IBERT debug-clock divider output" \
  [get_pins -quiet u_ibert_debug_clk_bufg/O] 1
require_count "IBERT debug-clock divider output net" \
  [get_nets -quiet -of_objects [get_pins -quiet u_ibert_debug_clk_bufg/O]] 1

# These endpoints capture the two non-obvious board mappings verified against
# schematic page 64 (FF3) and page 67 (FF6).
foreach {port_name expected_pin} {
  {p_ff3_recv[0]}  P48
  {n_ff3_recv[0]}  P49
  {p_ff3_recv[11]} AE50
  {n_ff3_recv[11]} AE51
  {p_ff3_xmit[0]}  P43
  {n_ff3_xmit[0]}  P44
  {p_ff3_xmit[11]} AE45
  {n_ff3_xmit[11]} AE46
  {p_ff6_recv[1]}  M48
  {n_ff6_recv[1]}  M49
} {
  set port [get_ports -quiet $port_name]
  require_count "top-level port $port_name" $port 1
  set actual_pin [get_property PACKAGE_PIN $port]
  if {$actual_pin ne $expected_pin} {
    error "$port_name must use package pin $expected_pin, found $actual_pin"
  }
}
puts "Validated schematic-derived FF3 and FF6 package pins"
