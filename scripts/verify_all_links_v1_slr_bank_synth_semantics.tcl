set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set dcp [file join $repo_dir build gt_test_all_links_v1 gt_test_all_links_v1_synth.dcp]
set expected_sha 409a7a24819c0da515d5443688df038649584c0b4e5820e583e909890b812ace
if {![file isfile $dcp]} {error "Missing synthesis DCP: $dcp"}
set actual_sha [lindex [split [exec sha256sum $dcp]] 0]
if {$actual_sha ne $expected_sha} {error "Synthesis DCP SHA mismatch: $actual_sha"}
open_checkpoint $dcp
set out_dir [file join $repo_dir build all_links_v1_reports slr_bank_closeout]
file mkdir $out_dir
set out [open [file join $out_dir synth_measurement_control_proof.rpt] w]
set total_controls 0; set bit1_total 0
for {set slr 0} {$slr < 4} {incr slr} {
  set bank [get_cells -hier -quiet -filter "NAME =~ *g_bank_slr$slr && REF_NAME =~ all_links_v1_slr_bank*"]
  if {[llength $bank] != 1} {close $out; error "Missing synthesis bank SLR$slr"}
  set name [get_property NAME $bank]
  set controls [get_cells -hier -quiet -filter "NAME =~ ${name}/u_control_pipeline/controls_out_reg* && REF_NAME =~ FD*"]
  set bit1 {}
  foreach cell $controls {if {[regexp {controls_out_reg\[1\]$} [get_property NAME $cell]]} {lappend bit1 $cell}}
  set reset [get_cells -hier -quiet -filter "NAME == ${name}/local_resetn_reg && REF_NAME =~ FD*"]
  if {[llength $controls] != 7 || [llength $bit1] != 1 || [llength $reset] != 1} {
    close $out; error "SLR$slr synthesis boundary [llength $controls]/[llength $bit1]/[llength $reset], expected 7/1/1"
  }
  incr total_controls [llength $controls]; incr bit1_total
  set loads [get_pins -quiet -leaf -of_objects [get_nets -quiet -of_objects [get_pins -quiet -of_objects $bit1 -filter {REF_PIN_NAME == Q}]] -filter {DIRECTION == IN}]
  puts $out "SLR$slr controls=7 control_bit_1=1 reset=1 bit1_leaf_loads=[llength $loads]"
}
set controllers [get_cells -hier -quiet -filter {NAME =~ */u_prbs_test_controller && REF_NAME =~ gt_prbs_test_controller*}]
set lane_records [get_cells -hier -quiet -filter {NAME =~ */u_engine/u_core/g_lane*.u_lane && REF_NAME =~ gt_lane_engine*}]
puts $out "controls_total=$total_controls bit1_total=$bit1_total controllers=[llength $controllers] lane_engines=[llength $lane_records]"
puts $out "synth_sha256=$actual_sha"
if {$total_controls != 28 || $bit1_total != 4 || [llength $controllers] != 28 || [llength $lane_records] != 112} {
  close $out; error "Unexpected synthesis semantic inventory"
}
puts $out "PASS: pre-opt retains 7+reset per bank; all 28 constant-disabled runtime-detector controllers and 112 lane engines remain"
close $out
puts "PASS: synthesis measurement-control proof 28 controls, four bit1, 28 controllers, 112 lane engines"
