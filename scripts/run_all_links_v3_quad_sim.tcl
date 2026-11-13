set repo [file dirname [file dirname [file normalize [info script]]]]
set work [file join $repo build all_links_v3_quad_sim_[clock microseconds]]
file mkdir $work
cd $work
exec xvlog -sv $repo/src/gt_runtime_integrity_monitor.sv \
  $repo/src/gt_prbs_test_controller.sv $repo/src/managed_quad124_lane_reset_policy.sv \
  $repo/src/all_links_v3_quad_controller.sv $repo/src/managed_all_links_v3_quad_wrapper.sv \
  $repo/sim/all_links_v3_q121_gt_stub.sv $repo/sim/tb_all_links_v3_quad.sv
exec xelab tb_all_links_v3_quad -s v3_quad -mt off
set output [exec xsim v3_quad -runall]
puts $output
if {![string match {*PASS: v3 quad*} $output] || [regexp {Error:|Fatal:} $output]} {
  error "V3 quad simulation failed"
}
