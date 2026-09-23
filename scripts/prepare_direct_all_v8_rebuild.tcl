set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set name gt_test_direct_all_v7r3
set project_dir [file join $repo_dir build $name]
set project [file join $project_dir ${name}.xpr]
set archive [file join $repo_dir build diagnostic_archive \
  direct-all-v7-0x00020404-failed-pma]
if {[file exists $archive]} {error "Refusing existing v7 failure archive $archive"}

set bit [file join $project_dir ${name}.bit]
set routed [file join $project_dir ${name}_routed.dcp]
set synth [file join $project_dir ${name}_synth.dcp]
set elf [file join $repo_dir build firmware_direct_all_v7 gt_test_direct_all_v7.elf]
foreach f [list $project $bit $routed $synth $elf] {
  if {![file isfile $f]} {error "Missing v7 artifact to preserve: $f"}
}
set expected_bit d16d6be685087abcff281319c2def2bba195793ae8c6fd7756bb0dd14c46a75f
set expected_routed ff2fedc90a0791c1f7edc3b53e6aa44c4a355cfe4ea1d4d81e7f17fea3379cc8
set expected_elf fc3d71793950d5ab161b23c842daffbbc08a3dde3e92644047ec919acd77ffb4
foreach {f expected} [list $bit $expected_bit $routed $expected_routed $elf $expected_elf] {
  set actual [lindex [split [exec sha256sum $f]] 0]
  if {$actual ne $expected} {error "Hash mismatch for preserved v7 artifact $f: $actual"}
}

file mkdir $archive
foreach f [list $bit $routed $synth $elf] {file copy $f $archive}
set failure_log [file join $repo_dir build diagnostic_archive \
  all-direct-v7-pma-f1-1789661003467752.log]
if {![file isfile $failure_log]} {error "Missing preserved v7 PMA failure evidence"}
file copy $failure_log $archive

open_project $project
update_compile_order -fileset sources_1
reset_run synth_1
reset_run impl_1
close_project
puts "PASS: preserved failed 0x00020404 artifacts and reset the project for 0x00020405 clean synthesis"
