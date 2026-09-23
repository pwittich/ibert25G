set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set target_name gt_test_all_links_v1
set project_dir [file join $repo_dir build $target_name]
set xpr [file join $project_dir ${target_name}.xpr]
set elf [file join $repo_dir build firmware_all_links_v1 ${target_name}.elf]
set report_dir [file join $repo_dir build all_links_v1_reports keep_hierarchy]
foreach f [list $xpr $elf] {if {![file isfile $f]} {error "Missing $f"}}
file mkdir $report_dir
open_project $xpr
if {[get_property TOP [get_filesets sources_1]] ne "gt_test_all_links_v1_top"} {error "Wrong top"}
if {[get_property PART [current_project]] ne "xcvu13p-flga2577-2-e"} {error "Wrong part"}
set xdc [file normalize [file join $repo_dir constraints all_links_v1_keep_hierarchy.xdc]]
set xdc_file [get_files -quiet $xdc]
if {[llength $xdc_file] != 1 || ![get_property USED_IN_SYNTHESIS $xdc_file] ||
    [get_property USED_IN_IMPLEMENTATION $xdc_file]} {
  error "Synthesis-only KEEP_HIERARCHY XDC association is not exact: $xdc_file"
}
set external_elfs {}
foreach f [get_files -all -quiet *.elf] {if {![get_property IS_GENERATED $f]} {lappend external_elfs $f}}
if {[llength $external_elfs] != 1 ||
    [file normalize [lindex $external_elfs 0]] ne [file normalize $elf]} {
  error "ELF association is not exact: $external_elfs"
}
reset_run impl_1
reset_run synth_1
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]
set_property INCREMENTAL_CHECKPOINT {} [get_runs synth_1]
launch_runs synth_1 -jobs 12
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
  error "Fresh all-links KEEP_HIERARCHY synthesis failed"
}
open_run synth_1
source [file join $script_dir check_all_links_v1_keep_hierarchy_synth.tcl]
report_utilization -file [file join $report_dir utilization_synth.rpt]
report_cdc -details -file [file join $report_dir cdc_synth.rpt]
report_methodology -file [file join $report_dir methodology_synth.rpt]
set canonical [file join $project_dir ${target_name}_synth.dcp]
write_checkpoint -force $canonical
set out [open [file join $report_dir synth_manifest.txt] w]
puts $out "canonical DCP $canonical"
puts $out "canonical DCP SHA-256 [lindex [split [exec sha256sum $canonical]] 0]"
puts $out "ELF $elf"
puts $out "ELF SHA-256 [lindex [split [exec sha256sum $elf]] 0]"
puts $out "fresh nonincremental synthesis; exact 28 controller KEEP_HIERARCHY roots"
puts $out "hardware not accessed"
close $out
puts "PASS: fresh all-links v1 KEEP_HIERARCHY synthesis and structural preflight"
