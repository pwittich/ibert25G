source [file join [file dirname [info script]] check_milestone271_synth.tcl]

set configured_generics [get_property GENERIC [get_filesets sources_1]]
foreach required {
  {HARDWARE_VERSION=131353}
  {RUNTIME_INTEGRITY_DETECTOR=1}
  {EXTERNAL_STARTUP_QUAD_RESTART=1}
  {INTEGRITY_HEARTBEAT_TEST_HOOK=0}
} {
  if {[lsearch -exact $configured_generics $required] < 0} {
    error "Missing frozen v275 generic: $required"
  }
}

foreach {label pattern minimum} {
  startup_restart_state {.*u_managed_quad124/u_prbs_test_controller/startup_quad_restart_issued_reg.*} 1
  integrity_event_count {.*u_runtime_integrity_monitor/event_count_reg.*} 1
  integrity_error_counters {.*u_runtime_integrity_monitor/error_assert_count_reg.*} 4
  integrity_clock_counter {.*u_runtime_integrity_monitor/heartbeat_timeout_count_reg.*} 1
  integrity_retained_lanes {.*u_runtime_integrity_monitor/retained_error_lanes_reg.*} 1
} {
  set cells [get_cells -hier -quiet -regexp $pattern]
  if {[llength $cells] < $minimum} {
    error "Enabled v275 design is missing $label state: $pattern"
  }
}
puts "V275 qualification policy and disabled heartbeat-test hook verified"
