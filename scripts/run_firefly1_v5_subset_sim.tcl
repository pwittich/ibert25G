set repo [file dirname [file dirname [file normalize [info script]]]]
set work [file join $repo build firefly1_v5_subset_sim]
file mkdir $work
cd $work
exec xvlog -sv $repo/src/gt_lane_engine.sv $repo/src/gt_test_engine_core.sv \
    $repo/src/gt_quad_controller.sv $repo/src/gt_prbs_test_controller.sv \
    $repo/src/gt_runtime_integrity_monitor.sv $repo/src/managed_quad124_lane_reset_policy.sv \
    $repo/sim/tb_firefly1_v5_subset.sv $env(XILINX_VIVADO)/data/verilog/src/glbl.v
exec xelab tb_firefly1_v5_subset glbl -s firefly1_v5_subset -mt off -L xpm
after 2000
set output [exec xsim firefly1_v5_subset -R]
puts $output
if {[regexp {Fatal:|Error:|ERROR:} $output] || ![string match {*PASS: v5 three-quad subset suite*} $output]} {
    error "v5 three-quad subset simulation failed"
}
