# Resume only the completed, checksum-pinned initial eye synthesis. No synth
# retry, route retry or historical target is included in this continuation.
set script_dir [file dirname [file normalize [info script]]]
set repo [file dirname $script_dir]
set project_dir [file join $repo build gt_test_eye_scan_v1]
set reports [file join $repo build eye_scan_v1_reports]
set source_snapshot [file join $reports SOURCE_SHA256SUMS]
exec sha256sum -c $source_snapshot
if {[file exists [file join $reports IMPLEMENTATION_SHA256SUMS]] ||
    [file exists [file join $project_dir gt_test_eye_scan_v1_routed.dcp]]} {
  error "Implementation has already been prepared or run; inspect before continuing"
}
open_project [file join $project_dir gt_test_eye_scan_v1.xpr]
if {[get_property PROGRESS [get_runs synth_1]] ne "100%" ||
    [get_property PROGRESS [get_runs impl_1]] ne "0%"} {error "Unexpected run state"}
open_run synth_1
source [file join $script_dir check_eye_scan_v1_synth.tcl]
set synth [file join $project_dir gt_test_eye_scan_v1_synth.dcp]
if {[file exists $synth]} {error "Refusing existing initialized synthesis checkpoint"}
write_checkpoint $synth
close_design
set inputs [list $source_snapshot $synth [file join $script_dir apply_eye_scan_v1_constraints.tcl] \
  [file join $script_dir apply_eye_scan_initialization.tcl] [file join $script_dir check_eye_scan_v1_synth.tcl] \
  [file join $script_dir build_eye_scan_v1_routed.tcl] [file normalize [info script]]]
set implementation_snapshot [file join $reports IMPLEMENTATION_SHA256SUMS]
set f [open $implementation_snapshot {WRONLY CREAT EXCL}]
puts $f [exec sha256sum {*}$inputs];close $f
launch_runs impl_1 -to_step route_design -jobs 12
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Eye implementation failed"}
exec sha256sum -c $source_snapshot
exec sha256sum -c $implementation_snapshot
open_run impl_1
write_checkpoint [file join $project_dir gt_test_eye_scan_v1_routed.dcp]
set timing [report_timing_summary -delay_type min_max -report_unconstrained \
  -return_string -file [file join $reports timing.rpt]]
set route [report_route_status -return_string -file [file join $reports routing.rpt]]
report_drc -file [file join $reports drc.rpt]
report_bus_skew -file [file join $reports bus_skew.rpt]
report_cdc -details -file [file join $reports cdc.rpt]
foreach v [get_drc_violations -quiet] {
  if {[get_property SEVERITY $v] eq "Error"} {error "Error DRC $v"}
}
if {![regexp {# of nets with routing errors[. ]*:[ ]*0} $route]} {error "Routing errors"}
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] TRUE]} {
  error "Compression disabled"
}
if {![string match {*All user specified timing constraints are met.*} $timing]} {
  error "Eye timing failed; routed evidence preserved, no bitstream"
}
puts "PASS: eye v1 normal route; independent audit required before BIT/BIN"
