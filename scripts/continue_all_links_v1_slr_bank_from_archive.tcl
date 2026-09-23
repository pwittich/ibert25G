set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set name gt_test_all_links_v1
set source_archive [file join $repo_dir build diagnostic_archive all-links-v1-slr-bank-attempt]
set placed [file join $source_archive ${name}_slr_bank_placed_failed.dcp]
set expected_sha 2ce015893cfbb15ad62be0bb77d98d71d697c44d517e1910e71dbab58271f439
set preflight [file join $repo_dir build all_links_v1_reports slr_bank_closeout corrected_placed_gate_pass.txt]
set prior_infrastructure_attempt [file join $repo_dir build diagnostic_archive all-links-v1-slr-bank-closeout-continuation]
set archive [file join $repo_dir build diagnostic_archive all-links-v1-slr-bank-closeout-continuation-retry1]
set work [file join $repo_dir build gt_test_all_links_v1_slr_bank_closeout_retry1]
if {![file isfile $placed] || [lindex [split [exec sha256sum $placed]] 0] ne $expected_sha} {error "Immutable placed checkpoint missing or hash mismatch"}
if {![file isfile $preflight]} {error "Corrected read-only placed gate has not passed"}
if {![file isfile [file join $prior_infrastructure_attempt final_status.txt]]} {error "Missing preserved infrastructure-failure record"}
if {[file exists $archive] || [file exists $work]} {error "Closeout retry1 already attempted; refusing another run"}
file mkdir $archive; file mkdir $work
set manifest [open [file join $archive continuation_manifest.txt] w]
puts $manifest "source_dcp=$placed"; puts $manifest "source_sha256=$expected_sha"
puts $manifest "prior_infrastructure_attempt=$prior_infrastructure_attempt (license checkout failed before phys_opt began; preserved unchanged)"
puts $manifest "license_preflight=[file join $repo_dir build all_links_v1_reports slr_bank_closeout license_status.rpt] (server UP, Implementation 10 issued/0 used)"
puts $manifest "flow=one default phys_opt_design then one default route_design; no directives, seeds, constraints, RTL, IP, synthesis, or hardware changes"
close $manifest
foreach f [glob -nocomplain -directory [file dirname $preflight] *] {if {[file isfile $f]} {file copy $f [file join $archive placed_[file tail $f]]}}
open_checkpoint $placed
set ::all_links_slr_report_dir [file join $work reports]
file mkdir $::all_links_slr_report_dir
puts "ALL_LINKS_V1_CLOSEOUT: default phys_opt_design, single permitted continuation"
if {[catch {phys_opt_design} result options]} {
  set status [open [file join $archive final_status.txt] w]; puts $status "FAIL phys_opt_design: $result"; close $status
  return -options $options $result
}
write_checkpoint [file join $archive ${name}_physopt.dcp]
report_timing_summary -delay_type min_max -max_paths 100 -report_unconstrained -file [file join $archive timing_physopt.rpt]
puts "ALL_LINKS_V1_CLOSEOUT: default route_design, single permitted route"
if {[catch {route_design} result options]} {
  catch {write_checkpoint [file join $archive ${name}_route_command_failed.dcp]}
  set status [open [file join $archive final_status.txt] w]; puts $status "FAIL route_design command: $result"; close $status
  return -options $options $result
}
write_checkpoint [file join $archive ${name}_routed_pre_gate.dcp]
if {[catch {source [file join $script_dir verify_all_links_v1_slr_bank_routed_closeout.tcl]} result options]} {
  foreach f [glob -nocomplain -directory $::all_links_slr_report_dir *] {if {[file isfile $f]} {file copy $f [file join $archive [file tail $f]]}}
  set status [open [file join $archive final_status.txt] w]; puts $status "FAIL routed gate: $result"; close $status
  return -options $options $result
}
set routed [file join $work ${name}_routed.dcp]
set bit [file join $work ${name}.bit]
write_checkpoint $routed
write_bitstream $bit
file copy $routed [file join $archive [file tail $routed]]
file copy $bit [file join $archive [file tail $bit]]
foreach f [glob -nocomplain -directory $::all_links_slr_report_dir *] {if {[file isfile $f]} {file copy $f [file join $archive [file tail $f]]}}
set status [open [file join $archive final_status.txt] w]; puts $status "ROUTED_GATE_PASS independent_audit_required"; close $status
puts "PASS: routed gate passed and compressed bit emitted; independent audit required"
