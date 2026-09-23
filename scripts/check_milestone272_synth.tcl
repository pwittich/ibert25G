source [file join [file dirname [info script]] check_milestone271_synth.tcl]

set configured_generics [get_property GENERIC [get_filesets sources_1]]
foreach required {
  {HARDWARE_VERSION=131350}
  {RUNTIME_INTEGRITY_DETECTOR=1}
} {
  if {[lsearch -exact $configured_generics $required] < 0} {
    error "Missing frozen v272 generic: $required"
  }
}

# The enabled target must retain the monitor state that default-off historical
# targets are permitted to optimize away.
foreach {label pattern minimum} {
  integrity_event_count {.*u_runtime_integrity_monitor/event_count_reg.*} 1
  integrity_error_counters {.*u_runtime_integrity_monitor/error_assert_count_reg.*} 4
  integrity_clock_counter {.*u_runtime_integrity_monitor/heartbeat_timeout_count_reg.*} 1
  integrity_retained_lanes {.*u_runtime_integrity_monitor/retained_error_lanes_reg.*} 1
} {
  set cells [get_cells -hier -quiet -regexp $pattern]
  if {[llength $cells] < $minimum} {
    error "Enabled v272 monitor is missing $label state: $pattern"
  }
}
puts "V272 runtime-integrity monitor netlist and target generics verified"
