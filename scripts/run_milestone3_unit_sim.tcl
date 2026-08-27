set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set sim_dir [file join $repo_dir build gt_milestone3_unit_sim]
file delete -force $sim_dir
file mkdir $sim_dir
cd $sim_dir
exec xvlog -sv \
  [file join $repo_dir src gt_quad_controller.sv] \
  [file join $repo_dir src gt_prbs_test_controller.sv] \
  [file join $repo_dir sim tb_gt_quad_controller.sv] \
  [file join $repo_dir sim tb_gt_prbs_test_controller.sv]
exec xelab tb_gt_quad_controller -s gt_milestone3_unit_sim -mt off
set output [exec xsim gt_milestone3_unit_sim -runall]
puts $output
if {[regexp {Fatal:|Error:} $output] ||
    ![regexp {PASS: quad reset} $output]} {
  error "Milestone-3 quad-controller self-check failed"
}
exec xelab tb_gt_prbs_test_controller -s gt_prbs_controller_sim -mt off
set output [exec xsim gt_prbs_controller_sim -runall]
puts $output
if {[regexp {Fatal:|Error:} $output] ||
    ![regexp {PASS: PMA reset ordering} $output]} {
  error "Milestone-3 PRBS-controller self-check failed"
}
