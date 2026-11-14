set script_dir [file dirname [file normalize [info script]]]
set repo [file dirname $script_dir]
set reference [file join $repo build gt_test_all_links_v3 gt_test_all_links_v3.xpr]
set project_name gt_test_eye_scan_v1
set project_dir [file join $repo build $project_name]
set elf [file join $repo build firmware_eye_scan_v1 gt_test_eye_scan_v1.elf]
set wrappers [lsort [glob -nocomplain [file join $repo build eye_scan_v1_topology_wrappers *.v]]]
if {![string match "2023.2*" [version -short]]} {error "Requires Vivado 2023.2"}
if {![file isfile $reference] || ![file isfile $elf] || [llength $wrappers] != 28} {
  error "Missing v3 reference, matching eye ELF or 28 derived topology wrappers"
}
if {[file exists $project_dir]} {error "Refusing existing $project_dir"}
exec sha256sum -c [file join $repo build eye_scan_v1_topology_wrappers SOURCE_SHA256SUMS]
exec sha256sum -c [file join $repo build eye_scan_v1_topology_wrappers SHA256SUMS]
open_project $reference
if {[get_property PART [current_project]] ne "xcvu13p-flga2577-2-e"} {error "Part mismatch"}
save_project_as -include_local_ip_cache $project_name $project_dir
close_project
open_project [file join $project_dir ${project_name}.xpr]
foreach f [get_files -all -quiet *.elf] {if {![get_property IS_GENERATED $f]} {remove_files $f}}
foreach f [get_files -all -quiet *_v3_topology.v] {if {![get_property IS_GENERATED $f]} {remove_files $f}}
add_files -norecurse $wrappers
foreach module {gt_test_eye_scan_v1_top eye_scan_v1_core eye_scan_v1_slr_bank
  managed_eye_scan_v1_quad_wrapper axi_lite_eye_scan_v1_engine eye_scan_v1_engine_core
  eye_scan_controller eye_scan_point eye_scan_drp_arbiter
  eye_scan_v1_result_copy_bank eye_scan_v1_quad_aggregate} {
  add_files -norecurse [file join $repo src ${module}.sv]
}
foreach f [get_files -of_objects [get_filesets constrs_1]] {
  set scope [get_property SCOPED_TO_REF $f]
  if {[string match *_v3_topology $scope]} {
    set_property SCOPED_TO_REF [string map {_v3_topology _eye_v1_topology} $scope] $f
  }
}
add_files -norecurse $elf
set_property SCOPED_TO_REF gt_test_milestone3_bd [get_files $elf]
set_property SCOPED_TO_CELLS microblaze_0 [get_files $elf]
set_property top gt_test_eye_scan_v1_top [get_filesets sources_1]
set_property generic {HARDWARE_VERSION=32'h00020503} [get_filesets sources_1]
set_property STEPS.OPT_DESIGN.TCL.PRE [file join $script_dir apply_eye_scan_v1_constraints.tcl] [get_runs impl_1]
set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs impl_1]
foreach run {synth_1 impl_1} {
  set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs $run]
  set_property INCREMENTAL_CHECKPOINT {} [get_runs $run]
}
reset_run impl_1
reset_run synth_1
foreach ip [get_ips] {if {[get_property IS_LOCKED $ip]} {error "Locked IP $ip"}}
report_ip_status -file [file join $project_dir initial_ip_status.rpt]
update_compile_order -fileset sources_1
close_project
puts "PASS: independent unbuilt eye-scan v1/0x00020503 project created with matching ELF"
