set repo [file dirname [file dirname [file normalize [info script]]]]
set work [file join $repo build eye_scan_drp_sim_[clock microseconds]]
if {[file exists $work]} {error "Refusing existing simulation directory $work"}
file mkdir $work
cd $work
exec xvlog -sv $repo/src/eye_scan_drp_arbiter.sv $repo/sim/tb_eye_scan_drp_arbiter.sv
exec xelab tb_eye_scan_drp_arbiter -s eye_scan_drp -mt off
set output [exec xsim eye_scan_drp -runall]
puts $output
if {![string match {*PASS: eye scan DRP ownership*} $output] ||
    [regexp {Error:|Fatal:} $output]} {error "Eye scan DRP simulation failed"}
