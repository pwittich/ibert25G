# Fully isolated q221-223 native dedicated-refclk proof target.
# This target has no firmware identity because it deliberately contains no MCU
# or MicroBlaze.  Its bitstream name/project/report directories are unique.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set proof_name gt_native_right221_223_proof_v1
set proof_dir [file join $repo_dir build $proof_name]
set ip_project [file join $repo_dir build gt_native_right221_223 gt_native_right221_223.xpr]
set ip_synth_dir [file join $repo_dir build gt_native_right221_223 \
  gt_native_right221_223.gen sources_1 ip native_right221_223_gt synth]

if {![file exists $ip_project]} {
  error "Create the isolated native q221-223 IP project first: $ip_project"
}
open_project $ip_project
set native_gt [get_ips -quiet native_right221_223_gt]
if {[llength $native_gt] != 1} { error "Expected exactly one native q221-223 Wizard IP" }
generate_target all $native_gt
source [file join $script_dir derive_native_right221_223_topology_wrapper.tcl]
close_project

set proof_project [file join $proof_dir ${proof_name}.xpr]
if {[file exists $proof_dir]} {
  # Resume only this exact new proof after a failed tool invocation.  Never
  # overwrite a foreign or historical build directory.
  if {![file exists $proof_project]} {
    error "Existing proof directory lacks expected project: $proof_project"
  }
  open_project $proof_project
} else {
  create_project $proof_name $proof_dir -part xcvu13p-flga2577-2-e
  set_property target_language Verilog [current_project]
  set_property simulator_language Mixed [current_project]

  foreach filename {
    gtwizard_ultrascale_v1_7_gtye4_channel.v
    gtwizard_ultrascale_v1_7_gtye4_common.v
    native_right221_223_gt_gtye4_channel_wrapper.v
    native_right221_223_gt_gtye4_common_wrapper.v
    native_right221_223_gt_gtwizard_gtye4.v
    native_right221_223_gt_gtwizard_top.v
    native_right221_223_gt_topology.v
  } {
    add_files -norecurse [file join $ip_synth_dir $filename]
  }
  add_files -norecurse [file join $repo_dir src gt_native_right221_223_proof_v1_top.sv]
  add_files -fileset constrs_1 -norecurse [file join $ip_synth_dir native_right221_223_gt.xdc]
  add_files -fileset constrs_1 -norecurse [file join $repo_dir constraints gt_native_right221_223_proof_v1.xdc]
  set_property top gt_native_right221_223_proof_v1_top [current_fileset]
}

# The standalone Wizard top references generated reset/calibration helpers in
# hdl/. Add them idempotently when resuming this proof after an early failure.
foreach helper [glob -nocomplain [file join $repo_dir build gt_native_right221_223 \
  gt_native_right221_223.gen sources_1 ip native_right221_223_gt hdl *.v]] {
  if {[llength [get_files -quiet $helper]] == 0} {
    add_files -norecurse $helper
  }
}
set synth_status [get_property STATUS [get_runs synth_1]]
set synth_stale [get_property NEEDS_REFRESH [get_runs synth_1]]
if {[string match "*error*" [string tolower $synth_status]] || $synth_stale} {
  # The only resumable failure expected here is an interrupted/license-denied
  # run in this proof directory, or a stale run after proof-source revision.
  # This never touches a hardware target.
  reset_run synth_1
  set synth_status ""
}
if {$synth_status ne "synth_design Complete!"} {
  launch_runs synth_1 -jobs 4
  wait_on_run synth_1
}
if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {
  error "Native q221-223 proof synthesis did not complete: [get_property STATUS [get_runs synth_1]]"
}
set impl_status [get_property STATUS [get_runs impl_1]]
if {$impl_status ne "write_bitstream Complete!"} {
  # This proof's first implementation was made stale only by adding the
  # generated Wizard support HDL after its initial elaboration failure.
  reset_run impl_1
  launch_runs impl_1 -to_step write_bitstream -jobs 4
  wait_on_run impl_1
}
if {[get_property STATUS [get_runs impl_1]] ne "write_bitstream Complete!"} {
  error "Native q221-223 proof implementation did not complete: [get_property STATUS [get_runs impl_1]]"
}
set impl_dir [get_property DIRECTORY [get_runs impl_1]]
set top_name gt_native_right221_223_proof_v1_top
set routed_dcp [file join $impl_dir ${top_name}_routed.dcp]
set bitstream [file join $impl_dir ${top_name}.bit]
file copy -force $routed_dcp [file join $proof_dir ${proof_name}_routed.dcp]
file copy -force $bitstream [file join $proof_dir ${proof_name}.bit]
open_checkpoint $routed_dcp
report_timing_summary -file [file join $proof_dir timing_summary.rpt]
report_drc -file [file join $proof_dir drc.rpt]
close_design
puts "Completed isolated native q221-223 proof: $proof_dir"
