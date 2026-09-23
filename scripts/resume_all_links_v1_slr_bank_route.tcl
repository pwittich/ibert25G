set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set name gt_test_all_links_v1
set project_dir [file join $repo_dir build $name]
set xpr [file join $project_dir ${name}.xpr]
set report_dir [file join $repo_dir build all_links_v1_reports slr_bank]
set archive [file join $repo_dir build diagnostic_archive all-links-v1-slr-bank-attempt]
set placed [file join $archive ${name}_slr_bank_placed.dcp]
foreach f [list $xpr $placed] {if {![file isfile $f]} {error "Placement gate evidence missing: $f"}}
open_project $xpr
if {[get_property STATUS [get_runs impl_1]] ne "Not started phys_opt_design"} {
  error "Implementation is not stopped after placement: [get_property STATUS [get_runs impl_1]]"
}
set hook [file normalize [get_property STEPS.PHYS_OPT_DESIGN.TCL.PRE [get_runs impl_1]]]
if {$hook ne [file normalize [file join $script_dir verify_all_links_v1_slr_bank_placed.tcl]]} {error "Placement gate hook missing"}
puts "ALL_LINKS_V1_SLR_BANK: placement passed; continuing same implementation through route exactly once"
launch_runs impl_1 -to_step route_design -jobs 12
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Route did not complete"}
open_run impl_1
source [file join $script_dir verify_all_links_v1_slr_bank_routed.tcl]
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {error "Compression disabled"}
set routed [file join $project_dir ${name}_routed.dcp]
set bit [file join $project_dir ${name}.bit]
write_checkpoint -force $routed
write_bitstream -force $bit
foreach f [list $routed $bit] {file copy -force $f [file join $archive [file tail $f]]}
file copy -force [file join [get_property DIRECTORY [get_runs impl_1]] runme.log] [file join $archive routed_runme.log]
foreach f [glob -nocomplain -directory $report_dir *routed*] {if {[file isfile $f]} {file copy -force $f [file join $archive [file tail $f]]}}
puts "PASS: compressed candidate emitted; independent routed audit required"
