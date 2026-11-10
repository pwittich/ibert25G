set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set project_dir [file join $repo_dir build gt_test_all_links_v2_timing_hardened]
set dcp [file join $project_dir gt_test_all_links_v2_timing_hardened_control_boundary_fix_routed.dcp]
set audit_dir [file join $repo_dir build all_links_v2_timing_hardened_control_boundary_fix_independent_audit]
set marker [file join $audit_dir AUDIT_PASS]
set bit [file join $project_dir gt_test_all_links_v2_timing_hardened_control_boundary_fix.bit]
set bin [file rootname $bit].bin
set expected_dcp_sha 323ff58252ae66a81e42c84d38b528ce053561804cdc7eeecb99d3066107993a

foreach f [list $dcp $marker] {if {![file isfile $f]} {error "Missing $f"}}
if {[file exists $bit]} {error "Refusing existing bitstream $bit"}
if {[file exists $bin]} {error "Refusing existing binary configuration $bin"}
set actual_sha [lindex [exec sha256sum $dcp] 0]
if {$actual_sha ne $expected_dcp_sha} {error "Audited DCP hash mismatch: $actual_sha"}
set marker_text [read [set fh [open $marker r]]]
close $fh
if {![string match "*candidate=[file normalize $dcp]*" $marker_text]} {
  error "Audit marker does not name the exact candidate"
}
open_checkpoint $dcp
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {
  error "Compression disabled"
}
write_bitstream -bin_file $bit
if {![file isfile $bin] || [file size $bin] == 0} {error "Missing or empty binary configuration $bin"}
set bit_sha [lindex [exec sha256sum $bit] 0]
puts "BIT_SHA256=$bit_sha"
puts "BIN_SHA256=[lindex [exec sha256sum $bin] 0]"
puts "PASS: wrote and hashed compressed BIT and BIN from exact independently audited all-links-v2 DCP; no hardware release"
