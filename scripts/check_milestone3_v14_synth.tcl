source [file join [file dirname [info script]] check_milestone271_synth.tcl]
set configured_generics [get_property GENERIC [get_filesets sources_1]]
foreach required {
  {DIAGNOSTIC_TRACE=2} {HARDWARE_VERSION=131086}
  {USE_EXACT_ERROR_COUNTS=1} {DIAGNOSTIC_RX_CLOCK_MONITOR=0}
  {EXTERNAL_RX_RECOVERY=0} {EXTERNAL_QUAD_RECOVERY=1}
  {EXTERNAL_STARTUP_QUAD_RESTART=0} {POST_CAPTURE_RX_REQUAL=0}
  {POST_CAPTURE_QUAD_RESTART=1} {RUNTIME_INTEGRITY_DETECTOR=1}
  {INTEGRITY_HEARTBEAT_TEST_HOOK=0}
} {
  if {[lsearch -exact $configured_generics $required] < 0} {
    error "Missing frozen full-v14 generic: $required"
  }
}
foreach {label pattern minimum} {
  integrity_event_count {.*u_runtime_integrity_monitor/event_count_reg.*} 1
  integrity_error_counters {.*u_runtime_integrity_monitor/error_assert_count_reg.*} 4
  integrity_clock_counter {.*u_runtime_integrity_monitor/heartbeat_timeout_count_reg.*} 1
  integrity_retained_lanes {.*u_runtime_integrity_monitor/retained_error_lanes_reg.*} 1
} {
  set cells [get_cells -hier -quiet -regexp $pattern]
  if {[llength $cells] < $minimum} {
    error "Enabled full-v14 design is missing $label state: $pattern"
  }
}
set startup_restart [get_cells -hier -quiet -regexp \
  {.*u_managed_quad124/u_prbs_test_controller/startup_quad_restart_issued_reg.*}]
if {[llength $startup_restart] != 0} {
  error "v14 must not retain startup quad-restart state"
}
puts "Full Milestone 3 v14 no-startup-restart diagnostic policy verified"
