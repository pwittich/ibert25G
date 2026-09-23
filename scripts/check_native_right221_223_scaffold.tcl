# Tcl-only consistency check for the initial native proof scaffold. It does
# not require Vivado, a project, a checkpoint, a license, or board access.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
source [file join $script_dir native_right221_223_config.tcl]

foreach {name actual expected} [list \
  name $native_proof_name gt_native_right221_223 \
  first_lane $native_proof_lane_first 56 \
  last_lane $native_proof_lane_last 67 \
  source_quad $native_proof_refclk_source_quad 222 \
  refclk_port $native_proof_refclk_port p_rt_r0_n \
  line_rate $native_proof_line_rate_gbps 25.78125 \
  refclk $native_proof_refclk_mhz 322.265625 \
  user_width $native_proof_user_data_width 80] {
  if {$actual ne $expected} { error "$name is $actual, expected $expected" }
}
if {[llength $native_proof_quad_indices] != 3 ||
    [lindex $native_proof_quad_indices 0] != 14 ||
    [lindex $native_proof_quad_indices 1] != 15 ||
    [lindex $native_proof_quad_indices 2] != 16 ||
    [llength $native_proof_physical_quads] != 3 ||
    [lindex $native_proof_physical_quads 0] != 221 ||
    [lindex $native_proof_physical_quads 1] != 222 ||
    [lindex $native_proof_physical_quads 2] != 223 ||
    [llength $native_proof_refclk_routes] != 3 ||
    [lindex [lindex $native_proof_refclk_routes 0] 1] ne "south" ||
    [lindex [lindex $native_proof_refclk_routes 1] 1] ne "local" ||
    [lindex [lindex $native_proof_refclk_routes 2] 1] ne "north"} {
  error "q221-223 shared-refclk topology changed"
}
if {$native_proof_channel_sites ne {
  GTYE4_CHANNEL_X1Y4 GTYE4_CHANNEL_X1Y5 GTYE4_CHANNEL_X1Y6 GTYE4_CHANNEL_X1Y7
  GTYE4_CHANNEL_X1Y8 GTYE4_CHANNEL_X1Y9 GTYE4_CHANNEL_X1Y10 GTYE4_CHANNEL_X1Y11
  GTYE4_CHANNEL_X1Y12 GTYE4_CHANNEL_X1Y13 GTYE4_CHANNEL_X1Y14 GTYE4_CHANNEL_X1Y15
} || $native_proof_common_sites ne {
  GTYE4_COMMON_X1Y1 GTYE4_COMMON_X1Y2 GTYE4_COMMON_X1Y3
}} {
  error "q221-223 sites differ from the full routed baseline"
}
if {$native_proof_wizard_channels ne {
  X1Y4 X1Y5 X1Y6 X1Y7 X1Y8 X1Y9 X1Y10 X1Y11
  X1Y12 X1Y13 X1Y14 X1Y15
}} {
  error "q221-223 Wizard channel IDs differ from the routed-site baseline"
}
foreach file {
  src/gt_native_active_quad_contract.sv
  src/gt_native_right221_223_shell.sv
  scripts/create_native_right221_223_ip.tcl
  scripts/audit_native_right221_223_routed.tcl
} {
  if {![file exists [file join $repo_dir $file]]} {
    error "native proof scaffold is missing $file"
  }
}
puts "Native q221-223 scaffold is internally consistent"
