set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set archive [file join $repo_dir build diagnostic_archive all-links-v1-postroute-default-physopt-attempt]
set dcp [file join $archive gt_test_all_links_v1_postroute_default_physopt.dcp]
set audit [file join $archive independent_audit_pass.txt]
set bit [file join $archive gt_test_all_links_v1_postroute_default_physopt.bit]
if {![file isfile $audit] || [file exists $bit]} {error "Audit absent or bit already exists"}
open_checkpoint $dcp
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {error "Compression disabled"}
write_bitstream $bit
set out [open [file join $archive release_sha256.txt] w]
foreach f [list $dcp $bit [file join $repo_dir build firmware_all_links_v1 gt_test_all_links_v1.elf]] {puts $out "[lindex [split [exec sha256sum $f]] 0]  $f"}
close $out
puts "PASS: compressed bitstream written from independently audited DCP"
