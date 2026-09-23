if {$argc == 0 || [lindex $argv 0] in {-h --help}} {
  puts "usage: vivado -mode batch -source report-timing-health.tcl -tclargs PROJECT_XPR ?RUN? ?REPORT_DIR?"
  exit 0
}

set project_file [file normalize [lindex $argv 0]]
set run_name impl_1
if {$argc > 1} { set run_name [lindex $argv 1] }
set report_dir [file join [pwd] timing-reports]
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
report_timing_summary -delay_type min_max -report_unconstrained -max_paths 50 \
  -file [file join $report_dir timing_summary.rpt]

set setup_path [get_timing_paths -quiet -delay_type max -max_paths 1]
set hold_path [get_timing_paths -quiet -delay_type min -max_paths 1]
set setup_slack [expr {[llength $setup_path] ? [get_property SLACK $setup_path] : "NA"}]
set hold_slack [expr {[llength $hold_path] ? [get_property SLACK $hold_path] : "NA"}]
puts "Worst setup slack: $setup_slack ns"
puts "Worst hold slack: $hold_slack ns"
puts "Wrote timing reports to $report_dir"
if {$setup_slack ne "NA" && $setup_slack < 0.0} { error "Setup timing is not met" }
if {$hold_slack ne "NA" && $hold_slack < 0.0} { error "Hold timing is not met" }
