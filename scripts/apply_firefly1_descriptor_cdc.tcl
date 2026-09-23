# Adapt the established isolated descriptor timing policy to twelve lanes.
set native_clocks [get_clocks -include_generated_clocks gtrefclk0_2]
set rx_clocks [get_clocks -filter {NAME =~ GTYE4_CHANNEL_RXOUTCLK*}]
set tx_clocks [get_clocks -filter {NAME =~ GTYE4_CHANNEL_TXOUTCLK*}]
if {[llength $rx_clocks] != 3 || [llength $native_clocks] < 7} {error "missing native user clocks"}
set descriptor_pins [get_pins -hier -filter {
  NAME =~ */g_lane*.g_managed.u_lane/selected_meta_reg/D ||
  NAME =~ */g_lane*.g_managed.u_lane/prbs_meta_reg*/D}]
if {[llength $descriptor_pins] != 48} {error "expected 48 descriptor endpoints"}
set other_clocks {}
foreach c [get_clocks] {
  if {[lsearch -exact $native_clocks $c] < 0} {lappend other_clocks $c}
}
set sinks [get_pins -of_objects [all_registers -clock $native_clocks] -filter {DIRECTION == IN && IS_CLOCK == 0}]
set excepted {}
foreach p $sinks {
  if {[lsearch -exact $descriptor_pins $p] < 0} {lappend excepted $p}
}
set_false_path -from $other_clocks -to $excepted
set async_sinks [all_registers -clock $native_clocks -async_pins]
if {[llength $async_sinks]} {set_false_path -from $other_clocks -to $async_sinks}
set_false_path -from $native_clocks -to $other_clocks
# Independent CDR phases; the TX control synchronizers cross from lane RX.
set_false_path -from $rx_clocks -to $tx_clocks
set_false_path -from $tx_clocks -to $rx_clocks
set_max_delay -datapath_only 3.000 -from [get_clocks clk_200] -to $descriptor_pins
foreach clk $rx_clocks {
  set endpoints {}
  foreach pin [get_pins -of_objects [all_registers -clock $clk] -filter {REF_PIN_NAME == D}] {
    if {[lsearch -exact $descriptor_pins $pin] >= 0} {lappend endpoints $pin}
  }
  if {[llength $endpoints] != 16} {error "expected 16 descriptor endpoints per RX clock"}
  set sources [all_fanin -flat -startpoints_only -to $endpoints]
  if {![llength $sources]} {error "descriptor sources missing"}
  set_bus_skew 3.000 -from $sources -to $endpoints
}
puts "FIREFLY_DESCRIPTOR_CDC: 48 endpoints bounded to 3 ns; three bus-skew constraints"
