set repo [file dirname [file dirname [file normalize [info script]]]]
set work [file join $repo build all_links_v3_config_sim_[clock microseconds]]
if {[file exists $work]} {error "Refusing existing simulation directory $work"}
file mkdir $work
cd $work
exec xvlog -sv $repo/src/all_links_v3_config.sv $repo/sim/tb_all_links_v3_config.sv
exec xelab tb_all_links_v3_config -s v3_config -mt off
set output [exec xsim v3_config -runall]
puts $output
if {![string match {*PASS: v3 config*} $output]} {error "v3 configuration simulation failed"}
