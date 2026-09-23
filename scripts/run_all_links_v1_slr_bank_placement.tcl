set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set name gt_test_all_links_v1
set project_dir [file join $repo_dir build $name]
set xpr [file join $project_dir ${name}.xpr]
set dcp [file join $project_dir ${name}_synth.dcp]
set elf [file join $repo_dir build firmware_all_links_v1 ${name}.elf]
set report_dir [file join $repo_dir build all_links_v1_reports slr_bank]
set archive [file join $repo_dir build diagnostic_archive all-links-v1-slr-bank-attempt]
foreach f [list $xpr $dcp $elf] {if {![file isfile $f]} {error "Missing $f"}}
if {[file exists $archive]} {error "SLR-bank attempt already exists: $archive"}
file mkdir $archive
file mkdir $report_dir
open_project $xpr
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Fresh synthesis unavailable"}
if {[get_property PROGRESS [get_runs impl_1]] ne "0%"} {error "Implementation is not fresh"}
set expected_hook [file normalize [file join $script_dir apply_all_links_v1_constraints.tcl]]
if {[file normalize [get_property STEPS.OPT_DESIGN.TCL.PRE [get_runs impl_1]]] ne $expected_hook} {error "Wrong constraint hook"}
foreach step {PLACE_DESIGN PHYS_OPT_DESIGN ROUTE_DESIGN WRITE_BITSTREAM} {
  foreach when {PRE POST} {set_property STEPS.${step}.TCL.${when} {} [get_runs impl_1]}
}
set_property STEPS.PHYS_OPT_DESIGN.TCL.PRE [file normalize [file join $script_dir verify_all_links_v1_slr_bank_placed.tcl]] [get_runs impl_1]
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs impl_1]
set_property INCREMENTAL_CHECKPOINT {} [get_runs impl_1]
set manifest [open [file join $archive attempt_manifest.txt] w]
puts $manifest "synth DCP $dcp"
puts $manifest "synth SHA-256 [lindex [split [exec sha256sum $dcp]] 0]"
puts $manifest "ELF SHA-256 [lindex [split [exec sha256sum $elf]] 0]"
puts $manifest "strategy [get_property STRATEGY [get_runs impl_1]]"
foreach prop {STEPS.OPT_DESIGN.ARGS.DIRECTIVE STEPS.PLACE_DESIGN.ARGS.DIRECTIVE STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE} {
  puts $manifest "$prop [get_property $prop [get_runs impl_1]]"
}
puts $manifest "one clean nonincremental implementation, placement gate before phys_opt; no hardware access"
close $manifest
puts "ALL_LINKS_V1_SLR_BANK: launching single implementation through placement"
launch_runs impl_1 -to_step place_design -jobs 12
wait_on_run impl_1
if {[get_property STATUS [get_runs impl_1]] ne "Not started phys_opt_design"} {error "Placement did not complete"}
open_run impl_1
source [file join $script_dir verify_all_links_v1_slr_bank_placed.tcl]
set placed [file join $archive ${name}_slr_bank_placed.dcp]
write_checkpoint -force $placed
file copy -force [file join [get_property DIRECTORY [get_runs impl_1]] runme.log] [file join $archive placement_runme.log]
foreach f [glob -nocomplain -directory $report_dir *placed* placement_gate.rpt] {if {[file isfile $f]} {file copy -force $f [file join $archive [file tail $f]]}}
puts "PASS: placement gate; resume the same implementation to phys_opt/route"
