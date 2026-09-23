# Routed gate for the live-supervisor FireFly-1 q121/q122/q123 proof.
# The reused harness keeps q221/q222/q223 hierarchy labels; the physical SITE
# checks below are the authoritative identity of this distinct left-side image.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set proof_name gt_native_left121_123_managed_proof_v1
set dcp [file join $repo_dir build $proof_name ${proof_name}_routed.dcp]
if {![file exists $dcp]} { error "Missing managed proof checkpoint: $dcp" }
open_checkpoint $dcp

set expected_channels {GTYE4_CHANNEL_X0Y4 GTYE4_CHANNEL_X0Y5 GTYE4_CHANNEL_X0Y6 GTYE4_CHANNEL_X0Y7 GTYE4_CHANNEL_X0Y8 GTYE4_CHANNEL_X0Y9 GTYE4_CHANNEL_X0Y10 GTYE4_CHANNEL_X0Y11 GTYE4_CHANNEL_X0Y12 GTYE4_CHANNEL_X0Y13 GTYE4_CHANNEL_X0Y14 GTYE4_CHANNEL_X0Y15}
set expected_commons {GTYE4_COMMON_X0Y1 GTYE4_COMMON_X0Y2 GTYE4_COMMON_X0Y3}
set channels [get_cells -hier -filter {REF_NAME == GTYE4_CHANNEL && (NAME =~ *u_q221/* || NAME =~ *u_q222/* || NAME =~ *u_q223/*)}]
set commons [get_cells -hier -filter {REF_NAME == GTYE4_COMMON && (NAME =~ *u_q221/* || NAME =~ *u_q222/* || NAME =~ *u_q223/*)}]
if {[llength $channels] != 12 || [llength $commons] != 3} { error "Expected 12 channels/3 commons, got [llength $channels]/[llength $commons]" }
set actual_channels {}; foreach c $channels { lappend actual_channels [get_property SITE $c] }
set actual_commons {}; foreach c $commons { lappend actual_commons [get_property SITE $c] }
if {[lsort $actual_channels] ne [lsort $expected_channels]} { error "Channel sites differ: $actual_channels" }
if {[lsort $actual_commons] ne [lsort $expected_commons]} { error "Common sites differ: $actual_commons" }

set supervisors {}
foreach c [get_cells -hier *u_supervisor*] {
  if {[regexp {g_quad\[[0-2]\]\.u_supervisor$} $c]} { lappend supervisors $c }
}
if {[llength $supervisors] != 3} { error "Expected three retained quad supervisors, got [llength $supervisors]" }

set routes [report_route_status -return_string]
if {![regexp {# of nets with routing errors[. ]*:[ ]*0} $routes]} { error "Managed proof has routing errors" }
set timing [report_timing_summary -return_string]
if {![string match {*All user specified timing constraints are met.*} $timing]} {
  error "Managed proof has an unmet timing constraint"
}
report_drc
foreach violation [get_drc_violations -quiet] {
  if {[get_property SEVERITY $violation] eq "Error"} {
    error "Managed proof has DRC error: $violation"
  }
}
report_timing_summary -file [file join $repo_dir build $proof_name audit_timing_summary.rpt]
report_drc -file [file join $repo_dir build $proof_name audit_drc.rpt]
puts "PASS: managed FireFly-1 q121/q122/q123 sites, supervisors, and routing audited"
close_design
