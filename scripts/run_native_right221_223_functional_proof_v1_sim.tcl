# Separate simulation for the native selection-aware scalar platform binding.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set sim_dir [file join $repo_dir build gt_native_right221_223_functional_proof_v1_sim]
file delete -force $sim_dir
file mkdir $sim_dir
cd $sim_dir
exec xvlog -sv \
  [file join $repo_dir src gt_native_active_quad_contract.sv] \
  [file join $repo_dir src gt_native_active_quad_platform.sv] \
  [file join $repo_dir src gt_lane_engine.sv] \
  [file join $repo_dir src gt_test_engine_core.sv] \
  [file join $repo_dir src axi_lite_gt_test_engine.sv] \
  [file join $repo_dir src i2c_register_slave.sv] \
  [file join $repo_dir src gt_test_engine_shell.sv] \
  [file join $repo_dir src gt_test_hardware_shell.sv] \
  [file join $repo_dir sim tb_gt_native_active_quad_platform.sv] \
  [file join $::env(XILINX_VIVADO) data verilog src glbl.v]
exec xelab tb_gt_native_active_quad_platform glbl \
  -s gt_native_right221_223_functional_proof_v1_sim -mt off -L xpm
set output [exec xsim gt_native_right221_223_functional_proof_v1_sim -runall]
puts $output
if {[regexp {Fatal:|Error:} $output] ||
    ![regexp {PASS: native active-quad contract} $output]} {
  error "Native q221-223 functional proof simulation failed"
}
