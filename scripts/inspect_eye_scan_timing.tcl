# Read-only timing triage of this development target. Never implements a
# design or writes a checkpoint; may inspect a completed placed checkpoint
# while the project continues its normal implementation.
set repo [file dirname [file dirname [file normalize [info script]]]]
set project [file join $repo build gt_test_eye_scan_v1]
set checkpoint [file join $project gt_test_eye_scan_v1_routed.dcp]
if {[llength $argv] > 1} {error "Usage: inspect_eye_scan_timing.tcl ?checkpoint?"}
if {[llength $argv] == 1} {
  set checkpoint [file normalize [lindex $argv 0]]
} elseif {![file isfile $checkpoint]} {
  set checkpoint [file join $project gt_test_eye_scan_v1.runs impl_1 gt_test_eye_scan_v1_top_placed.dcp]
}
if {![file isfile $checkpoint]} {error "No completed eye checkpoint"}
set checksum [lindex [exec sha256sum $checkpoint] 0]
set reports [file join $repo build eye_scan_timing_[clock microseconds]]
file mkdir $reports
open_checkpoint $checkpoint
if {[get_property TOP [current_design]] ne "gt_test_eye_scan_v1_top" ||
    [get_property PART [current_design]] ne "xcvu13p-flga2577-2-e"} {
  error "Unexpected timing target"
}
check_timing -verbose -file [file join $reports check_timing.rpt]
report_clocks -file [file join $reports clocks.rpt]
report_clock_interaction -file [file join $reports clock_interaction.rpt]
report_exceptions -coverage -file [file join $reports exceptions.rpt]
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $reports summary.rpt]
report_timing -delay_type max -max_paths 100 -nworst 1 -path_type full_clock_expanded -file [file join $reports setup.rpt]
report_timing -delay_type min -max_paths 30 -nworst 1 -path_type full_clock_expanded -file [file join $reports hold.rpt]
set f [open [file join $reports negative_setup.tsv] {WRONLY CREAT EXCL}]
puts $f "slack\tstartpoint\tendpoint\tstart_clock\tend_clock\tlogic_levels\tdatapath_delay"
foreach p [get_timing_paths -quiet -delay_type max -slack_lesser_than 0 -max_paths 1000 -nworst 1] {
  set fields {}
  foreach property {SLACK STARTPOINT_PIN ENDPOINT_PIN STARTPOINT_CLOCK ENDPOINT_CLOCK LOGIC_LEVELS DATAPATH_DELAY} {
    lappend fields [get_property $property $p]
  }
  puts $f [join $fields "\t"]
}
close $f
if {[lindex [exec sha256sum $checkpoint] 0] ne $checksum} {error "Checkpoint changed during read-only inspection"}
set f [open [file join $reports INPUT_SHA256] {WRONLY CREAT EXCL}]
puts $f "$checksum  $checkpoint"; close $f
puts "EYE_TIMING_REPORTS=$reports"
close_design
