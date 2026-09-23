# Independent routed structural check for the detector and its intentional
# asynchronous inputs. This supplements, but does not waive, the CDC report.
foreach {label pattern minimum} {
  integrity_event_count {.*u_runtime_integrity_monitor/event_count_reg.*} 1
  integrity_error_synchronizers {.*u_runtime_integrity_monitor/error_(meta|sync)_reg.*} 8
  integrity_heartbeat_synchronizers {.*u_runtime_integrity_monitor/heartbeat_(meta|sync)_reg} 2
  integrity_retained_lanes {.*u_runtime_integrity_monitor/retained_error_lanes_reg.*} 1
} {
  set cells [get_cells -hier -quiet -regexp $pattern]
  if {[llength $cells] < $minimum} {
    error "Routed v272 monitor is missing $label state: $pattern"
  }
}
set integrity_synchronizers [get_cells -hier -quiet -regexp \
  {.*u_runtime_integrity_monitor/(error_(meta|sync)_reg.*|heartbeat_(meta|sync)_reg)}]
if {[llength $integrity_synchronizers] != 10} {
  error "Expected ten runtime-integrity synchronizer registers; found [llength $integrity_synchronizers]"
}
foreach cell $integrity_synchronizers {
  if {![get_property ASYNC_REG $cell]} {
    error "Runtime-integrity synchronizer lacks ASYNC_REG: $cell"
  }
}
puts "Routed runtime-integrity monitor structure verified"
