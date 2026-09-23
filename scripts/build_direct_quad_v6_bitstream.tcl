set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
if {![info exists endpoint] || $endpoint ni {1 2}} {error "endpoint must be 1 or 2"}
set name gt_test_direct_quad_v6_f${endpoint}
set project_dir [file join $repo_dir build $name]
if {[file exists [file join $project_dir ${name}.xpr]]} {
  open_project [file join $project_dir ${name}.xpr]
} else {source [file join $script_dir create_direct_quad_v6_project.tcl]}
if {[get_property TOP [get_filesets sources_1]] ne "${name}_top"} {error "Wrong endpoint top"}
foreach f [get_files -of_objects [get_filesets constrs_1]] {
  if {[file tail $f] eq "board_pins.xdc" || [string match *native_left* $f] ||
      [string match *managed_quad124_gt* $f]} {set_property IS_ENABLED false $f}
}
foreach f [get_files -all -quiet *.elf] {
  if {[string match gt_test_firefly1*.elf [file tail $f]]} {remove_files $f}
}
set endpoint_elf [file join $repo_dir build firmware_direct_quad_v6_f${endpoint} ${name}.elf]
set associated_elfs [get_files -all -quiet *.elf -filter {SCOPED_TO_CELLS != ""}]
if {[llength $associated_elfs] != 1 || [file normalize [lindex $associated_elfs 0]] ne [file normalize $endpoint_elf]} {
  error "Expected exactly the endpoint v6 ELF association, got $associated_elfs"
}
foreach f {sysmon.xdc clock_monitor_pins.xdc clock_monitor_cdc.xdc gt_test_milestone3.xdc} {
  set target [get_files -quiet [file join $repo_dir constraints $f]]
  if {[llength $target] != 1} {error "Missing required constraint $f"}
  set_property IS_ENABLED true $target
}
set target [get_files -quiet [file join $repo_dir constraints direct_quad_v6_f${endpoint}_clocks.xdc]]
if {[llength $target] != 1} {error "Missing endpoint clock constraints"}
set_property IS_ENABLED true $target
set board [file join $repo_dir constraints direct_quad_v6_f${endpoint}_board.xdc]
set target [get_files -quiet $board]
if {![llength $target]} {add_files -fileset constrs_1 -norecurse $board; set target [get_files $board]}
set_property IS_ENABLED true $target
if {[get_property NEEDS_REFRESH [get_runs synth_1]] && [get_property PROGRESS [get_runs synth_1]] eq "100%"} {
  error "Sources changed after synthesis; preserve artifacts and explicitly review a new synthesis"
}
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
  launch_runs synth_1 -jobs 8
  wait_on_run synth_1
}
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Synthesis failed"}
open_run synth_1
if {[llength [get_cells -hier -filter {REF_NAME == GTYE4_CHANNEL && IS_PRIMITIVE}]] != 4} {error "Expected exactly four GT channels"}
write_checkpoint -force [file join $project_dir ${name}_synth.dcp]
close_design
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
  launch_runs impl_1 -to_step write_bitstream -jobs 8
  wait_on_run impl_1
}
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Implementation failed; checkpoints retained"}
open_run impl_1
write_checkpoint -force [file join $project_dir ${name}_routed.dcp]
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {error "Compression disabled"}
if {![string match {*All user specified timing constraints are met.*} [report_timing_summary -return_string]]} {error "Timing failed"}
set bit [file join [get_property DIRECTORY [get_runs impl_1]] ${name}_top.bit]
file copy -force $bit [file join $project_dir ${name}.bit]
puts "PASS: v6 F$endpoint compressed build; independent audit still required"
