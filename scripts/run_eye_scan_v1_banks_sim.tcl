set repo [file dirname [file dirname [file normalize [info script]]]]
set work [file join $repo build eye_scan_v1_banks_sim_[clock microseconds]]
file mkdir $work
cd $work
exec xvlog -sv $repo/src/all_links_v3_return_pipeline.sv $repo/src/direct_all_v7_quad_aggregate.sv \
  $repo/src/all_links_v3_quad_aggregate.sv $repo/src/eye_scan_v1_quad_aggregate.sv $repo/sim/eye_scan_v1_bank_stubs.sv \
  $repo/src/eye_scan_v1_slr_bank.sv $repo/sim/tb_eye_scan_v1_banks.sv $repo/sim/tb_eye_scan_v1_status.sv
exec xelab tb_eye_scan_v1_banks -s v3_banks -mt off
set output [exec xsim v3_banks -runall]
puts $output
if {![string match {*PASS: eye v1 four-bank*} $output] || [regexp {Error:|Fatal:} $output]} {
  error "V3 bank simulation failed"
}
exec xelab tb_eye_scan_v1_status -s eye_status -mt off
set status_output [exec xsim eye_status -runall]
puts $status_output
if {![string match {*PASS: eye v1 matched status*} $status_output] || [regexp {Error:|Fatal:} $status_output]} {
  error "Eye matched status transport simulation failed"
}
