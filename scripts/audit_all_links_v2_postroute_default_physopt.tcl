set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set archive [file join $repo_dir build diagnostic_archive \
  all-links-v2-postroute-default-physopt-attempt]
set status [file join $archive final_status.txt]
if {![file isfile $status]} {error "Strict gate status missing"}
set fh [open $status r]; set status_text [read $fh]; close $fh
if {[string first "PASS\n" $status_text] != 0} {error "Strict gate did not pass"}
set ::all_links_audit_candidate [file join $archive \
  gt_test_all_links_v2_postroute_default_physopt.dcp]
set ::all_links_audit_report_dir [file join $archive independent_audit]
set ::all_links_audit_participation 1
if {[file exists [file join $archive independent_audit_pass.txt]] ||
    [file exists $::all_links_audit_report_dir]} {error "Independent audit already exists"}
source [file join $script_dir audit_all_links_v1_routed.tcl]
set out [open [file join $archive independent_audit_pass.txt] {WRONLY CREAT EXCL}]
puts $out "PASS candidate=$::all_links_audit_candidate identity=0x00020501 participation=enabled"
close $out
