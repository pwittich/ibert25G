if {$argc == 0 || [lindex $argv 0] in {-h --help}} {
  puts "usage: vivado -mode batch -source report-implementation-health.tcl -tclargs PROJECT_XPR ?RUN? ?REPORT_DIR?"
  exit 0
}

set project_file [file normalize [lindex $argv 0]]
set run_name impl_1
if {$argc > 1} { set run_name [lindex $argv 1] }
set report_dir [file join [pwd] implementation-reports]
if {$argc > 2} { set report_dir [file normalize [lindex $argv 2]] }
if {![file exists $project_file]} { error "Project not found: $project_file" }
file mkdir $report_dir
open_project $project_file
if {[get_property PROGRESS [get_runs $run_name]] ne "100%"} { error "Run $run_name is not complete" }
open_run $run_name

report_drc -file [file join $report_dir drc.rpt]
report_methodology -file [file join $report_dir methodology.rpt]
report_utilization -hierarchical -file [file join $report_dir utilization_hierarchical.rpt]
report_clock_utilization -file [file join $report_dir clock_utilization.rpt]
report_route_status -file [file join $report_dir route_status.rpt]
report_high_fanout_nets -timing -load_types -max_nets 100 \
  -file [file join $report_dir high_fanout_nets.rpt]
report_timing_summary -delay_type min_max -report_unconstrained -max_paths 20 \
  -file [file join $report_dir timing_summary.rpt]

set gt_channels [get_cells -quiet -hier -filter {REF_NAME == GTYE4_CHANNEL}]
set fh [open [file join $report_dir gty_placement.tsv] w]
puts $fh "cell\tloc"
foreach cell $gt_channels { puts $fh "$cell\t[get_property LOC $cell]" }
close $fh
puts "GTYE4_CHANNEL count: [llength $gt_channels]"
puts "Wrote implementation reports to $report_dir"
