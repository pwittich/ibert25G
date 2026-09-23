set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set sim_dir [file join $repo_dir build gt_milestone3_unit_sim]
file delete -force $sim_dir
file mkdir $sim_dir
cd $sim_dir
exec xvlog -sv \
  [file join $repo_dir src gt_quad_controller.sv] \
  [file join $repo_dir src gt_prbs_test_controller.sv] \
  [file join $repo_dir src gt_runtime_integrity_monitor.sv] \
  [file join $repo_dir src managed_quad124_lane_reset_policy.sv] \
  [file join $repo_dir sim tb_gt_quad_controller.sv] \
  [file join $repo_dir sim tb_gt_prbs_test_controller.sv] \
  [file join $repo_dir sim tb_gt_prbs_test_controller_fixed.sv] \
  [file join $repo_dir sim tb_gt_prbs_test_controller_recovery.sv] \
  [file join $repo_dir sim tb_gt_prbs_quad_restart.sv] \
  [file join $repo_dir sim tb_gt_prbs_planned_startup_restart.sv] \
  [file join $repo_dir sim tb_gt_prbs_runtime_integrity.sv] \
  [file join $repo_dir sim tb_gt_runtime_integrity_monitor.sv] \
  [file join $repo_dir sim tb_managed_quad124_lane_reset_policy.sv]
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
    ![regexp {PASS: PMA reset, external live-RX acquisition} $output]} {
  error "Milestone-3 PRBS-controller self-check failed"
}
exec xelab tb_gt_prbs_test_controller_fixed \
  -s gt_prbs_controller_fixed_sim -mt off
set output [exec xsim gt_prbs_controller_fixed_sim -runall]
puts $output
if {[regexp {Fatal:|Error:} $output] ||
    ![regexp {PASS: fixed staged acquisition} $output]} {
  error "Milestone-2.5.2 fixed-acquisition self-check failed"
}
exec xelab tb_gt_prbs_test_controller_recovery \
  -s gt_prbs_controller_recovery_sim -mt off
set output [exec xsim gt_prbs_controller_recovery_sim -runall]
puts $output
if {[regexp {Fatal:|Error:} $output] ||
    ![regexp {PASS: bounded external recovery and CAPTURE_DONE-to-IDLE RX requalification} $output]} {
  error "Milestone-2.5.5 external-recovery self-check failed"
}
exec xelab tb_gt_prbs_quad_restart \
  -s gt_prbs_quad_restart_sim -mt off
set output [exec xsim gt_prbs_quad_restart_sim -runall]
puts $output
if {[regexp {Fatal:|Error:} $output] ||
    ![regexp {PASS: sustained-failure and post-capture quad restarts} $output]} {
  error "Milestone-2.5.12 quad-restart self-check failed"
}
exec xelab tb_gt_prbs_planned_startup_restart \
  -s gt_prbs_planned_startup_restart_sim -mt off
set output [exec xsim gt_prbs_planned_startup_restart_sim -runall]
puts $output
if {[regexp {Fatal:|Error:} $output] ||
    ![regexp {PASS: planned startup restart and conclusive failure policy} $output]} {
  error "Milestone-2.5.23 planned-startup-restart self-check failed"
}
exec xelab tb_managed_quad124_lane_reset_policy \
  -s gt_lane_reset_policy_sim -mt off
set output [exec xsim gt_lane_reset_policy_sim -runall]
puts $output
if {[regexp {Fatal:|Error:} $output] ||
    ![regexp {PASS: acquisition-only lane-engine reset policy} $output]} {
  error "Milestone-2.5.16 lane-reset policy self-check failed"
}
exec xelab tb_gt_runtime_integrity_monitor \
  -s gt_runtime_integrity_monitor_sim -mt off
set output [exec xsim gt_runtime_integrity_monitor_sim -runall]
puts $output
if {[regexp {Fatal:|Error:} $output] ||
    ![regexp {PASS: runtime integrity assertion, hysteresis, and retention} $output]} {
  error "Runtime-integrity monitor self-check failed"
}
exec xelab tb_gt_prbs_runtime_integrity \
  -s gt_prbs_runtime_integrity_sim -mt off
set output [exec xsim gt_prbs_runtime_integrity_sim -runall]
puts $output
if {[regexp {Fatal:|Error:} $output] ||
    ![regexp {PASS: controller runtime-integrity fault integration} $output]} {
  error "Controller runtime-integrity integration self-check failed"
}
exec xvlog -sv \
  [file join $repo_dir src gt_lane_engine.sv] \
  [file join $repo_dir sim tb_gt_lane_engine_restart.sv]
exec xelab tb_gt_lane_engine_restart -s gt_lane_restart_sim -mt off
set output [exec xsim gt_lane_restart_sim -runall]
puts $output
if {[regexp {Fatal:|Error:} $output] ||
    ![regexp {PASS: lane restart rearm preserves odd and even toggle phases} $output]} {
  error "Milestone-2.5.17 lane restart-rearm self-check failed"
}
exec xvlog -sv \
  [file join $repo_dir src gt_test_engine_core.sv] \
  [file join $repo_dir sim tb_gt_recovery_system.sv] \
  [file join $env(XILINX_VIVADO) data verilog src glbl.v]
exec xelab tb_gt_recovery_system glbl -s gt_recovery_system_sim -mt off -L xpm
set output [exec xsim gt_recovery_system_sim -runall]
puts $output
if {[regexp {Fatal:|Error:} $output] ||
    ![regexp {PASS: integrated recovery} $output]} {
  error "Integrated recovery self-check failed"
}
exec xvlog -sv [file join $repo_dir src gt_transition_trace.sv] \
  [file join $repo_dir src gt_rx_error_profile.sv] \
  [file join $repo_dir sim tb_gt_diagnostic_capture.sv]
exec xelab tb_gt_diagnostic_capture glbl -s gt_diagnostic_capture_sim -mt off -L xpm
set output [exec xsim gt_diagnostic_capture_sim -runall]
puts $output
if {[regexp {Fatal:|Error:|ERROR:} $output] ||
    ![regexp {PASS: transition trace} $output]} {
  error "Diagnostic capture self-check failed"
}
source [file join $script_dir run_descriptor_transfer_sim.tcl]
