set repo [file dirname [file dirname [file normalize [info script]]]]
set work [file join $repo build all_links_v1_aggregate_sim]
file delete -force $work
file mkdir $work
cd $work
exec xvlog -sv $repo/src/direct_all_v7_quad_aggregate.sv \
  $repo/src/all_links_v1_quad_aggregate.sv \
  $repo/sim/tb_all_links_v1_quad_aggregate.sv
exec xelab tb_all_links_v1_quad_aggregate -s all_links_v1_aggregate -mt off
set output [exec xsim all_links_v1_aggregate -R]
puts $output
if {![string match {*PASS: final four-bank aggregation*} $output]} {
  error "all-links aggregate/session simulation failed"
}
