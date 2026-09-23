set repo [file dirname [file dirname [file normalize [info script]]]]
set work [file join $repo build all_links_v2_participation_sim]
file delete -force $work
file mkdir $work
cd $work
exec xvlog -sv \
  $repo/src/gt_lane_engine.sv $repo/src/all_links_v2_result_copy_bank.sv \
  $repo/src/gt_test_engine_core.sv \
  $repo/src/direct_all_v7_quad_aggregate.sv \
  $repo/src/all_links_v1_quad_aggregate.sv \
  $repo/sim/all_links_v1_slr_bank_stubs.sv \
  $repo/src/all_links_v1_slr_bank.sv \
  $repo/sim/tb_all_links_v2_participation.sv
exec xelab tb_all_links_v2_participation -s all_links_v2_participation -mt off -L xpm
set output [exec xsim all_links_v2_participation -runall]
puts $output
if {![string match {*PASS: all-links v2 direct-only/sparse/all112/back-to-back participation and publication epochs*} $output]} {
  error "all-links v2 participation simulation failed"
}
