set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
source [file join $script_dir direct_quad_v6_project_utils.tcl]
source [file join $script_dir direct_all_v7_generated_support_manifest.tcl]
if {![string match "2023.2*" [version -short]]} {error "Requires Vivado 2023.2"}
set project_name_override gt_test_direct_all_v7r3
set top gt_test_direct_all_v7_top
set project_dir [file join $repo_dir build $project_name_override]
set elf [file join $repo_dir build firmware_direct_all_v7 gt_test_direct_all_v7.elf]
set ipdir [file join $repo_dir build direct_all_v7_ip direct_all_v7_ip.srcs sources_1 ip]
if {![file isfile $elf]} {error "Missing $elf"}
set xcis {}
foreach quad {221 222 223 224 225 226 227 228 229 230 231 232 233 234} {
  set xci [file join $ipdir direct_all_v7_q${quad}_gt direct_all_v7_q${quad}_gt.xci]
  if {![file isfile $xci]} {error "Missing $xci"}
  lappend xcis $xci
}
if {[file exists $project_dir]} {error "Refusing to overwrite $project_dir"}
open_project [file join $repo_dir build gt_test_firefly1_loopback_v5 gt_test_firefly1_loopback_v5.xpr]
if {[get_property PART [current_project]] ne "xcvu13p-flga2577-2-e"} {error "Reference part mismatch"}
if {$project_name_override eq "" || $project_dir eq ""} {error "Empty project clone destination"}
puts "V7_PROJECT_CLONE name=$project_name_override directory=$project_dir"
save_project_as -include_local_ip_cache $project_name_override $project_dir
set bd [file join $project_dir ${project_name_override}.srcs sources_1 bd gt_test_milestone3_bd gt_test_milestone3_bd.bd]
close_project
open_project [file join $project_dir ${project_name_override}.xpr]
foreach f [get_files -of_objects [get_filesets constrs_1]] {set_property IS_ENABLED false $f}
set inherited [get_files -all -quiet *firmware_firefly1_loopback_v5/gt_test_firefly1_loopback_v5.elf]
if {[llength $inherited] != 1} {error "Expected one inherited external v5 ELF, got $inherited"}
remove_files $inherited
set legacy_generated {}
foreach f [get_files -all -quiet] {
  if {[string first "/gt_native_left121_123_functional_ip_v1/" [file normalize $f]] >= 0} {
    lappend legacy_generated $f
  }
}
if {![llength $legacy_generated]} {error "Expected inherited FireFly generated support sources"}
remove_files $legacy_generated
foreach f {
  clock_input_buffers.sv clock_frequency_monitor.sv i2c_register_slave.sv sysmon_i2c_ssi.sv
  gt_lane_engine.sv gt_transition_trace.sv gt_rx_error_profile.sv gt_test_engine_core.sv
  axi_lite_gt_test_engine.sv gt_quad_controller.sv gt_runtime_integrity_monitor.sv
  gt_prbs_test_controller.sv managed_quad124_lane_reset_policy.sv
  managed_direct_quad_v6_wrapper.sv direct_quad_v6_refclk_buffers.sv direct_all_v7_quad_aggregate.sv
  gt_test_direct_quad_v6_core.sv gt_test_direct_all_v7_top.sv
} {add_files -norecurse [file join $repo_dir src $f]}
foreach xci $xcis {import_ip -files $xci}
generate_target all [get_ips direct_all_v7_q*_gt]
set topology_dir [file join $repo_dir build direct_all_v7_topology_wrappers]
set topology_wrappers [glob -nocomplain [file join $topology_dir *_topology.v]]
if {[llength $topology_wrappers] != 14} {
  error "Expected fourteen derived topology wrappers in $topology_dir"
}
add_files -norecurse $topology_wrappers
add_files -norecurse [direct_all_v7_support_manifest $repo_dir]
foreach {quad xdc} [direct_all_v7_outer_xdc_manifest $repo_dir] {
  add_files -fileset constrs_1 -norecurse $xdc
  set xf [get_files $xdc]
  set_property SCOPED_TO_REF direct_all_v7_q${quad}_gt_topology $xf
  set_property PROCESSING_ORDER EARLY $xf
}
set inherited_board [get_files -quiet [file join $repo_dir constraints board_pins.xdc]]
if {[llength $inherited_board] == 1} {set_property IS_ENABLED false $inherited_board}
foreach f {sysmon.xdc clock_monitor_pins.xdc clock_monitor_cdc.xdc gt_test_milestone3.xdc direct_quad_v6_f1_clocks.xdc} {
  set path [file join $repo_dir constraints $f]
  add_files -fileset constrs_1 -norecurse $path
  set_property IS_ENABLED true [get_files $path]
}
add_files -norecurse $elf
set elf_files {}
foreach f [get_files -all -quiet *.elf] {
  if {![get_property IS_GENERATED $f]} {lappend elf_files $f}
}
if {[llength $elf_files] != 1 || [file normalize [lindex $elf_files 0]] ne [file normalize $elf]} {
  error "Expected one exact non-generated v7 ELF, got $elf_files"
}
set_property SCOPED_TO_REF gt_test_milestone3_bd $elf_files
set_property SCOPED_TO_CELLS microblaze_0 $elf_files
direct_v7_assert_single_bd_elf $bd
set_property top $top [get_filesets sources_1]
set_property generic {} [get_filesets sources_1]
foreach run {synth_1 impl_1} {
  reset_run $run
  set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs $run]
  set_property INCREMENTAL_CHECKPOINT {} [get_runs $run]
}
set_property STEPS.OPT_DESIGN.TCL.PRE [file join $script_dir apply_direct_all_v7_constraints.tcl] [get_runs impl_1]
update_compile_order -fileset sources_1
report_ip_status -file [file join $project_dir initial_ip_status.rpt]
close_project
open_project [file join $project_dir ${project_name_override}.xpr]
set reopened_elfs {}
foreach f [get_files -all -quiet *.elf] {
  if {![get_property IS_GENERATED $f]} {lappend reopened_elfs $f}
}
if {[llength $reopened_elfs] != 1 || [file normalize [lindex $reopened_elfs 0]] ne [file normalize $elf]} {
  error "Reopened project does not contain exactly the v7 external ELF: $reopened_elfs"
}
if {[get_property SCOPED_TO_REF [lindex $reopened_elfs 0]] ne "gt_test_milestone3_bd" ||
    [get_property SCOPED_TO_CELLS [lindex $reopened_elfs 0]] ne "microblaze_0"} {
  error "Reopened v7 ELF has incorrect BD/cell association"
}
if {[get_property top [get_filesets sources_1]] ne $top} {error "Reopened top mismatch"}
direct_v7_assert_single_bd_elf $bd
report_ip_status -file [file join $project_dir reopened_ip_status.rpt]
puts "PASS: created symmetric all-direct v7 project; clean synthesis required"
