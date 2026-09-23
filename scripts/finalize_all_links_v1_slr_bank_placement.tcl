set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set name gt_test_all_links_v1
set project_dir [file join $repo_dir build $name]
set xpr [file join $project_dir ${name}.xpr]
set report_dir [file join $repo_dir build all_links_v1_reports slr_bank]
set archive [file join $repo_dir build diagnostic_archive all-links-v1-slr-bank-attempt]
open_project $xpr
if {[get_property STATUS [get_runs impl_1]] ne "Not started phys_opt_design"} {
  error "Existing implementation is not a completed placed run: [get_property STATUS [get_runs impl_1]]"
}
set run_dir [get_property DIRECTORY [get_runs impl_1]]
set run_placed [file join $run_dir ${name}_top_placed.dcp]
if {![file isfile $run_placed]} {error "Missing placed run checkpoint $run_placed"}
close_project
open_checkpoint $run_placed
source [file join $script_dir verify_all_links_v1_slr_bank_placed.tcl]
set placed [file join $archive ${name}_slr_bank_placed.dcp]
write_checkpoint -force $placed
file copy -force [file join $run_dir runme.log] [file join $archive placement_runme.log]
foreach f [glob -nocomplain -directory $report_dir *placed* placement_gate.rpt] {if {[file isfile $f]} {file copy -force $f [file join $archive [file tail $f]]}}
puts "PASS: existing single placement passed gate; same run may continue to phys_opt/route"
