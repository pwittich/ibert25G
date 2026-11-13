set repo [file dirname [file dirname [file normalize [info script]]]]
set work [file join $repo build all_links_v3_engine_sim_[clock microseconds]]
if {[file exists $work]} {error "Refusing existing simulation directory $work"}
file mkdir $work
cd $work
exec xvlog -sv $repo/src/all_links_v3_return_pipeline.sv $repo/src/all_links_v3_config.sv $repo/src/all_links_v3_lane_engine.sv \
  $repo/src/all_links_v3_result_copy_bank.sv $repo/src/all_links_v3_config_ack_bank.sv $repo/src/all_links_v3_engine_core.sv \
  $repo/sim/tb_all_links_v3_engine.sv $::env(XILINX_VIVADO)/data/verilog/src/glbl.v
exec xelab tb_all_links_v3_engine glbl -s v3_engine -mt off -L xpm
set output [exec xsim v3_engine -runall]
puts $output
if {![string match {*PASS: v3 engine*} $output] || [regexp {Error:|Fatal:} $output]} {error "v3 engine simulation failed"}

exec xelab tb_all_links_v3_engine glbl -s v3_engine_delayed_ack -mt off -L xpm -generic_top EXTRA_ACK_DELAY=1
set delayed_output [exec xsim v3_engine_delayed_ack -runall]
puts $delayed_output
if {![string match {*PASS: v3 engine*} $delayed_output] || [regexp {Error:|Fatal:} $delayed_output]} {
  error "V3 delayed acknowledgement simulation failed"
}
puts "PASS: v3 acknowledgement guard tolerates independently delayed return data and phase"
