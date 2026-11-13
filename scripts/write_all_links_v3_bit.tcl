set repo [file dirname [file dirname [file normalize [info script]]]]
foreach manifest {SOURCE_SHA256SUMS IMPLEMENTATION_SHA256SUMS} {
  set path [file join $repo build all_links_v3_reports $manifest]
  if {![file isfile $path]} {error "Missing frozen build inputs: $path"}
  exec sha256sum -c $path
}

set project_dir [file join $repo build gt_test_all_links_v3]
set dcp [file join $project_dir gt_test_all_links_v3_routed.dcp]
set elf [file join $repo build firmware_all_links_v3 gt_test_all_links_v3.elf]
set marker [file join $repo build all_links_v3_audit AUDIT_PASS]
set bit [file join $project_dir gt_test_all_links_v3.bit]
set bin [file rootname $bit].bin
foreach f [list $dcp $elf $marker] {if {![file isfile $f]} {error "Missing $f"}}
foreach f [list $bit $bin] {if {[file exists $f]} {error "Refusing existing $f"}}
set f [open $marker r]; set audit [read $f]; close $f
set dcp_sha [lindex [exec sha256sum $dcp] 0]
if {![string match "*identity=0x00020502*" $audit] ||
    ![string match "*sha256=$dcp_sha*" $audit]} {error "V3 audit identity/hash mismatch"}
open_checkpoint $dcp
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {
  error "Compression disabled"
}
write_bitstream -bin_file $bit
if {![file isfile $bin] || [file size $bin] == 0} {error "Missing/empty BIN"}
set f [open [file join $project_dir SHA256SUMS] {WRONLY CREAT EXCL}]
foreach file [list $bit $bin $dcp $elf] {
  set hash [lindex [exec sha256sum $file] 0]
  puts $f "$hash  $file"
  puts "ARTIFACT_SHA256=$hash FILE=$file"
}
close $f
puts "PASS: audited compressed v3 BIT/BIN emitted; hardware release remains closed"
