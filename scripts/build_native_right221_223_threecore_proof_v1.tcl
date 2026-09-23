# Route the isolated three-core q221/q222/q223 proof.  It never changes v15.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set proof_name gt_native_right221_223_threecore_proof_v1
set build_dir [file join $repo_dir build $proof_name]
set ip_dir [file join $repo_dir build gt_native_right221_223_threecore_ip_v3 \
  gt_native_right221_223_threecore_ip.gen sources_1 ip]
source [file join $script_dir derive_native_right221_223_threecore_topology.tcl]

set project_file [file join $build_dir ${proof_name}.xpr]
if {[file exists $build_dir]} {
  if {![file exists $project_file]} {
    # Early proof builds predate the protected proof_name variable and used
    # the last derived core name as the .xpr stem.  Reuse that one project
    # only when it is the sole project in this isolated build directory.
    set prior_projects [glob -nocomplain [file join $build_dir *.xpr]]
    if {[llength $prior_projects] != 1} {
      error "Existing proof directory lacks an unambiguous project: $build_dir"
    }
    set project_file [lindex $prior_projects 0]
  }
  open_project $project_file
} else {
  create_project $proof_name $build_dir -part xcvu13p-flga2577-2-e
  set_property target_language Verilog [current_project]
  set_property simulator_language Mixed [current_project]
  foreach quad {221 222 223} {
  set d [file join $ip_dir native_right${quad}_gt synth]
  foreach f [list native_right${quad}_gt_gtye4_channel_wrapper.v \
                  native_right${quad}_gt_gtye4_common_wrapper.v \
                  native_right${quad}_gt_gtwizard_gtye4.v \
                  native_right${quad}_gt_gtwizard_top.v \
                  native_right${quad}_gt_topology.v] {
    add_files -norecurse [file join $d $f]
  }
  add_files -fileset constrs_1 -norecurse [file join $d native_right${quad}_gt.xdc]
  }
# Common vendor primitive models are identical for all three Wizard instances.
set common_dir [file join $ip_dir native_right221_gt synth]
foreach f {gtwizard_ultrascale_v1_7_gtye4_channel.v gtwizard_ultrascale_v1_7_gtye4_common.v} {
  add_files -norecurse [file join $common_dir $f]
}
foreach f [glob -nocomplain [file join $ip_dir native_right221_gt hdl *.v]] {
  add_files -norecurse $f
}
  add_files -norecurse [file join $repo_dir src gt_native_right221_223_threecore_proof_v1_top.sv]
  add_files -fileset constrs_1 -norecurse [file join $repo_dir constraints gt_native_right221_223_proof_v1.xdc]
  set_property top gt_native_right221_223_threecore_proof_v1_top [current_fileset]
}
set impl_status [get_property STATUS [get_runs impl_1]]
if {$impl_status ne "write_bitstream Complete!"} {
  # This isolated proof is resumable after an interrupted batch client.  A
  # stale "running" marker is not a live hardware or production build.
  if {$impl_status ne "Not started"} { reset_run impl_1 }
  if {[get_property NEEDS_REFRESH [get_runs synth_1]]} { reset_run synth_1 }
  launch_runs impl_1 -to_step write_bitstream -jobs 4
}
wait_on_run impl_1
if {[get_property STATUS [get_runs impl_1]] ne "write_bitstream Complete!"} {
  error "Three-core proof implementation failed: [get_property STATUS [get_runs impl_1]]"
}
set run_dir [get_property DIRECTORY [get_runs impl_1]]
set dcp [file join $run_dir gt_native_right221_223_threecore_proof_v1_top_routed.dcp]
file copy -force $dcp [file join $build_dir ${proof_name}_routed.dcp]
file copy -force [file join $run_dir gt_native_right221_223_threecore_proof_v1_top.bit] [file join $build_dir ${proof_name}.bit]
open_checkpoint $dcp
report_timing_summary -file [file join $build_dir timing_summary.rpt]
report_drc -file [file join $build_dir drc.rpt]
close_design
puts "Completed $proof_name"
