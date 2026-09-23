set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set name gt_test_direct_all_v7r3
set project_dir [file join $repo_dir build $name]
set project [file join $project_dir ${name}.xpr]
set reference [file join $project_dir ${name}_routed.dcp]
set bit [file join $project_dir ${name}.bit]
set synth [file join $project_dir ${name}_synth.dcp]
set firmware_dir [file join $repo_dir build firmware_direct_all_v7]
set elf [file join $firmware_dir gt_test_direct_all_v7.elf]
set archive [file join $repo_dir build diagnostic_archive \
  direct-all-v11-0x00020408-post-capture-aggregate-timeout]

if {[file exists $archive]} {error "Refusing existing v11 archive $archive"}
foreach f [list $project $reference $bit $synth $elf] {
  if {![file isfile $f]} {error "Missing v11 artifact $f"}
}
foreach {f expected} [list \
  $bit d0432ec4999b8c08e6515a8493e71f1a2fb0effd5d5f548799aee7f45c17afde \
  $reference ed5d9884cf019ca9cae57efb20f18a5be231a04d0ffb44276082e70fabe19429 \
  $elf 35f310112418d5dfb309c5fe6696e8bb6762a45939f3d6cedbfa66802619f05f] {
  set actual [lindex [split [exec sha256sum $f]] 0]
  if {$actual ne $expected} {error "V11 artifact hash mismatch $f: $actual"}
}

file mkdir $archive
foreach f [list $bit $reference $synth] {file copy $f $archive}
file copy -force $firmware_dir [file join $archive firmware_direct_all_v7]
foreach evidence [glob -nocomplain [file join $repo_dir build diagnostic_archive \
    all-direct-v11-*.log]] {
  file copy $evidence $archive
}
foreach evidence [glob -nocomplain [file join $repo_dir build diagnostic_archive \
    firefly1-v11-*-program-*.log]] {
  file copy $evidence $archive
}
file delete -force $firmware_dir

open_project $project
update_compile_order -fileset sources_1
reset_run synth_1
reset_run impl_1
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs impl_1]
set_property INCREMENTAL_CHECKPOINT [file join $archive ${name}_routed.dcp] \
  [get_runs impl_1]
close_project
puts "PASS: preserved v11 artifacts/evidence and prepared 0x00020409 incremental rebuild"
