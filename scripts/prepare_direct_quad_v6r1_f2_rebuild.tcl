set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set name gt_test_direct_quad_v6_f2
set project_dir [file join $repo_dir build $name]
set archive [file join $repo_dir build diagnostic_archive direct-v6-f2-00020402-pma-lane105-failure-20260917T035300Z gt_test_direct_quad_v6_f2_routed.dcp]
set elf [file join $repo_dir build firmware_direct_quad_v6_f2 ${name}.elf]
foreach file [list $archive $elf] {if {![file isfile $file]} {error "Missing $file"}}
open_project [file join $project_dir ${name}.xpr]
if {[get_property TOP [get_filesets sources_1]] ne "${name}_top"} {error "Wrong endpoint top"}
set associated [get_files -all -quiet *.elf -filter {SCOPED_TO_CELLS != ""}]
if {[llength $associated] != 1 || [file normalize [lindex $associated 0]] ne [file normalize $elf]} {
  error "Unexpected F2 ELF association: $associated"
}
update_compile_order -fileset sources_1
reset_run synth_1
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs impl_1]
set_property INCREMENTAL_CHECKPOINT $archive [get_runs impl_1]
set_property STEPS.OPT_DESIGN.TCL.PRE [file join $script_dir apply_direct_quad_v6_descriptor_cdc.tcl] [get_runs impl_1]
puts "PASS: prepared F2 0x00020403 rebuild with preserved failed route as incremental reference"
