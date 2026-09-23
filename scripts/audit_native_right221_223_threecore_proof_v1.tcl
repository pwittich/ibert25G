# Post-route ownership and topology gate for the isolated three-core proof.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set dcp [file join $repo_dir build gt_native_right221_223_threecore_proof_v1 \
  gt_native_right221_223_threecore_proof_v1_routed.dcp]
if {![file exists $dcp]} { error "Missing three-core routed checkpoint: $dcp" }
open_checkpoint $dcp
set expected_channels {GTYE4_CHANNEL_X1Y4 GTYE4_CHANNEL_X1Y5 GTYE4_CHANNEL_X1Y6 GTYE4_CHANNEL_X1Y7 GTYE4_CHANNEL_X1Y8 GTYE4_CHANNEL_X1Y9 GTYE4_CHANNEL_X1Y10 GTYE4_CHANNEL_X1Y11 GTYE4_CHANNEL_X1Y12 GTYE4_CHANNEL_X1Y13 GTYE4_CHANNEL_X1Y14 GTYE4_CHANNEL_X1Y15}
set expected_commons {GTYE4_COMMON_X1Y1 GTYE4_COMMON_X1Y2 GTYE4_COMMON_X1Y3}
set channels [get_cells -hier -filter {REF_NAME == GTYE4_CHANNEL && (NAME =~ *u_q221/* || NAME =~ *u_q222/* || NAME =~ *u_q223/*)}]
set commons [get_cells -hier -filter {REF_NAME == GTYE4_COMMON && (NAME =~ *u_q221/* || NAME =~ *u_q222/* || NAME =~ *u_q223/*)}]
if {[llength $channels] != 12 || [llength $commons] != 3} { error "Expected 12 channels/3 commons, got [llength $channels]/[llength $commons]" }
set actual_channels {}; foreach c $channels { lappend actual_channels [get_property SITE $c] }
set actual_commons {}; foreach c $commons { lappend actual_commons [get_property SITE $c] }
if {[lsort $actual_channels] ne [lsort $expected_channels]} { error "Channel sites differ: $actual_channels" }
if {[lsort $actual_commons] ne [lsort $expected_commons]} { error "Common sites differ: $actual_commons" }
set routes [report_route_status -return_string]
if {![regexp {# of nets with routing errors[. ]*:[ ]*0} $routes]} {
  error "Three-core proof has routing errors"
}
report_timing_summary -file [file join $repo_dir build gt_native_right221_223_threecore_proof_v1 audit_timing_summary.rpt]
report_drc -file [file join $repo_dir build gt_native_right221_223_threecore_proof_v1 audit_drc.rpt]
puts "PASS: three-core q221/q222/q223 sites and routing audited"
close_design
