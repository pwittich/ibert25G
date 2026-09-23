set repo [file dirname [file dirname [file normalize [info script]]]]
set work [file join $repo build firefly1_v5_session_sim]
file mkdir $work
cd $work
exec xvlog -sv $repo/src/gt_lane_engine.sv $repo/src/gt_test_engine_core.sv $repo/sim/tb_dual_endpoint_window.sv
foreach mode {0 1} {
    exec xelab tb_dual_endpoint_window -generic_top SESSIONS=$mode -s session_$mode -mt off
    after 2000
    set output [exec xsim session_$mode -R]
    puts $output
    if {[regexp {Fatal:|Error:|ERROR:} $output] || ![string match {*PASS:*} $output]} {
        error "session simulation failed mode=$mode"
    }
}
