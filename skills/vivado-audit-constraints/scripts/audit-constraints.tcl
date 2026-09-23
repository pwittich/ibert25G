if {$argc == 0 || [lindex $argv 0] in {-h --help}} {
  puts "usage: vivado -mode batch -source audit-constraints.tcl -tclargs PROJECT_XPR ?RUN? ?REPORT_DIR?"
  exit 0
}

set project_file [file normalize [lindex $argv 0]]
set run_name impl_1
if {$argc > 1} { set run_name [lindex $argv 1] }
set report_dir [file join [pwd] constraint-reports]
if {$argc > 2} { set report_dir [file normalize [lindex $argv 2]] }
if {![file exists $project_file]} { error "Project not found: $project_file" }
file mkdir $report_dir
open_project $project_file
if {[get_property PROGRESS [get_runs $run_name]] ne "100%"} { error "Run $run_name is not complete" }
open_run $run_name

check_timing -verbose -file [file join $report_dir check_timing.rpt]
report_clocks -file [file join $report_dir clocks.rpt]
report_clock_interaction -delay_type min_max -file [file join $report_dir clock_interaction.rpt]
report_exceptions -coverage -file [file join $report_dir exceptions.rpt]
report_cdc -details -file [file join $report_dir cdc.rpt]
report_methodology -file [file join $report_dir methodology.rpt]
report_drc -file [file join $report_dir drc.rpt]

set missing_pin {}
set default_iostandard {}
foreach port [get_ports -quiet] {
  if {[get_property PACKAGE_PIN $port] eq ""} { lappend missing_pin $port }
  if {[get_property IOSTANDARD $port] eq "DEFAULT"} { lappend default_iostandard $port }
}
set fh [open [file join $report_dir io_gaps.rpt] w]
puts $fh "Ports without PACKAGE_PIN ([llength $missing_pin]): $missing_pin"
puts $fh "Ports with DEFAULT IOSTANDARD ([llength $default_iostandard]): $default_iostandard"
close $fh
puts "Wrote constraint audit to $report_dir"
