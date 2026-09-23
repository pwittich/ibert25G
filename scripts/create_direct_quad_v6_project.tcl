set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
source [file join $script_dir direct_quad_v6_project_utils.tcl]
if {![info exists endpoint] || $endpoint ni {1 2}} {error "endpoint must be 1 or 2"}
if {![string match "2023.2*" [version -short]]} {error "Requires Vivado 2023.2"}
set name gt_test_direct_quad_v6_f${endpoint}
set dest [file join $repo_dir build $name]
set elf [file join $repo_dir build firmware_direct_quad_v6_f${endpoint} ${name}.elf]
set quad [expr {$endpoint == 1 ? 222 : 233}]
set xci [file join $repo_dir build direct_quad_v6_ip direct_quad_v6_ip.srcs sources_1 ip direct_v6_q${quad}_gt direct_v6_q${quad}_gt.xci]
foreach f [list $elf $xci] {if {![file isfile $f]} {error "Missing $f"}}
if {[file exists $dest]} {error "Refusing to overwrite $dest; use build resume"}
# Preserve completed supervisor BD/IP runs, not the incompatible GT layout.
open_project [file join $repo_dir build gt_test_firefly1_loopback_v5 gt_test_firefly1_loopback_v5.xpr]
if {[get_property PART [current_project]] ne "xcvu13p-flga2577-2-e"} {error "Reference part mismatch"}
save_project_as -include_local_ip_cache $name $dest
if {[file normalize [get_property DIRECTORY [current_project]]] ne [file normalize $dest]} {error "Save As failed"}
set bd [file join $dest ${name}.srcs sources_1 bd gt_test_milestone3_bd gt_test_milestone3_bd.bd]
close_project
if {![direct_v6_strip_inherited_elf $bd]} {error "Inherited v5 ELF association was not present in cloned BD"}
open_project [file join $dest ${name}.xpr]
# Vivado 2023.2.2 can segfault when removing an IP fileset after save_project_as.
# Keep the uninstantiated legacy source/IP records in the cloned project and
# disable only its application constraints.  The selected top cannot elaborate
# those GTs; the routed audit proves exactly four channels and one common.
foreach f [get_files -of_objects [get_filesets constrs_1]] {
  if {[file tail $f] in {board_pins.xdc sysmon.xdc clock_monitor_pins.xdc clock_monitor_cdc.xdc gt_test_milestone3.xdc firefly1_reference_clocks.xdc} ||
      [string match *native_left* $f] || [string match *managed_quad124_gt* $f]} {
    set_property IS_ENABLED false $f
  }
}
foreach f [get_files -all -quiet *.elf] {
  if {[string match gt_test_firefly1*.elf [file tail $f]]} {remove_files $f}
}
foreach f {
  clock_input_buffers.sv clock_frequency_monitor.sv i2c_register_slave.sv sysmon_i2c_ssi.sv
  gt_lane_engine.sv gt_transition_trace.sv gt_rx_error_profile.sv gt_test_engine_core.sv
  axi_lite_gt_test_engine.sv gt_quad_controller.sv gt_runtime_integrity_monitor.sv
  gt_prbs_test_controller.sv managed_quad124_lane_reset_policy.sv
  managed_direct_quad_v6_wrapper.sv direct_quad_v6_refclk_buffers.sv gt_test_direct_quad_v6_core.sv
} {add_files -norecurse [file join $repo_dir src $f]}
add_files -norecurse [file join $repo_dir src ${name}_top.sv]
import_ip -files $xci
generate_target all [get_ips direct_v6_q${quad}_gt]
foreach f {sysmon.xdc clock_monitor_pins.xdc clock_monitor_cdc.xdc gt_test_milestone3.xdc} {
  add_files -fileset constrs_1 -norecurse [file join $repo_dir constraints $f]
  set_property IS_ENABLED true [get_files [file join $repo_dir constraints $f]]
}
add_files -fileset constrs_1 -norecurse [file join $repo_dir constraints direct_quad_v6_f${endpoint}_clocks.xdc]
set_property IS_ENABLED true [get_files [file join $repo_dir constraints direct_quad_v6_f${endpoint}_clocks.xdc]]
add_files -fileset constrs_1 -norecurse [file join $repo_dir constraints direct_quad_v6_f${endpoint}_board.xdc]
set_property IS_ENABLED true [get_files [file join $repo_dir constraints direct_quad_v6_f${endpoint}_board.xdc]]
add_files -norecurse $elf
set_property SCOPED_TO_REF gt_test_milestone3_bd [get_files [file tail $elf]]
set_property SCOPED_TO_CELLS microblaze_0 [get_files [file tail $elf]]
save_project
direct_v6_assert_single_bd_elf $bd f${endpoint}
set_property top ${name}_top [get_filesets sources_1]
set_property generic {} [get_filesets sources_1]
reset_run synth_1
foreach run {synth_1 impl_1} {
  set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs $run]
  set_property INCREMENTAL_CHECKPOINT {} [get_runs $run]
}
set_property STEPS.OPT_DESIGN.TCL.PRE [file join $script_dir apply_direct_quad_v6_descriptor_cdc.tcl] [get_runs impl_1]
foreach run [get_runs] {
  if {[string first "[file normalize $dest]/" "[file normalize [get_property DIRECTORY $run]]/"] != 0} {error "Run points outside new project: $run"}
}
update_compile_order -fileset sources_1
report_ip_status -file [file join $dest initial_ip_status.rpt]
puts "Created isolated direct v6 F$endpoint; clean application synthesis required"
