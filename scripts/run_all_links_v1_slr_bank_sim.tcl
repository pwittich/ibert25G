set repo [file dirname [file dirname [file normalize [info script]]]]
set work [file join $repo build all_links_v1_slr_bank_sim]
file delete -force $work
file mkdir $work
cd $work
exec xvlog -sv $repo/src/direct_all_v7_quad_aggregate.sv \
  $repo/src/all_links_v1_quad_aggregate.sv \
  $repo/sim/all_links_v1_slr_bank_stubs.sv \
  $repo/src/all_links_v1_slr_bank.sv \
  $repo/sim/tb_all_links_v1_slr_bank.sv
exec xelab tb_all_links_v1_slr_bank -s all_links_v1_slr_bank -mt off
set output [exec xsim all_links_v1_slr_bank -runall]
puts $output
if {![string match {*PASS: four SLR-bank reset*} $output]} {
  error "all-links SLR-bank focused simulation failed"
}
