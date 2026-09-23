set r [file dirname [file dirname [file normalize [info script]]]]
set d [file join $r build prbs_pma_regression]
file mkdir $d
cd $d
exec xvlog -sv [file join $r src gt_prbs_test_controller.sv] [file join $r src gt_runtime_integrity_monitor.sv] [file join $r sim tb_gt_prbs_test_controller.sv]
exec xelab tb_gt_prbs_test_controller -s prbs_pma_regression -mt off
set output [exec xsim prbs_pma_regression -runall]
puts $output
if {[regexp {Fatal:|Error:} $output] || ![string match {*PASS: PMA reset, external live-RX acquisition*} $output]} {
  error "PMA continuity/cleanup regression failed"
}
exec xelab tb_gt_prbs_cleanup_no_ack -s prbs_cleanup_no_ack -mt off
set output [exec xsim prbs_cleanup_no_ack -runall]
puts $output
if {[regexp {Fatal:|Error:} $output] || ![string match {*PASS: missing cleanup reset acknowledgement fails boundedly*} $output]} {
  error "Missing cleanup acknowledgement regression failed"
}
