set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set p [file join $repo_dir build gt_test_firefly1_loopback_v5]
if {[file exists [file join $p gt_test_firefly1_loopback_v5.xpr]]} {
  open_project [file join $p gt_test_firefly1_loopback_v5.xpr]
} else {
  source [file join $script_dir create_firefly1_loopback_v5_project.tcl]
}
# Resume completed synthesis rather than restarting it after an implementation failure.
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
  launch_runs synth_1 -jobs 8
  wait_on_run synth_1
}
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "v5 synthesis failed"}
open_run synth_1
foreach {pattern count} {*tx_session_active_reg 1 *cleanup_wizard_reset_seen_reg 3 *session_meta_reg 3 *session_sync_reg 3} {
  if {[llength [get_cells -hier -filter "NAME =~ $pattern"]] != $count} {error "v5 synthesis structural gate failed: $pattern"}
}
write_checkpoint -force [file join $p gt_test_firefly1_loopback_v5_synth.dcp]
close_design
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "v5 implementation failed"}
open_run impl_1
write_checkpoint -force [file join $p gt_test_firefly1_loopback_v5_routed.dcp]
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {error "compression disabled"}
if {![string match {*All user specified timing constraints are met.*} [report_timing_summary -return_string]]} {error "v5 timing failed"}
file copy -force [file join [get_property DIRECTORY [get_runs impl_1]] gt_test_firefly1_loopback_v2_top.bit] [file join $p gt_test_firefly1_loopback_v5.bit]
report_incremental_reuse -file [file join $p incremental_reuse.rpt]
puts "PASS: v5 compressed bitstream built; independent audit required"
