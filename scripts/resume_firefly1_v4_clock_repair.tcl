set script_dir [file dirname [file normalize [info script]]]
set r [file dirname $script_dir]
set project_dir [file join $r build gt_test_firefly1_loopback_v4]
set archive [file join $r build diagnostic_archive firefly1-v4-before-clock-repair]
if {![file exists $archive]} {
  file mkdir $archive
  file copy [file join $project_dir gt_test_firefly1_loopback_v4.bit] $archive
  file copy [file join $project_dir gt_test_firefly1_loopback_v4.runs impl_1 gt_test_firefly1_loopback_v2_top_routed.dcp] $archive
} elseif {[lindex [exec sha256sum [file join $archive gt_test_firefly1_loopback_v4.bit]] 0] ne "727d63005cc97c45c87833749f48b6b9a9b87b333b2c362bad09c5a78b141ee5"} {
  error "unexpected archived artifact; refusing to overwrite evidence"
}
open_project [file join $project_dir gt_test_firefly1_loopback_v4.xpr]
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "synthesis incomplete"}
open_run synth_1
read_xdc [file join $r constraints firefly1_reference_clocks.xdc]
source [file join $script_dir apply_firefly1_descriptor_cdc.tcl]
opt_design
place_design
phys_opt_design
route_design
set reports [file join $r build gt_test_firefly1_loopback_v4_repaired_reports]
file mkdir $reports
report_timing_summary -file [file join $reports timing.rpt]
report_route_status -file [file join $reports routing.rpt]
report_methodology -file [file join $reports methodology.rpt]
report_bus_skew -file [file join $reports bus_skew.rpt]
write_checkpoint -force [file join $project_dir gt_test_firefly1_loopback_v4_routed.dcp]
if {![string match {*All user specified timing constraints are met.*} [report_timing_summary -return_string]]} {error "repaired timing failed"}
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
write_bitstream -force [file join $project_dir gt_test_firefly1_loopback_v4.bit]
puts "PASS: FireFly-1 v4 clock-repaired compressed bitstream"
