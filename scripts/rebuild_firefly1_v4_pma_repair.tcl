# Development v4 repair. Preserve the exact first hardware-tested revision
# before resetting runs; firmware/ABI are unchanged. Never reuse its hash.
set script_dir [file dirname [file normalize [info script]]]
set r [file dirname $script_dir]
set p [file join $r build gt_test_firefly1_loopback_v4]
if {![info exists archive_name]} {set archive_name firefly1-v4-first-hardware-revision}
set archive [file join $r build diagnostic_archive $archive_name]
if {![info exists prior_hash]} {set prior_hash fe21094d2a204fade6b2eb957c47bbd074c2a6f917ec59a4c34fa5ca3cb1bfc4}
if {![file exists $archive]} {
  if {[lindex [exec sha256sum [file join $p gt_test_firefly1_loopback_v4.bit]] 0] ne $prior_hash} {
    error "unexpected source artifact; refusing to replace evidence"
  }
  file mkdir $archive
  foreach f {gt_test_firefly1_loopback_v4.bit gt_test_firefly1_loopback_v4_routed.dcp} {
    file copy [file join $p $f] $archive
  }
  file copy [file join $r build gt_test_firefly1_loopback_v4_audit] $archive
} elseif {[lindex [exec sha256sum [file join $archive gt_test_firefly1_loopback_v4.bit]] 0] ne $prior_hash} {
  error "unexpected archived artifact"
}
open_project [file join $p gt_test_firefly1_loopback_v4.xpr]
set clocks [file join $r constraints firefly1_reference_clocks.xdc]
if {![llength [get_files -quiet $clocks]]} {add_files -fileset constrs_1 -norecurse $clocks}
set_property STEPS.OPT_DESIGN.TCL.PRE [file join $script_dir apply_firefly1_descriptor_cdc.tcl] [get_runs impl_1]
reset_runs synth_1
if {[info exists clean_synthesis] && $clean_synthesis} {
  set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]
  set_property INCREMENTAL_CHECKPOINT {} [get_runs synth_1]
  launch_runs synth_1 -jobs 8
  wait_on_run synth_1
  if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "clean synthesis failed"}
  open_run synth_1
  set ack [get_cells -hier -filter {NAME =~ *cleanup_wizard_reset_seen_reg}]
  if {[llength $ack] != 3} {error "clean synthesis still lacks reset acknowledgement; do not implement"}
  close_design
}
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "PMA repair implementation failed"}
open_run impl_1
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {error "compression disabled"}
write_checkpoint -force [file join $p gt_test_firefly1_loopback_v4_routed.dcp]
if {![string match {*All user specified timing constraints are met.*} [report_timing_summary -return_string]]} {error "PMA repair timing failed"}
file copy -force [file join [get_property DIRECTORY [get_runs impl_1]] gt_test_firefly1_loopback_v2_top.bit] [file join $p gt_test_firefly1_loopback_v4.bit]
puts "PASS: FireFly-1 v4 PMA continuity/cleanup repair built; independent audit required"
