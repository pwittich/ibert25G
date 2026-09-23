set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set archive [file join $repo_dir build diagnostic_archive all-links-v1-slr-bank-closeout-continuation-retry1]
set routed [file join $archive gt_test_all_links_v1_routed_pre_gate.dcp]
if {![file isfile $routed]} {error "Missing routed evidence DCP: $routed"}
set ::all_links_slr_report_dir [file join $repo_dir build gt_test_all_links_v1_slr_bank_closeout_retry1 reports_final]
open_checkpoint $routed
set outcome PASS
if {[catch {source [file join $script_dir verify_all_links_v1_slr_bank_routed_closeout.tcl]} result]} {
  set outcome "FAIL: $result"
}
foreach f [glob -nocomplain -directory $::all_links_slr_report_dir *] {
  if {[file isfile $f]} {file copy -force $f [file join $archive [file tail $f]]}
}
set status [open [file join $archive final_status.txt] w]
puts $status $outcome
puts $status "implementation=one default phys_opt_design and one default route_design from immutable placed SHA 2ce015893cfbb15ad62be0bb77d98d71d697c44d517e1910e71dbab58271f439"
puts $status "bitstream=not_generated independent_audit=not_run hardware=not_touched"
close $status
puts $outcome
