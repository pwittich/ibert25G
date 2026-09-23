set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set target_name gt_test_all_links_v1
set project_dir [file join $repo_dir build $target_name]
set xpr [file join $project_dir ${target_name}.xpr]
set elf [file join $repo_dir build firmware_all_links_v1 ${target_name}.elf]
set report_dir [file join $repo_dir build all_links_v1_reports post_keep_hierarchy_revert]
foreach f [list $xpr $elf] {if {![file isfile $f]} {error "Missing $f"}}
file mkdir $report_dir
open_project $xpr
if {[llength [get_files -quiet [file join $repo_dir constraints all_links_v1_keep_hierarchy.xdc]]]} {
  error "Failed KEEP_HIERARCHY XDC remains active"
}
reset_run impl_1
reset_run synth_1
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]
set_property INCREMENTAL_CHECKPOINT {} [get_runs synth_1]
launch_runs synth_1 -jobs 12
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Clean reverted synthesis failed"}
open_run synth_1
source [file join $script_dir check_all_links_v1_synth.tcl]
set controllers [get_cells -hier -quiet -filter {REF_NAME =~ gt_prbs_test_controller*}]
if {[llength $controllers] != 28} {error "Controller count [llength $controllers], expected 28"}
set kept [get_cells -hier -quiet -filter {
  REF_NAME =~ gt_prbs_test_controller* && KEEP_HIERARCHY == 1}]
set dont [get_cells -hier -quiet -filter {
  REF_NAME =~ gt_prbs_test_controller* && DONT_TOUCH == 1}]
if {[llength $kept] || [llength $dont]} {
  error "Failed property remains: KEEP_HIERARCHY controllers=[llength $kept] DONT_TOUCH controllers=[llength $dont]"
}
set canonical [file join $project_dir ${target_name}_synth.dcp]
write_checkpoint -force $canonical
set out [open [file join $report_dir synth_manifest.txt] w]
puts $out "canonical DCP $canonical"
puts $out "canonical DCP SHA-256 [lindex [split [exec sha256sum $canonical]] 0]"
puts $out "ELF SHA-256 [lindex [split [exec sha256sum $elf]] 0]"
puts $out "fresh nonincremental synthesis after failed KEEP_HIERARCHY experiment reverted"
puts $out "controllers 28 KEEP_HIERARCHY 0 controller-DONT_TOUCH 0"
puts $out "hardware not accessed"
close $out
puts "PASS: fresh reverted all-links v1 synthesis; no KEEP_HIERARCHY or DONT_TOUCH"
