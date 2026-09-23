# Prove both profile CDC controls originate at the intended management-domain
# registers, with no combinational decode between source and first RX stage.
foreach {label destination_pattern source_pattern expected_count} {
  measurement *g_profile*.profile/measure_meta_reg *u_engine/u_core/measurement_active_reg 4
  epoch       *g_profile*.profile/run_meta_reg     *u_engine/u_core/start_req_toggle_reg 4
} {
  set destinations [get_cells -hier -filter "NAME =~ $destination_pattern"]
  if {[llength $destinations] != $expected_count} {
    error "Expected $expected_count $label profile destinations; found [llength $destinations]"
  }
  foreach destination $destinations {
    set d_pin [get_pins -of_objects $destination -filter {REF_PIN_NAME == D}]
    set startpoints [all_fanin -flat -startpoints_only -to $d_pin]
    set source_cells [get_cells -quiet -of_objects $startpoints]
    set matching [filter $source_cells "NAME =~ $source_pattern"]
    if {[llength $matching] != 1 || [llength $source_cells] != 1} {
      error "$label destination $destination has unexpected source cells: $source_cells"
    }
    set logic_cells [all_fanin -flat -only_cells -to $d_pin]
    set combinational [filter $logic_cells {IS_SEQUENTIAL == 0}]
    if {[llength $combinational] != 0} {
      error "$label destination $destination has combinational fanin: $combinational"
    }
  }
}
puts "Profile measurement and epoch CDC sources are registered and direct"
