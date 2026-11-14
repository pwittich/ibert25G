set repo [file dirname [file dirname [file normalize [info script]]]]
set work [file join $repo build eye_scan_point_sim_[clock microseconds]]
if {[file exists $work]} {error "Refusing existing simulation directory $work"}
file mkdir $work
cd $work
exec xvlog -sv $repo/src/eye_scan_drp_arbiter.sv $repo/src/eye_scan_point.sv \
  $repo/sim/eye_scan_gt_model.sv $repo/sim/tb_eye_scan_point.sv
exec xelab tb_eye_scan_point -s eye_scan_point -mt off
set output [exec xsim eye_scan_point -runall]
puts $output
if {![string match {*PASS: eye scan point*} $output] ||
    [regexp {Error:|Fatal:} $output]} {error "Eye scan point simulation failed"}
