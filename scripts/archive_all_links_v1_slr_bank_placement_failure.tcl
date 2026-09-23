set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set name gt_test_all_links_v1
set run_dir [file join $repo_dir build $name ${name}.runs impl_1]
set placed [file join $run_dir ${name}_top_placed.dcp]
set report_dir [file join $repo_dir build all_links_v1_reports slr_bank]
set archive [file join $repo_dir build diagnostic_archive all-links-v1-slr-bank-attempt]
foreach path [list $placed $archive] {if {![file exists $path]} {error "Missing $path"}}
file mkdir $report_dir
open_checkpoint $placed
proc placed_cell_slr {cell} {
  set sites [get_sites -quiet -of_objects $cell]
  set slrs [get_slrs -quiet -of_objects $sites]
  if {[llength $sites] != 1 || [llength $slrs] != 1} {return ""}
  return [get_property NAME [lindex $slrs 0]]
}
set out [open [file join $report_dir placement_failure.rpt] w]
set locality_failures {}
set boundary_failures {}
set expected_counts {6 8 8 6}
for {set slr 0} {$slr < 4} {incr slr} {
  set bank [get_cells -hier -quiet -filter "NAME =~ *g_bank_slr$slr && REF_NAME =~ all_links_v1_slr_bank*"]
  set bank_name [get_property NAME $bank]
  set controls [get_cells -hier -quiet -filter "NAME =~ ${bank_name}/u_control_pipeline/controls_out_reg* && REF_NAME =~ FD*"]
  set resets [get_cells -hier -quiet -filter "NAME == ${bank_name}/local_resetn_reg && REF_NAME =~ FD*"]
  set pb_cells [get_cells -quiet -of_objects [get_pblocks all_links_v1_control_slr$slr]]
  puts $out "SLR$slr controls=[llength $controls] reset=[llength $resets] boundary_pblock=[llength $pb_cells]"
  puts $out "SLR$slr control_names=$controls reset_names=$resets"
  foreach cell [concat $controls $resets] {
    set actual [placed_cell_slr $cell]
    if {$actual ne "SLR$slr"} {lappend boundary_failures [list [get_property NAME $cell] expected=SLR$slr actual=$actual]}
  }
  set roots [get_cells -hier -quiet -filter "NAME =~ ${bank_name}/*/u_prbs_test_controller && REF_NAME =~ gt_prbs_test_controller*"]
  set reducer_leaves [get_cells -hier -quiet -filter "NAME =~ ${bank_name}/u_local_aggregate/* && IS_PRIMITIVE"]
  puts $out "SLR$slr controller_roots=[llength $roots] expected=[lindex $expected_counts $slr] reducer_leaves=[llength $reducer_leaves]"
  foreach root $roots {
    foreach cell [get_cells -hier -quiet -filter "NAME =~ [get_property NAME $root]/* && IS_PRIMITIVE"] {
      if {[get_property REF_NAME $cell] in {VCC GND}} {continue}
      set actual [placed_cell_slr $cell]
      if {$actual ne "SLR$slr"} {lappend locality_failures [list CONTROLLER [get_property NAME $cell] expected=SLR$slr actual=$actual]}
    }
  }
  foreach cell $reducer_leaves {
    if {[get_property REF_NAME $cell] in {VCC GND}} {continue}
    set actual [placed_cell_slr $cell]
    if {$actual ne "SLR$slr"} {lappend locality_failures [list REDUCER [get_property NAME $cell] expected=SLR$slr actual=$actual]}
  }
}
set timing [report_timing_summary -delay_type min_max -max_paths 100 -report_unconstrained \
  -return_string -file [file join $report_dir timing_placed_failure.rpt]]
regexp {Setup\s*:\s*([0-9]+)\s+Failing Endpoints,\s+Worst Slack\s+([-0-9.]+)ns,\s+Total Violation\s+([-0-9.]+)ns} $timing -> setup_failed wns tns
regexp {Hold\s*:\s*([0-9]+)\s+Failing Endpoints,\s+Worst Slack\s+([-0-9.]+)ns,\s+Total Violation\s+([-0-9.]+)ns} $timing -> hold_failed whs ths
set skew [report_bus_skew -warn_on_violation -return_string -file [file join $report_dir bus_skew_placed_failure.rpt]]
set skew_met [regexp -all {Slack \(MET\)} $skew]
set skew_violated [regexp -all {Slack \(VIOLATED\)} $skew]
set por_endpoints {}
foreach path [get_timing_paths -quiet -delay_type max -slack_lesser_than 0 -max_paths 10000 -nworst 1] {
  set cell [get_cells -quiet -of_objects [get_property ENDPOINT_PIN $path]]
  set endpoint_name [get_property NAME $cell]
  if {[regexp -nocase {(por|resetn).*reg|reg.*(por|resetn)} $endpoint_name]} {lappend por_endpoints $endpoint_name}
}
puts $out "boundary_location_failures=[llength $boundary_failures] $boundary_failures"
puts $out "controller_reducer_locality_failures=[llength $locality_failures] first=[lrange $locality_failures 0 99]"
puts $out "setup WNS=$wns TNS=$tns failing_endpoints=$setup_failed"
puts $out "hold WHS=$whs THS=$ths failing_endpoints=$hold_failed"
puts $out "references KEEP_HIER placed=-1.089/-605.050/1743; baseline routed=-1.277/-1517.198/4916"
puts $out "bus_skew met=$skew_met violated=$skew_violated"
puts $out "POR_or_reset_significant_endpoints=[llength $por_endpoints] first=[lrange $por_endpoints 0 99]"
puts $out "FAIL: mandatory 7/7/7/7 placed control-register inventory not preserved; no phys_opt/route"
close $out
report_timing -delay_type max -max_paths 500 -file [file join $report_dir critical_paths_placed_failure.rpt]
file copy -force $placed [file join $archive ${name}_slr_bank_placed_failed.dcp]
file copy -force [file join $run_dir runme.log] [file join $archive placement_runme.log]
foreach f [glob -nocomplain -directory $report_dir *failure*] {if {[file isfile $f]} {file copy -force $f [file join $archive [file tail $f]]}}
set status [open [file join $archive final_status.txt] w]
puts $status "FAILED placement structural gate; no phys_opt/route/bit/audit"
puts $status "placed DCP SHA-256 [lindex [split [exec sha256sum $placed]] 0]"
close $status
puts "ARCHIVED: all-links v1 SLR-bank placement structural failure; route not permitted"
