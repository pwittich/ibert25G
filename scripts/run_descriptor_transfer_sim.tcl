set repo [file dirname [file dirname [file normalize [info script]]]]
set sim_dir [file join $repo build descriptor_transfer_sim]
file mkdir $sim_dir
cd $sim_dir
exec xvlog -sv $repo/src/gt_lane_engine.sv $repo/sim/tb_gt_lane_descriptor_transfer.sv
exec xelab tb_gt_lane_descriptor_transfer -s descriptor_transfer_sim -mt off
set output [exec xsim descriptor_transfer_sim -R]
puts $output
if {[regexp {Fatal:|Error:|ERROR:} $output] ||
    ![string match {*PASS: descriptor per-bit skew*} $output]} {
  error "Descriptor transfer regression failed"
}
