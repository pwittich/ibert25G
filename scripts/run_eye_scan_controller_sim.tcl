set repo [file dirname [file dirname [file normalize [info script]]]]
set work [file join $repo build eye_scan_controller_sim_[clock microseconds]]
file mkdir $work
cd $work
exec xvlog -sv $repo/src/eye_scan_controller.sv $repo/sim/tb_eye_scan_controller.sv
exec xelab tb_eye_scan_controller -s eye_controller -mt off
set output [exec xsim eye_controller -runall]
puts $output
if {![string match {*PASS: eye scan global controller*} $output] ||
    [regexp {Error:|Fatal:} $output]} {error "Eye controller simulation failed"}
