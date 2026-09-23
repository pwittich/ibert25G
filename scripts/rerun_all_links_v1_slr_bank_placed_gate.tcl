set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set dcp [file join $repo_dir build diagnostic_archive all-links-v1-slr-bank-attempt gt_test_all_links_v1_slr_bank_placed_failed.dcp]
set expected_sha 2ce015893cfbb15ad62be0bb77d98d71d697c44d517e1910e71dbab58271f439
if {![file isfile $dcp]} {error "Missing immutable placed DCP: $dcp"}
set actual_sha [lindex [split [exec sha256sum $dcp]] 0]
if {$actual_sha ne $expected_sha} {error "Placed DCP SHA mismatch: $actual_sha"}
set ::all_links_slr_report_dir [file join $repo_dir build all_links_v1_reports slr_bank_closeout]
open_checkpoint $dcp
if {[get_property PART [current_design]] ne "xcvu13p-flga2577-2-e"} {error "Wrong part"}
source [file join $script_dir verify_all_links_v1_slr_bank_placed_closeout.tcl]
set marker [open [file join $::all_links_slr_report_dir corrected_placed_gate_pass.txt] w]
puts $marker "placed_dcp=$dcp"; puts $marker "sha256=$actual_sha"; puts $marker "status=PASS"; puts $marker "no_design_change=true"
close $marker
