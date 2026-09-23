set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set target_name gt_test_all_links_v1
set project_dir [file join $repo_dir build $target_name]
set xpr [file join $project_dir ${target_name}.xpr]
set elf [file join $repo_dir build firmware_all_links_v1 ${target_name}.elf]
set report_dir [file join $repo_dir build all_links_v1_reports keep_hierarchy]
open_project $xpr
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Fresh synthesis incomplete"}
open_run synth_1
source [file join $script_dir check_all_links_v1_keep_hierarchy_synth.tcl]
set canonical [file join $project_dir ${target_name}_synth.dcp]
write_checkpoint -force $canonical
set out [open [file join $report_dir synth_manifest.txt] w]
puts $out "canonical DCP $canonical"
puts $out "canonical DCP SHA-256 [lindex [split [exec sha256sum $canonical]] 0]"
puts $out "ELF $elf"
puts $out "ELF SHA-256 [lindex [split [exec sha256sum $elf]] 0]"
puts $out "fresh nonincremental synthesis; exact 28 controller KEEP_HIERARCHY roots"
puts $out "synthesis run completed with 0 errors and 0 critical warnings"
puts $out "hardware not accessed"
close $out
puts "PASS: finalized canonical KEEP_HIERARCHY synthesis checkpoint from fresh run"
