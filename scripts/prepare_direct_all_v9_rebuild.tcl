set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set name gt_test_direct_all_v7r3
set project_dir [file join $repo_dir build $name]
set project [file join $project_dir ${name}.xpr]
set reference [file join $repo_dir build diagnostic_archive \
  direct-all-v8-0x00020405-hardware-failure gt_test_direct_all_v7r3_routed.dcp]

foreach f [list $project $reference] {
  if {![file isfile $f]} {error "Missing v9 rebuild input $f"}
}

open_project $project
update_compile_order -fileset sources_1
reset_run synth_1
reset_run impl_1
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs impl_1]
set_property INCREMENTAL_CHECKPOINT $reference [get_runs impl_1]
close_project
puts "PASS: prepared 0x00020406 synthesis and incremental implementation from the audited v8 route"
