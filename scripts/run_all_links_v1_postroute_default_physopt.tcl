set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set source_dcp [file join $repo_dir build diagnostic_archive all-links-v1-slr-bank-closeout-continuation-retry1 gt_test_all_links_v1_routed_pre_gate.dcp]
set source_sha 4631ff396e6b18baf61a312c6beaa7d77b00f6ba267830c40367a163a222a974
set preflight [file join $repo_dir build all_links_v1_reports postroute_default_physopt_preflight preflight_manifest.txt]
set preflight_dir [file dirname $preflight]
set archive [file join $repo_dir build diagnostic_archive all-links-v1-postroute-default-physopt-attempt]
set work [file join $repo_dir build gt_test_all_links_v1_postroute_default_physopt]
if {![file isfile $preflight] || [string first "PASS" [read [set fh [open $preflight r]]] ] != 0} {catch {close $fh}; error "Exact preflight has not passed"}
close $fh
if {[lindex [split [exec sha256sum $source_dcp]] 0] ne $source_sha} {error "Input DCP hash changed"}
if {[file exists $archive] || [file exists $work]} {error "Exclusive post-route attempt already exists"}
file mkdir $archive
file mkdir $work
foreach f [glob -nocomplain -directory $preflight_dir *] {if {[file isfile $f]} {file copy $f [file join $archive preflight_[file tail $f]]}}
set status_file [file join $archive final_status.txt]
set manifest [open [file join $archive attempt_manifest.txt] w]
puts $manifest "input_dcp=$source_dcp"
puts $manifest "input_sha256=$source_sha"
puts $manifest "command=phys_opt_design"
puts $manifest "prohibited=-post_route, route_design, directives, retry, source/constraint/IP/synthesis/seed/strategy changes"
close $manifest
open_checkpoint $source_dcp
puts "ALL_LINKS_V1_POSTROUTE: invoking the sole permitted operation: phys_opt_design"
if {[catch {phys_opt_design} result options]} {
  set s [open $status_file w]; puts $s "FAIL phys_opt_design command: $result"; puts $s "bitstream=not_generated audit=not_run hardware=not_touched"; close $s
  return -options $options $result
}
set output_dcp [file join $archive gt_test_all_links_v1_postroute_default_physopt.dcp]
write_checkpoint $output_dcp
set output_sha [lindex [split [exec sha256sum $output_dcp]] 0]
set hash_out [open [file join $archive output_sha256.txt] w]; puts $hash_out "$output_sha  $output_dcp"; close $hash_out
set ::all_links_slr_report_dir [file join $work strict_gate]
file mkdir $::all_links_slr_report_dir
set outcome PASS
if {[catch {source [file join $script_dir verify_all_links_v1_slr_bank_routed_closeout.tcl]} result]} {set outcome "FAIL strict routed gate: $result"}
if {$outcome eq "PASS" && [catch {source [file join $script_dir verify_all_links_v1_postroute_inventory.tcl]} result]} {set outcome "FAIL strict inventory gate: $result"}
foreach f [glob -nocomplain -directory $::all_links_slr_report_dir *] {if {[file isfile $f]} {file copy $f [file join $archive [file tail $f]]}}
set s [open $status_file w]
puts $s $outcome
puts $s "input_sha256=$source_sha"
puts $s "output_sha256=$output_sha"
if {$outcome eq "PASS"} {puts $s "independent_audit=required bitstream=not_yet_generated"} else {puts $s "independent_audit=not_run bitstream=not_generated"}
puts $s "hardware=not_touched"
close $s
if {$outcome ne "PASS"} {error $outcome}
puts "PASS: sole post-route phys_opt operation meets strict routed gate; independent audit required"
