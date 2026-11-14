set script_dir [file dirname [file normalize [info script]]]
set repo [file dirname $script_dir]
set project_dir [file join $repo build gt_test_eye_scan_v1]
set reports [file join $repo build eye_scan_v1_reports]
if {[file exists $reports]} {error "Refusing existing eye v1 build reports"}
file mkdir $reports
open_project [file join $project_dir gt_test_eye_scan_v1.xpr]
if {![string match "2023.2*" [version -short]] ||
    [get_property PART [current_project]] ne "xcvu13p-flga2577-2-e"} {error "Tool/part mismatch"}
foreach ip [get_ips] {
  if {[get_property IS_LOCKED $ip]} {error "Locked IP: $ip"}
}
report_ip_status -file [file join $reports ip_status.rpt]
foreach run {synth_1 impl_1} {
  if {[get_property PROGRESS [get_runs $run]] ne "0%"} {error "Run $run already started; inspect before resume"}
  set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs $run]
  set_property INCREMENTAL_CHECKPOINT {} [get_runs $run]
}
set source_inputs {}
foreach f [get_files -all] {
  if {[file isfile $f] && [file extension $f] in {.sv .v .vhd .xdc .xci .elf .mem .coe .dcp}} {
    lappend source_inputs [file normalize $f]
  }
}
set source_inputs [lsort -unique $source_inputs]
set snapshot [file join $reports SOURCE_SHA256SUMS]
set f [open $snapshot {WRONLY CREAT EXCL}]
puts $f [exec sha256sum {*}$source_inputs]
close $f
launch_runs synth_1 -jobs 12
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Eye v1 synthesis failed"}
open_run synth_1
exec sha256sum -c $snapshot
source [file join $script_dir check_eye_scan_v1_synth.tcl]
write_checkpoint [file join $project_dir gt_test_eye_scan_v1_synth.dcp]
close_design
exec sha256sum -c $snapshot
set implementation_inputs [list $snapshot \
  [file join $project_dir gt_test_eye_scan_v1_synth.dcp] \
  [file join $script_dir apply_eye_scan_v1_constraints.tcl] \
  [file join $script_dir build_eye_scan_v1_routed.tcl] \
  [file join $script_dir check_eye_scan_v1_synth.tcl]]
lappend implementation_inputs [file join $script_dir apply_eye_scan_initialization.tcl] \
  [file join $script_dir check_eye_scan_drp_boundary.tcl]
set implementation_snapshot [file join $reports IMPLEMENTATION_SHA256SUMS]
set f [open $implementation_snapshot {WRONLY CREAT EXCL}]
puts $f [exec sha256sum {*}$implementation_inputs]
close $f
launch_runs impl_1 -to_step route_design -jobs 12
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Eye v1 implementation failed"}
exec sha256sum -c $snapshot
exec sha256sum -c $implementation_snapshot
open_run impl_1
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {
  error "Compression disabled"
}
write_checkpoint [file join $project_dir gt_test_eye_scan_v1_routed.dcp]
set timing [report_timing_summary -delay_type min_max -report_unconstrained \
  -return_string -file [file join $reports timing.rpt]]
set routing [report_route_status -return_string -file [file join $reports routing.rpt]]
report_drc -file [file join $reports drc.rpt]
report_bus_skew -file [file join $reports bus_skew.rpt]
report_cdc -details -file [file join $reports cdc.rpt]
if {![regexp {# of nets with routing errors[. ]*:[ ]*0} $routing]} {error "Routing errors"}
foreach v [get_drc_violations -quiet] {
  if {[get_property SEVERITY $v] eq "Error"} {error "Error DRC: $v"}
}
if {![string match {*All user specified timing constraints are met.*} $timing]} {
  error "Eye v1 misses timing; routed evidence preserved; no bitstream"
}
puts "PASS: eye v1 route complete; independent audit required before BIT/BIN"
