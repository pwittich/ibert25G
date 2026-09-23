set repo [file dirname [file dirname [file normalize [info script]]]]
set work [file join $repo build firefly1_reset_fanout_sim]
file mkdir $work
cd $work
exec xvlog -sv $repo/sim/tb_firefly1_reset_fanout.sv $repo/src/managed_firefly1_group_wrapper.sv
exec xelab tb_firefly1_reset_fanout -s fanout_sim -mt off
after 2000
set output [exec xsim fanout_sim -R]
puts $output
if {[regexp {Fatal:|Error:|ERROR:} $output] || ![string match {*PASS: v5 broadcasts each quad reset*} $output]} {
    error "reset fanout simulation failed"
}
