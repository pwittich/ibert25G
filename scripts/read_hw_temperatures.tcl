# Read-only hardware-server telemetry. Does not program, reset, or halt a device.
open_hw_manager
connect_hw_server -url lnx4189:3121
set targets [get_hw_targets]
if {[llength $targets] != 1} { error "Expected exactly one connected JTAG chain: $targets" }
open_hw_target [lindex $targets 0]
foreach device [get_hw_devices] {
  puts "DEVICE $device"
  foreach monitor [get_hw_sysmons -of_objects $device] {
    refresh_hw_sysmon $monitor
    report_property $monitor
  }
}
close_hw_manager
