set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set out_dir [file join $repo_dir build gt_test_engine_ooc]

file delete -force $out_dir
file mkdir $out_dir

read_verilog -sv [list \
  [file join $repo_dir src gt_lane_engine.sv] \
  [file join $repo_dir src gt_test_engine_core.sv] \
  [file join $repo_dir src axi_lite_gt_test_engine.sv]]

synth_design -mode out_of_context -flatten_hierarchy rebuilt \
  -top axi_lite_gt_test_engine -part xcvu13p-flga2577-2-e
create_clock -name s_axi_aclk -period 5.000 [get_ports s_axi_aclk]

report_utilization -file [file join $out_dir utilization.rpt]
report_cdc -details -file [file join $out_dir cdc.rpt]
report_methodology -file [file join $out_dir methodology.rpt]
write_checkpoint -force [file join $out_dir axi_lite_gt_test_engine.dcp]

puts "Synthetic GT test engine synthesized successfully"
puts "Reports: $out_dir"
