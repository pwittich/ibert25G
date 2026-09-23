set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set name gt_test_direct_all_v7r3
set project_dir [file join $repo_dir build $name]
set project_file [file join $project_dir ${name}.xpr]
set elf [file join $repo_dir build firmware_direct_all_v7 gt_test_direct_all_v7.elf]
set report_dir [file join $repo_dir build direct_all_v7_reports]

if {![file isfile $project_file]} {error "Missing reviewed v7 project $project_file"}
if {![file isfile $elf]} {error "Missing v7 firmware $elf"}
file mkdir $report_dir
open_project $project_file
if {[get_property TOP [get_filesets sources_1]] ne "gt_test_direct_all_v7_top"} {error "Wrong v7 top"}
set external_elfs {}
foreach f [get_files -all -quiet *.elf] {
  if {![get_property IS_GENERATED $f]} {lappend external_elfs $f}
}
if {[llength $external_elfs] != 1 ||
    [file normalize [lindex $external_elfs 0]] ne [file normalize $elf] ||
    [get_property SCOPED_TO_REF [lindex $external_elfs 0]] ne "gt_test_milestone3_bd" ||
    [get_property SCOPED_TO_CELLS [lindex $external_elfs 0]] ne "microblaze_0"} {
  error "V7 ELF association is not exact: $external_elfs"
}
report_ip_status -file [file join $report_dir ip_status_prebuild.rpt]
foreach ip [get_ips -quiet] {
  if {[get_property IS_LOCKED $ip]} {error "Locked IP before build: $ip"}
}

# update_direct_all_v7_project_sources.tcl performed the reviewed clean reset.
# Refuse ambiguous partial synthesis, while allowing an explicit resume after
# the clean synthesis checkpoint has completed.
set synth_progress [get_property PROGRESS [get_runs synth_1]]
if {$synth_progress ni {"0%" "100%"}} {
  error "Refusing partial synthesis state $synth_progress; preserve it and review before retry"
}
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]
set_property INCREMENTAL_CHECKPOINT {} [get_runs synth_1]
if {$synth_progress eq "0%"} {
  puts "DIRECT_ALL_V7_BUILD: launching clean synthesis"
  launch_runs synth_1 -jobs 12
  wait_on_run synth_1
}
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "V7 synthesis failed"}

open_run synth_1
set firefly_ports [get_ports -quiet -filter {NAME =~ *_ff*}]
if {[llength $firefly_ports] != 0} {
  error "All-direct top still exposes legacy FireFly ports: $firefly_ports"
}
set channels [get_cells -hier -filter {REF_NAME == GTYE4_CHANNEL && IS_PRIMITIVE}]
set commons [get_cells -hier -filter {REF_NAME == GTYE4_COMMON && IS_PRIMITIVE}]
if {[llength $channels] != 56} {error "Expected exactly 56 synthesized GT channels, got [llength $channels]"}
if {[llength $commons] != 14} {error "Expected exactly 14 synthesized GT commons, got [llength $commons]"}
set channel_sites {}
foreach c $channels {lappend channel_sites [get_property LOC $c]}
set common_sites {}
foreach c $commons {lappend common_sites [get_property LOC $c]}
set expected_channels {}
for {set y 4} {$y <= 59} {incr y} {lappend expected_channels GTYE4_CHANNEL_X1Y$y}
if {[lsort $channel_sites] ne [lsort $expected_channels]} {error "Synthesized channel sites differ: $channel_sites"}
foreach {label pattern expected} {
  engines {*g_lane*.g_managed.u_lane} 56
  quad_controllers {*g_quad*.u_managed_direct/u_quad_controller} 14
  session_applied_ack {*g_quad*.u_managed_direct/session_applied_sync_reg} 14
  aggregate {*u_quad_aggregate} 1
} {
  set found [get_cells -hier -quiet -filter "NAME =~ $pattern"]
  if {[llength $found] != $expected} {error "$label structural count [llength $found], expected $expected"}
}
report_utilization -file [file join $report_dir utilization_synth.rpt]
report_cdc -details -file [file join $report_dir cdc_synth.rpt]
report_methodology -file [file join $report_dir methodology_synth.rpt]
write_checkpoint -force [file join $project_dir ${name}_synth.dcp]
close_design

# V12 replaces the stale Wizard aggregate qualification after capture with
# selected per-lane RXRESETDONE/RXPMARESETDONE.  Reuse the exact audited v11
# route; this is a one-condition controller change.
set incremental_reference [file join $repo_dir build diagnostic_archive \
  direct-all-v11-0x00020408-post-capture-aggregate-timeout gt_test_direct_all_v7r3_routed.dcp]
if {![file isfile $incremental_reference]} {error "Missing audited v11 incremental reference"}
set_property INCREMENTAL_CHECKPOINT $incremental_reference [get_runs impl_1]
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs impl_1]
set impl_progress [get_property PROGRESS [get_runs impl_1]]
if {$impl_progress ni {"0%" "100%"}} {
  error "Refusing partial implementation state $impl_progress; checkpoints retained for review"
}
if {$impl_progress eq "0%"} {
  puts "DIRECT_ALL_V7_BUILD: launching v12 incremental implementation from audited v11 route"
  launch_runs impl_1 -to_step write_bitstream -jobs 12
  wait_on_run impl_1
}
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "V7 implementation failed; run artifacts retained"}

open_run impl_1
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {
  error "V7 bitstream compression is disabled"
}
set routed_channels [get_cells -hier -filter {REF_NAME == GTYE4_CHANNEL && IS_PRIMITIVE}]
set routed_commons [get_cells -hier -filter {REF_NAME == GTYE4_COMMON && IS_PRIMITIVE}]
set routed_channel_sites {}
foreach c $routed_channels {lappend routed_channel_sites [get_property LOC $c]}
set routed_common_sites {}
foreach c $routed_commons {lappend routed_common_sites [get_property LOC $c]}
set expected_commons {}
for {set y 1} {$y <= 14} {incr y} {lappend expected_commons GTYE4_COMMON_X1Y$y}
if {[lsort $routed_channel_sites] ne [lsort $expected_channels]} {error "Routed channel sites differ: $routed_channel_sites"}
if {[lsort $routed_common_sites] ne [lsort $expected_commons]} {error "Routed common sites differ: $routed_common_sites"}
write_checkpoint -force [file join $project_dir ${name}_routed.dcp]
set timing_text [report_timing_summary -return_string -file [file join $report_dir timing_summary_routed.rpt]]
report_route_status -file [file join $report_dir route_status.rpt]
report_drc -file [file join $report_dir drc_routed.rpt]
report_incremental_reuse -file [file join $report_dir incremental_reuse.rpt]
if {![string match {*All user specified timing constraints are met.*} $timing_text]} {error "V7 timing failed"}
set run_dir [get_property DIRECTORY [get_runs impl_1]]
set generated_bit [file join $run_dir gt_test_direct_all_v7_top.bit]
if {![file isfile $generated_bit]} {error "Missing generated bitstream $generated_bit"}
file copy -force $generated_bit [file join $project_dir ${name}.bit]
puts "PASS: all-direct v12 per-lane post-capture requalification compressed implementation built; independent audit required"
