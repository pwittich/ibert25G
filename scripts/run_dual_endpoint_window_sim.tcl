set repo [file dirname [file dirname [file normalize [info script]]]]
set work [file join $repo build dual_endpoint_window_sim]
file mkdir $work
cd $work
exec xvlog -sv $repo/src/gt_lane_engine.sv $repo/src/gt_test_engine_core.sv $repo/sim/tb_dual_endpoint_window.sv
exec xelab tb_dual_endpoint_window -s dual_endpoint_window -mt off
set output [exec xsim dual_endpoint_window -runall]
puts $output
if {[regexp {Fatal:|Error:|ERROR:} $output] || ![string match {*PASS: v4 dual-endpoint stop race reproduced*} $output]} {
    error "Dual endpoint window reproduction failed"
}
