# Routed ownership/topology and retained active-contract presence check.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set native_proof_checkpoint [file join $repo_dir build gt_native_right221_223_functional_proof_v1 \
  gt_native_right221_223_functional_proof_v1_routed.dcp]
source [file join $script_dir audit_native_right221_223_routed.tcl]
open_checkpoint $native_proof_checkpoint
if {[get_property BITSTREAM.GENERAL.COMPRESS [current_design]] ne "TRUE"} {
  error "Functional proof compression is disabled"
}
set adapter [get_cells -hier -quiet -regexp {.*u_active_platform.*}]
if {[llength $adapter] == 0} { error "Missing retained active-quad platform adapter" }
# The adapter boundary is DONT_TOUCH; Vivado may legally flatten its purely
# combinational child contract within that boundary.  Functional behavior is
# established by the companion engine simulation, so do not mistake that
# flattening for a missing contract.
foreach {site pin_name} {
  GTYE4_CHANNEL_X1Y4 GTSOUTHREFCLK0 GTYE4_CHANNEL_X1Y8 GTREFCLK0
  GTYE4_CHANNEL_X1Y12 GTNORTHREFCLK0 GTYE4_COMMON_X1Y1 GTSOUTHREFCLK00
  GTYE4_COMMON_X1Y2 GTREFCLK00 GTYE4_COMMON_X1Y3 GTNORTHREFCLK00
} {
  if {[string match "GTYE4_COMMON*" $site]} { set ref_name GTYE4_COMMON } else { set ref_name GTYE4_CHANNEL }
  set cell [get_cells -hier -quiet -filter "SITE == $site && REF_NAME == $ref_name"]
  set pin [get_pins -of_objects $cell -quiet -filter "REF_PIN_NAME == $pin_name"]
  set net [get_nets -of_objects $pin -quiet]
  if {[llength $cell] != 1 || [llength $pin] != 1 || [llength $net] != 1 ||
      [string first {gtrefclk00_in[0]} [get_property NAME $net]] < 0} {
    error "$site does not retain the expected q222 dedicated-refclk endpoint $pin_name"
  }
}
puts "Native q221-223 functional active-quad adapter audit passed"
close_design
