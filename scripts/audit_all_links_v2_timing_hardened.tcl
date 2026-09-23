set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set ::all_links_audit_candidate [file join $repo_dir build \
  gt_test_all_links_v2_timing_hardened gt_test_all_links_v2_timing_hardened_control_boundary_fix_routed.dcp]
set ::all_links_audit_report_dir [file join $repo_dir build \
  all_links_v2_timing_hardened_control_boundary_fix_independent_audit]
set ::all_links_audit_participation 1
set ::all_links_audit_v2_hardening 1
source [file join $script_dir audit_all_links_v1_routed.tcl]
set marker [file join $::all_links_audit_report_dir AUDIT_PASS]
if {[file exists $marker]} {error "Refusing existing audit marker $marker"}
set fh [open $marker {WRONLY CREAT EXCL}]
puts $fh "candidate=[file normalize $::all_links_audit_candidate]"
puts $fh "identity=0x00020501"
puts $fh "hardening=four-bank-copy,per-quad-reset,4x64-snapshot"
close $fh
