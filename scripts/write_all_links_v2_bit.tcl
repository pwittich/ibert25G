set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set project_dir [file join $repo_dir build gt_test_all_links_v2]
set dcp [file join $project_dir gt_test_all_links_v2_routed.dcp]
set marker [file join $repo_dir build all_links_v2_audit AUDIT_PASS]
set bit [file join $project_dir gt_test_all_links_v2.bit]
foreach f [list $dcp $marker] {if {![file isfile $f]} {error "Missing $f"}}
if {[file exists $bit]} {error "Refusing existing bitstream $bit"}
open_checkpoint $dcp
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {
  error "Compression disabled"
}
write_bitstream $bit
puts "PASS: wrote audited compressed all-links v2 bitstream $bit"
