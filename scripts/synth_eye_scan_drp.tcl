# Standalone synthesis smoke gate only; this does not qualify image timing.
set repo [file dirname [file dirname [file normalize [info script]]]]
if {![string match "2023.2*" [version -short]]} {error "Requires Vivado 2023.2"}
set work [file join $repo build eye_scan_drp_synth_[clock microseconds]]
if {[file exists $work]} {error "Refusing existing synthesis directory $work"}
file mkdir $work
create_project -in_memory -part xcvu13p-flga2577-2-e
read_verilog -sv [file join $repo src eye_scan_drp_arbiter.sv]
synth_design -top eye_scan_drp_arbiter -part xcvu13p-flga2577-2-e -mode out_of_context
set latches [get_cells -hier -quiet -filter {IS_PRIMITIVE && REF_NAME =~ LD*}]
if {[llength $latches]} {error "Unexpected latches: $latches"}
set state_regs [get_cells -hier -quiet -filter {NAME =~ state_reg* && REF_NAME =~ FD*}]
if {[llength $state_regs] != 2} {error "FSM encoding/register inventory changed: $state_regs"}
create_clock -name mgmt_clk -period 5.000 [get_ports mgmt_clk]
report_utilization -file [file join $work utilization.rpt]
report_timing_summary -file [file join $work timing.rpt]
write_checkpoint [file join $work eye_scan_drp_arbiter_synth.dcp]
puts "PASS: eye scan DRP standalone synthesis, no latches, two encoded state registers"
puts "EYE_DRP_SYNTH_REPORTS $work"
close_project
