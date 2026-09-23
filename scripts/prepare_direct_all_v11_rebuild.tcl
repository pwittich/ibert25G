set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set name gt_test_direct_all_v7r3
set project [file join $repo_dir build $name ${name}.xpr]
set reference [file join $repo_dir build diagnostic_archive \
  direct-all-v10-0x00020407-q231-capture-done-failure \
  gt_test_direct_all_v7r3_routed.dcp]

foreach f [list $project $reference] {
  if {![file isfile $f]} {error "Missing v11 rebuild input $f"}
}

open_project $project
update_compile_order -fileset sources_1
reset_run synth_1
reset_run impl_1
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs impl_1]
set_property INCREMENTAL_CHECKPOINT $reference [get_runs impl_1]
close_project
puts "PASS: prepared 0x00020408 synthesis and incremental implementation from the audited v10 route"
