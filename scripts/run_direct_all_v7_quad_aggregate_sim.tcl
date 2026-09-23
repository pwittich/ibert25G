set repo [file dirname [file dirname [file normalize [info script]]]]
set work [file join $repo build direct_all_v7_quad_aggregate_sim]
file mkdir $work
cd $work
exec xvlog -sv $repo/src/direct_all_v7_quad_aggregate.sv $repo/sim/tb_direct_all_v7_quad_aggregate.sv
exec xelab tb_direct_all_v7_quad_aggregate -s direct_all_v7_quad_aggregate_sim -mt off
after 2000
set output [exec xsim direct_all_v7_quad_aggregate_sim -R]
puts $output
if {[regexp {Fatal:|Error:|ERROR:} $output] ||
    ![string match {*PASS: fourteen-quad readiness/cleanup aggregation*} $output]} {
  error "v7 quad aggregation simulation failed"
}
