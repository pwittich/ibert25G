set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set sim_dir [file join $repo_dir build gt_test_engine_sim]

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
  [file join $repo_dir sim tb_gt_test_hardware_shell.sv] \
  [file join $repo_dir sim tb_gt_test_engine_milestone3.sv] \
  [file join $::env(XILINX_VIVADO) data verilog src glbl.v]
# This test elaborates 112 lane instances.  A single elaboration worker avoids
# host-dependent simulator-kernel failures from overcommitting large servers.
exec xelab tb_gt_test_hardware_shell glbl -s gt_test_engine_sim -mt off -L xpm
set sim_output [exec xsim gt_test_engine_sim -runall]
puts $sim_output
if {[regexp {Fatal:|Error:} $sim_output] ||
    ![regexp {PASS: 112-lane synthetic job} $sim_output]} {
  error "GT test engine self-check failed"
}

exec xelab tb_gt_test_engine_milestone3 glbl \
  -s gt_test_engine_milestone3_sim -mt off -L xpm
set milestone3_output [exec xsim gt_test_engine_milestone3_sim -runall]
puts $milestone3_output
if {[regexp {Fatal:|Error:} $milestone3_output] ||
    ![regexp {PASS: milestone-3 mask} $milestone3_output]} {
  error "Milestone-3 test-engine self-check failed"
}
