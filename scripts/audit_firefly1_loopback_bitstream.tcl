set s [file dirname [file normalize [info script]]]; set r [file dirname $s]
set d [file join $r build gt_test_firefly1_loopback_v1 gt_test_firefly1_loopback_v1.runs impl_1 gt_test_milestone25_top_routed.dcp]
open_checkpoint $d
set c [get_cells -hier -filter {REF_NAME == GTYE4_CHANNEL && IS_PRIMITIVE}]
if {[llength $c] == 0} {
  puts "GT_CELL_REFS [lsort -unique [get_property REF_NAME [get_cells -hier -filter {REF_NAME =~ *GTY*}]]]"
  error "No GTYE4 channel primitives found"
}
set sites {}; foreach x $c {
  set q [get_property SITE $x]
  if {$q eq ""} {set q [get_property LOC $x]}
  if {$q eq ""} {set q [lindex [get_sites -quiet -of_objects $x] 0]}
  if {$q ne ""} {lappend sites $q}
}
set expected_channels {GTYE4_CHANNEL_X0Y4 GTYE4_CHANNEL_X0Y5 GTYE4_CHANNEL_X0Y6 GTYE4_CHANNEL_X0Y7 GTYE4_CHANNEL_X0Y8 GTYE4_CHANNEL_X0Y9 GTYE4_CHANNEL_X0Y10 GTYE4_CHANNEL_X0Y11 GTYE4_CHANNEL_X0Y12 GTYE4_CHANNEL_X0Y13 GTYE4_CHANNEL_X0Y14 GTYE4_CHANNEL_X0Y15}
if {[lsort -unique $sites] ne $expected_channels} {
  error "FireFly-1 channel ownership failure: expected {$expected_channels}; observed {[lsort -unique $sites]}"
}
set cm [get_cells -hier -filter {REF_NAME == GTYE4_COMMON && IS_PRIMITIVE}]
set common_sites {}; foreach x $cm {
  set q [get_property LOC $x]; if {$q eq ""} {set q [lindex [get_sites -quiet -of_objects $x] 0]}
  if {$q ne ""} {lappend common_sites $q}
}
set expected_commons {GTYE4_COMMON_X0Y1 GTYE4_COMMON_X0Y2 GTYE4_COMMON_X0Y3}
if {[lsort -unique $common_sites] ne $expected_commons} {error "FireFly-1 COMMON ownership failure: expected {$expected_commons}; observed {[lsort -unique $common_sites]}"}
set rt [report_route_status -return_string]; if {![regexp {# of nets with routing errors[. ]*:[ ]*0} $rt]} {error "routing errors"}
set t [report_timing_summary -return_string]; if {![string match {*All user specified timing constraints are met.*} $t]} {error "timing failed"}
report_drc
foreach v [get_drc_violations -quiet] {if {[get_property SEVERITY $v] eq "Error"} {error "DRC error $v"}}
puts "PASS: FireFly-1 corrected routed ownership/COMMON/routing/timing audit"
