source [file join [file dirname [info script]] check_milestone271_synth.tcl]

set configured_generics [get_property GENERIC [get_filesets sources_1]]
foreach required {
  {HARDWARE_VERSION=131352}
  {RUNTIME_INTEGRITY_DETECTOR=1}
  {EXTERNAL_STARTUP_QUAD_RESTART=1}
  {INTEGRITY_HEARTBEAT_TEST_HOOK=1}
} {
  if {[lsearch -exact $configured_generics $required] < 0} {
    error "Missing frozen v274 generic: $required"
  }
}

foreach {label pattern minimum} {
  startup_restart_state {.*u_managed_quad124/u_prbs_test_controller/startup_quad_restart_issued_reg.*} 1
  integrity_event_count {.*u_runtime_integrity_monitor/event_count_reg.*} 1
  integrity_error_counters {.*u_runtime_integrity_monitor/error_assert_count_reg.*} 4
  integrity_clock_counter {.*u_runtime_integrity_monitor/heartbeat_timeout_count_reg.*} 1
  integrity_retained_lanes {.*u_runtime_integrity_monitor/retained_error_lanes_reg.*} 1
  heartbeat_test_control {.*u_engine/u_core/tx_error_inject_toggle_reg\[15\].*} 1
} {
  set cells [get_cells -hier -quiet -regexp $pattern]
  if {[llength $cells] < $minimum} {
    error "Enabled v274 design is missing $label state: $pattern"
  }
}
puts "V274 heartbeat-test, planned-startup-restart, and runtime-integrity netlist verified"
