# v270 isolated target only. Replace the former quad-124 blanket clock group
# with equivalent directional exceptions excluding the descriptor data pins.
# Called after synthesis and as the implementation pre-opt hook.
set quad_clocks [get_clocks -include_generated_clocks gtrefclk0_4]
if {[llength $quad_clocks] < 2} { error "Missing managed quad generated clocks" }
set descriptor_pins [get_pins -hier -filter {
  NAME =~ */g_lane*.g_managed.u_lane/selected_meta_reg/D ||
  NAME =~ */g_lane*.g_managed.u_lane/prbs_meta_reg*/D}]
if {[llength $descriptor_pins] != 16} {
  error "Expected 16 quad descriptor capture pins, got [llength $descriptor_pins]"
}
set other_clocks {}
foreach c [get_clocks] {
  if {[lsearch -exact $quad_clocks $c] < 0} { lappend other_clocks $c }
}
set sinks [get_pins -of_objects [all_registers -clock $quad_clocks] \
  -filter {DIRECTION == IN && IS_CLOCK == 0}]
set excepted_sinks {}
foreach p $sinks {
  if {[lsearch -exact $descriptor_pins $p] < 0} { lappend excepted_sinks $p }
}
if {![llength $excepted_sinks]} { error "No non-descriptor RX-domain sinks" }
# Keep the prior exceptions for other CDC data, including CE/reset pins;
# this change is deliberately not a global CDC requalification.
set_false_path -from $other_clocks -to $excepted_sinks
set async_sinks [all_registers -clock $quad_clocks -async_pins]
if {[llength $async_sinks]} { set_false_path -from $other_clocks -to $async_sinks }
set_false_path -from $quad_clocks -to $other_clocks
# 3 ns < one 322.265625-MHz RX period; the request path adds two RX stages.
# This leaves one cycle for capture skew and one for synchronizer resolution.
set_max_delay -datapath_only 3.000 -from [get_clocks clk_200] -to $descriptor_pins
puts "DESCRIPTOR_CDC_CONSTRAINTS 16 capture pins, 3.000 ns datapath bound"
