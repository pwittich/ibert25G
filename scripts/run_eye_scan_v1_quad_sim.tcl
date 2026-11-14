set repo [file dirname [file dirname [file normalize [info script]]]]
set work [file join $repo build eye_scan_v1_quad_sim_[clock microseconds]]
file mkdir $work
cd $work
exec xvlog -sv $repo/src/gt_runtime_integrity_monitor.sv \
  $repo/src/gt_prbs_test_controller.sv $repo/src/managed_quad124_lane_reset_policy.sv \
  $repo/src/all_links_v3_quad_controller.sv $repo/src/eye_scan_drp_arbiter.sv \
  $repo/src/eye_scan_point.sv $repo/src/managed_eye_scan_v1_quad_wrapper.sv \
  $repo/sim/eye_scan_gt_model.sv $repo/sim/eye_scan_v1_q121_gt_stub.sv $repo/sim/tb_eye_scan_v1_quad.sv
exec xelab tb_eye_scan_v1_quad -s eye_quad -mt off
set output [exec xsim eye_quad -runall]
puts $output
if {![string match {*PASS: eye v1 quad*} $output] || [regexp {Error:|Fatal:} $output]} {
  error "Eye quad integration failed"
}
