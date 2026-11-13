set repo [file dirname [file dirname [file normalize [info script]]]]
set work [file join $repo build all_links_v3_banks_sim_[clock microseconds]]
file mkdir $work
cd $work
exec xvlog -sv $repo/src/all_links_v3_return_pipeline.sv $repo/src/direct_all_v7_quad_aggregate.sv \
  $repo/src/all_links_v3_quad_aggregate.sv $repo/sim/all_links_v3_bank_stubs.sv \
  $repo/src/all_links_v3_slr_bank.sv $repo/sim/tb_all_links_v3_banks.sv
exec xelab tb_all_links_v3_banks -s v3_banks -mt off
set output [exec xsim v3_banks -runall]
puts $output
if {![string match {*PASS: v3 all-SLR*} $output] || [regexp {Error:|Fatal:} $output]} {
  error "V3 bank simulation failed"
}
