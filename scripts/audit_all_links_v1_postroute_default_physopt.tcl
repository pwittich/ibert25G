set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set archive [file join $repo_dir build diagnostic_archive all-links-v1-postroute-default-physopt-attempt]
set ::all_links_audit_candidate [file join $archive gt_test_all_links_v1_postroute_default_physopt.dcp]
set ::all_links_audit_report_dir [file join $archive independent_audit]
if {![file isfile [file join $archive final_status.txt]] || [string first "PASS" [read [set fh [open [file join $archive final_status.txt] r]]]] != 0} {catch {close $fh}; error "Strict gate did not pass"}
close $fh
source [file join $script_dir audit_all_links_v1_routed.tcl]
set out [open [file join $archive independent_audit_pass.txt] w]; puts $out "PASS candidate=$::all_links_audit_candidate"; close $out
