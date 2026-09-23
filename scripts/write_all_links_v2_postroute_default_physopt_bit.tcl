set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set archive [file join $repo_dir build diagnostic_archive \
  all-links-v2-postroute-default-physopt-attempt]
set dcp [file join $archive gt_test_all_links_v2_postroute_default_physopt.dcp]
set audit [file join $archive independent_audit_pass.txt]
set elf [file join $repo_dir build firmware_all_links_v2 gt_test_all_links_v2.elf]
set bit [file join $archive gt_test_all_links_v2_postroute_default_physopt.bit]
foreach f [list $dcp $audit $elf] {if {![file isfile $f]} {error "Missing $f"}}
if {[file exists $bit]} {error "Bitstream already exists"}
open_checkpoint $dcp
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {
  error "Compression disabled"
}
write_bitstream $bit
set out [open [file join $archive release_sha256.txt] {WRONLY CREAT EXCL}]
foreach f [list $dcp $bit $elf] {puts $out "[lindex [split [exec sha256sum $f]] 0]  $f"}
close $out
puts "PASS: wrote compressed all-links-v2 build candidate; no hardware release"
