set repo [file dirname [file dirname [file normalize [info script]]]]
set work [file join $repo build all_links_v1_subset_sim]
file delete -force $work
file mkdir $work
cd $work
exec xvlog -sv \
  $repo/src/gt_lane_engine.sv $repo/src/all_links_v2_result_copy_bank.sv \
  $repo/src/gt_test_engine_core.sv \
  $repo/src/axi_lite_gt_test_engine.sv $repo/src/i2c_register_slave.sv \
  $repo/src/gt_test_engine_shell.sv $repo/src/gt_test_hardware_shell.sv \
  $repo/sim/tb_gt_test_engine_milestone3.sv \
  $::env(XILINX_VIVADO)/data/verilog/src/glbl.v
exec xelab tb_all_links_v1_subset_engine glbl -s all_links_v1_subset -mt off -L xpm
set result_log [file join $work all_links_v1_subset.out]
exec xsim all_links_v1_subset -runall > $result_log 2>@1
set result_file [open $result_log r]
set output [read $result_file]
close $result_file
puts $output
if {![string match {*PASS: milestone-3 mask, out-of-range rejection*} $output]} {
  error "all-links fresh subset engine simulation failed"
}
puts "PASS: focused all-links v1 subset engine regression"
