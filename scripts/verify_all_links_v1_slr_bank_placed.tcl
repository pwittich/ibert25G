set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set report_dir [file join $repo_dir build all_links_v1_reports slr_bank]
file mkdir $report_dir
proc cell_slr {cell} {
  set sites [get_sites -quiet -of_objects $cell]
  if {[llength $sites] != 1} {return ""}
  set slrs [get_slrs -quiet -of_objects $sites]
  if {[llength $slrs] != 1} {return ""}
  return [get_property NAME [lindex $slrs 0]]
}
set out [open [file join $report_dir placement_gate.rpt] w]
set expected_counts {6 8 8 6}
set locality_failures {}
set boundary_failures {}
set boundary_total 0
set controller_total 0
set reducer_total 0
for {set slr 0} {$slr < 4} {incr slr} {
  set bank [get_cells -hier -quiet -filter "NAME =~ *g_bank_slr$slr && REF_NAME =~ all_links_v1_slr_bank*"]
  if {[llength $bank] != 1} {close $out; error "Missing placed bank SLR$slr"}
  set bank_name [get_property NAME $bank]
  set controls [get_cells -hier -quiet -filter "NAME =~ ${bank_name}/u_control_pipeline/controls_out_reg* && REF_NAME =~ FD*"]
  set reset_reg [get_cells -hier -quiet -filter "NAME == ${bank_name}/local_resetn_reg && REF_NAME =~ FD*"]
  set boundary [concat $controls $reset_reg]
  if {[llength $controls] != 7 || [llength $reset_reg] != 1} {
    close $out; error "SLR$slr boundary inventory [llength $controls]/[llength $reset_reg], expected 7/1"
  }
  foreach cell $boundary {
    incr boundary_total
    set actual [cell_slr $cell]
    if {$actual ne "SLR$slr"} {lappend boundary_failures [list [get_property NAME $cell] expected=SLR$slr actual=$actual]}
  }
  set roots [get_cells -hier -quiet -filter "NAME =~ ${bank_name}/*/u_prbs_test_controller && REF_NAME =~ gt_prbs_test_controller*"]
  if {[llength $roots] != [lindex $expected_counts $slr]} {
    close $out; error "SLR$slr controller roots [llength $roots], expected [lindex $expected_counts $slr]"
  }
  set reducer_prefix "${bank_name}/u_local_aggregate/"
  set reducer_leaves [get_cells -hier -quiet -filter "NAME =~ ${reducer_prefix}* && IS_PRIMITIVE"]
  if {![llength $reducer_leaves]} {close $out; error "SLR$slr local reducer has no placed leaves"}
  foreach cell $reducer_leaves {
    incr reducer_total
    set ref [get_property REF_NAME $cell]
    if {$ref in {VCC GND}} {continue}
    set actual [cell_slr $cell]
    if {$actual ne "SLR$slr"} {lappend locality_failures [list REDUCER [get_property NAME $cell] expected=SLR$slr actual=$actual]}
  }
  foreach root $roots {
    set leaves [get_cells -hier -quiet -filter "NAME =~ [get_property NAME $root]/* && IS_PRIMITIVE"]
    if {![llength $leaves]} {close $out; error "Controller root has no leaves: $root"}
    foreach cell $leaves {
      incr controller_total
      set ref [get_property REF_NAME $cell]
      if {$ref in {VCC GND}} {continue}
      set actual [cell_slr $cell]
      if {$actual ne "SLR$slr"} {lappend locality_failures [list CONTROLLER [get_property NAME $cell] expected=SLR$slr actual=$actual]}
    }
  }
}
set timing [report_timing_summary -delay_type min_max -max_paths 100 -report_unconstrained \
  -return_string -file [file join $report_dir timing_placed.rpt]]
if {![regexp {Setup\s*:\s*([0-9]+)\s+Failing Endpoints,\s+Worst Slack\s+([-0-9.]+)ns,\s+Total Violation\s+([-0-9.]+)ns} $timing -> setup_failed wns tns]} {
  close $out; error "Cannot parse placed setup summary"
}
set skew [report_bus_skew -warn_on_violation -return_string -file [file join $report_dir bus_skew_placed.rpt]]
set skew_groups [regexp -all {Slack \((?:MET|VIOLATED)\)} $skew]
set skew_violated [regexp -all {Slack \(VIOLATED\)} $skew]
set failing_paths [get_timing_paths -quiet -delay_type max -slack_lesser_than 0 -max_paths 10000 -nworst 1]
set por_endpoints {}
set reentries {}
foreach path $failing_paths {
  set start_pin [get_property STARTPOINT_PIN $path]
  set end_pin [get_property ENDPOINT_PIN $path]
  set start_cell [get_cells -quiet -of_objects $start_pin]
  set end_cell [get_cells -quiet -of_objects $end_pin]
  set end_name [get_property NAME $end_cell]
  if {[regexp -nocase {(por|resetn).*reg|reg.*(por|resetn)} $end_name]} {lappend por_endpoints $end_name}
  set start_name [get_property NAME $start_cell]
  for {set slr 0} {$slr < 4} {incr slr} {
    if {![string match "*g_bank_slr${slr}/*u_prbs_test_controller*" $start_name]} {continue}
    if {![string match "*g_bank_slr${slr}/*" $end_name]} {continue}
    foreach point [get_property POINTS $path] {
      set obj [get_property OBJECT $point]
      set cell [get_cells -quiet -of_objects $obj]
      if {[llength $cell] != 1 || [get_property REF_NAME $cell] in {VCC GND}} {continue}
      set actual [cell_slr $cell]
      if {$actual ne "" && $actual ne "SLR$slr"} {
        lappend reentries [list [get_property NAME $path] start=$start_name endpoint=$end_name escaped=[get_property NAME $cell] actual=$actual]
        break
      }
    }
  }
}
report_timing -delay_type max -max_paths 500 -file [file join $report_dir critical_paths_placed.rpt]
puts $out "boundary registers $boundary_total failures [llength $boundary_failures]"
puts $out "controller leaves $controller_total reducer leaves $reducer_total locality failures [llength $locality_failures]"
puts $out "setup WNS $wns ns TNS $tns ns failing endpoints $setup_failed"
puts $out "reference KEEP_HIER placement WNS -1.089 ns TNS -605.050 ns failing endpoints 1743"
puts $out "reference baseline routed WNS -1.277 ns TNS -1517.198 ns failing endpoints 4916"
puts $out "bus-skew groups $skew_groups violations $skew_violated"
puts $out "global-POR/reset significant failing endpoints [llength $por_endpoints]"
puts $out "controller-SLR exit/reentry failures [llength $reentries]"
puts $out "boundary failures $boundary_failures"
puts $out "locality failures [lrange $locality_failures 0 49]"
puts $out "POR/reset endpoints [lrange $por_endpoints 0 49]"
puts $out "reentries [lrange $reentries 0 49]"
set structural_ok [expr {$boundary_total == 32 && ![llength $boundary_failures] && ![llength $locality_failures] && ![llength $reentries]}]
set constraint_ok [expr {$skew_groups == 28 && $skew_violated == 0}]
set endpoint_ok [expr {![llength $por_endpoints]}]
set timing_ok [expr {$wns > -0.989 && $tns > -605.050 && $setup_failed < 1743}]
puts $out "categories structural=$structural_ok constraints=$constraint_ok reset_endpoint=$endpoint_ok timing=$timing_ok"
if {!$structural_ok || !$constraint_ok || !$endpoint_ok || !$timing_ok} {
  close $out
  error "All-links SLR-bank placement gate failed: structural=$structural_ok constraints=$constraint_ok reset_endpoint=$endpoint_ok timing=$timing_ok"
}
puts $out "PASS: credible multi-category placement improvement; phys-opt/route permitted"
close $out
puts "PASS: all-links v1 SLR-bank placement gate WNS=$wns TNS=$tns endpoints=$setup_failed"
