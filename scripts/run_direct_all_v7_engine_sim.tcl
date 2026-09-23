set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set sim_dir [file join $repo_dir build direct_all_v7_engine_sim]

file delete -force $sim_dir
file mkdir $sim_dir
cd $sim_dir

exec xvlog -sv \
  [file join $repo_dir src gt_lane_engine.sv] \
  [file join $repo_dir src gt_test_engine_core.sv] \
  [file join $repo_dir src axi_lite_gt_test_engine.sv] \
  [file join $repo_dir src i2c_register_slave.sv] \
  [file join $repo_dir src gt_test_engine_shell.sv] \
  [file join $repo_dir src gt_test_hardware_shell.sv] \
  [file join $repo_dir sim tb_gt_test_engine_milestone3.sv] \
  [file join $::env(XILINX_VIVADO) data verilog src glbl.v]
exec xelab tb_direct_all_v7_engine glbl -s direct_all_v7_engine -mt off -L xpm
set output [exec xsim direct_all_v7_engine -R]
puts $output
if {[regexp {Fatal:|Error:|ERROR:} $output] ||
    ![string match {*PASS: milestone-3 mask*} $output]} {
  error "all-direct v7 exact-56 engine simulation failed"
}
puts "PASS: all-direct v7 exact 56-lane mask, atomic publication, and consecutive run IDs"
