set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
source [file join $script_dir derive_native_left121_123_functional_topology.tcl]
set build_dir [file join $repo_dir build gt_native_left121_123_functional_elab]
if {[file exists $build_dir]} { file delete -force $build_dir }
create_project gt_native_left121_123_functional_elab $build_dir -part xcvu13p-flga2577-2-e -force
set ip_dir [file join $repo_dir build gt_native_left121_123_functional_ip_v1 gt_native_left121_123_functional_ip.gen sources_1 ip]
foreach quad {121 122 123} {
  set d [file join $ip_dir native_left${quad}_functional_gt synth]
  foreach f [list native_left${quad}_functional_gt_gtye4_channel_wrapper.v native_left${quad}_functional_gt_gtye4_common_wrapper.v native_left${quad}_functional_gt_gtwizard_gtye4.v native_left${quad}_functional_gt_gtwizard_top.v native_left${quad}_functional_gt_topology.v] { add_files -norecurse [file join $d $f] }
}
set d [file join $ip_dir native_left121_functional_gt synth]
foreach f {gtwizard_ultrascale_v1_7_gtye4_channel.v gtwizard_ultrascale_v1_7_gtye4_common.v} { add_files -norecurse [file join $d $f] }
foreach f [glob -nocomplain [file join $ip_dir native_left121_functional_gt hdl *.v]] { add_files -norecurse $f }
foreach f {gt_quad_controller.sv gt_runtime_integrity_monitor.sv gt_prbs_test_controller.sv managed_quad124_lane_reset_policy.sv managed_native_left_quad_wrapper.sv managed_firefly1_group_wrapper.sv gt_native_left121_123_functional_elab_top.sv} { add_files -norecurse [file join $repo_dir src $f] }
set_property top gt_native_left121_123_functional_elab_top [current_fileset]
set_property source_mgmt_mode None [current_project]
synth_design -top gt_native_left121_123_functional_elab_top -part xcvu13p-flga2577-2-e
puts "PASS: functional FireFly-1 group elaborates"
