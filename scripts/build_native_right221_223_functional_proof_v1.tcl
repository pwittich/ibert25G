# Isolated functional companion to the routed q221-223 topology proof.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set proof_name gt_native_right221_223_functional_proof_v1
set proof_dir [file join $repo_dir build $proof_name]
set ip_project [file join $repo_dir build gt_native_right221_223 gt_native_right221_223.xpr]
set ip_synth_dir [file join $repo_dir build gt_native_right221_223 \
  gt_native_right221_223.gen sources_1 ip native_right221_223_gt synth]
if {![file exists $ip_project]} { error "Missing isolated q221-223 Wizard project" }
open_project $ip_project
generate_target all [get_ips native_right221_223_gt]
source [file join $script_dir derive_native_right221_223_topology_wrapper.tcl]
close_project

set project_file [file join $proof_dir ${proof_name}.xpr]
if {[file exists $proof_dir]} {
  if {![file exists $project_file]} { error "Refusing foreign proof directory: $proof_dir" }
  open_project $project_file
} else {
  create_project $proof_name $proof_dir -part xcvu13p-flga2577-2-e
  set_property target_language Verilog [current_project]
  foreach file {
    gtwizard_ultrascale_v1_7_gtye4_channel.v
    gtwizard_ultrascale_v1_7_gtye4_common.v
    native_right221_223_gt_gtye4_channel_wrapper.v
    native_right221_223_gt_gtye4_common_wrapper.v
    native_right221_223_gt_gtwizard_gtye4.v
    native_right221_223_gt_gtwizard_top.v
    native_right221_223_gt_topology.v
  } { add_files -norecurse [file join $ip_synth_dir $file] }
  foreach helper [glob -nocomplain [file join $repo_dir build gt_native_right221_223 \
    gt_native_right221_223.gen sources_1 ip native_right221_223_gt hdl *.v]] {
    add_files -norecurse $helper
  }
  add_files -norecurse [file join $repo_dir src gt_native_active_quad_contract.sv]
  add_files -norecurse [file join $repo_dir src gt_native_active_quad_platform.sv]
  add_files -norecurse [file join $repo_dir src gt_native_right221_223_functional_proof_v1_top.sv]
  add_files -fileset constrs_1 -norecurse [file join $ip_synth_dir native_right221_223_gt.xdc]
  add_files -fileset constrs_1 -norecurse [file join $repo_dir constraints gt_native_right221_223_functional_proof_v1.xdc]
  set_property top gt_native_right221_223_functional_proof_v1_top [current_fileset]
}
if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {
  reset_run synth_1
  launch_runs synth_1 -jobs 4
  wait_on_run synth_1
}
if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {
  error "Functional proof synthesis failed"
}
if {[get_property STATUS [get_runs impl_1]] ne "write_bitstream Complete!"} {
  reset_run impl_1
  launch_runs impl_1 -to_step write_bitstream -jobs 4
  wait_on_run impl_1
}
if {[get_property STATUS [get_runs impl_1]] ne "write_bitstream Complete!"} {
  error "Functional proof implementation failed"
}
set impl_dir [get_property DIRECTORY [get_runs impl_1]]
set top gt_native_right221_223_functional_proof_v1_top
file copy -force [file join $impl_dir ${top}_routed.dcp] [file join $proof_dir ${proof_name}_routed.dcp]
file copy -force [file join $impl_dir ${top}.bit] [file join $proof_dir ${proof_name}.bit]
open_checkpoint [file join $impl_dir ${top}_routed.dcp]
report_timing_summary -file [file join $proof_dir timing_summary.rpt]
report_drc -file [file join $proof_dir drc.rpt]
close_design
puts "Completed isolated native functional proof: $proof_dir"
