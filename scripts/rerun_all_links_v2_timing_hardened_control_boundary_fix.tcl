# Reuse the exact fresh timing-hardened synthesis for one focused normal
# implementation.  Harden only the established eight-register control/reset
# boundary per SLR; result-copy hierarchy retains soft SLR guidance.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set project_name gt_test_all_links_v2_timing_hardened
set project_dir [file join $repo_dir build $project_name]
set project_file [file join $project_dir ${project_name}.xpr]
set synth_dcp [file join $project_dir ${project_name}.runs synth_1 gt_test_all_links_v1_top.dcp]
set prior_archive [file join $repo_dir build diagnostic_archive all-links-v2-timing-hardened-hard-copy-stage-timing-failure gt_test_all_links_v2_timing_hardened_locality_fix_routed.dcp]
set report_dir [file join $repo_dir build all_links_v2_timing_hardened_control_boundary_fix_reports]
set output_dcp [file join $project_dir ${project_name}_control_boundary_fix_routed.dcp]
set expected_synth_sha a914ff24b3a9e9a106ff92a6276ce2c0842df701112c420e65e4c61e1847b8f9
set expected_prior_sha 362a042f1fc921019e326f03e66774264c0782c82c9c335c5d5636c24cbbea33

foreach f [list $project_file $synth_dcp $prior_archive] {
  if {![file isfile $f]} {error "Missing required immutable input $f"}
}
proc sha256 {path} {return [lindex [exec sha256sum $path] 0]}
if {[sha256 $synth_dcp] ne $expected_synth_sha} {error "Synth DCP hash mismatch"}
if {[sha256 $prior_archive] ne $expected_prior_sha} {error "Prior failed route archive hash mismatch"}
if {[file exists $report_dir] || [file exists $output_dcp]} {
  error "Control-boundary-fix outputs already exist; refusing retry/overwrite"
}
file mkdir $report_dir
open_project $project_file
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Synthesis is not complete"}
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Prior implementation state is not preserved"}
foreach run {synth_1 impl_1} {
  set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs $run]
  set_property INCREMENTAL_CHECKPOINT {} [get_runs $run]
}
reset_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "0%"} {error "Implementation reset failed"}
puts "ALL_LINKS_V2_CONTROL_BOUNDARY_FIX: exact synth hash pinned; launching one normal nonincremental implementation"
launch_runs impl_1 -to_step route_design -jobs 12
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Control-boundary-fix implementation failed"}
open_run impl_1
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {
  error "Bitstream compression disabled"
}
write_checkpoint $output_dcp
set timing [report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose \
  -return_string -file [file join $report_dir timing_summary_routed.rpt]]
set routing [report_route_status -return_string -file [file join $report_dir route_status.rpt]]
report_drc -file [file join $report_dir drc_routed.rpt]
report_bus_skew -file [file join $report_dir bus_skew_routed.rpt]
report_cdc -details -file [file join $report_dir cdc_routed.rpt]
if {![regexp {# of nets with routing errors[. ]*:[ ]*0} $routing]} {error "Routing errors"}
foreach v [get_drc_violations -quiet] {
  if {[get_property SEVERITY $v] eq "Error"} {error "Routed DRC error $v"}
}
if {![string match {*All user specified timing constraints are met.*} $timing]} {
  error "Control-boundary-fix route misses timing; evidence preserved"
}
puts "PASS: all-links v2 control-boundary-fix route is timing clean; independent audit required"
