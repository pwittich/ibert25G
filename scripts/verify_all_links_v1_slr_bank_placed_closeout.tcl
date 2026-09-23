# Correct post-opt/placed gate for the all-links-v1 SLR-bank experiment.
# Synthesis retains all seven pipeline outputs.  After opt_design bit 1 is
# intentionally absent because it only feeds controllers built with the
# constant-zero runtime detector.  Lane engines consume the global engine
# measurement control independently.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
if {![info exists ::all_links_slr_report_dir]} {
  set ::all_links_slr_report_dir [file join $repo_dir build all_links_v1_reports slr_bank_closeout]
}
set report_dir $::all_links_slr_report_dir
file mkdir $report_dir

proc all_links_cell_slr {cell} {
  set sites [get_sites -quiet -of_objects $cell]
  if {[llength $sites] != 1} {return ""}
  set slrs [get_slrs -quiet -of_objects $sites]
  if {[llength $slrs] != 1} {return ""}
  return [get_property NAME [lindex $slrs 0]]
}
proc all_links_control_index {cell} {
  set name [get_property NAME $cell]
  if {![regexp {controls_out_reg\[([0-9]+)\]$} $name -> index]} {error "Cannot decode control index: $name"}
  return $index
}

set out [open [file join $report_dir corrected_placement_gate.rpt] w]
set expected_counts {6 8 8 6}
set expected_control_indices {0 2 3 4 5 6}
set boundary_failures {}; set publication_failures {}; set publication_escapes {}
set controller_total 0; set reducer_total 0; set constrained_publication_paths 0
set banks [get_cells -hier -quiet -filter {REF_NAME =~ all_links_v1_slr_bank*}]
if {[llength $banks] != 4} {close $out; error "Bank count [llength $banks], expected 4"}
foreach bank $banks {
  if {![string equal -nocase [get_property KEEP_HIERARCHY $bank] yes] &&
      ![string equal -nocase [get_property KEEP_HIERARCHY $bank] true]} {close $out; error "Bank lacks KEEP_HIERARCHY: $bank"}
  if {[string equal -nocase [get_property DONT_TOUCH $bank] true]} {close $out; error "Forbidden bank DONT_TOUCH: $bank"}
}
foreach pattern {all_links_v1_quads_slr* all_links_v1_locality_slr* all_links_v1_kh_locality_slr*} {
  if {[llength [get_pblocks -quiet $pattern]]} {close $out; error "Obsolete pblock remains: $pattern"}
}

for {set slr 0} {$slr < 4} {incr slr} {
  set bank [get_cells -hier -quiet -filter "NAME =~ *g_bank_slr$slr && REF_NAME =~ all_links_v1_slr_bank*"]
  if {[llength $bank] != 1} {close $out; error "Missing unique bank SLR$slr"}
  set bank_name [get_property NAME $bank]
  if {![string equal -nocase [get_property USER_SLR_ASSIGNMENT $bank] "SLR$slr"]} {close $out; error "SLR$slr soft assignment mismatch"}
  set controls [get_cells -hier -quiet -filter "NAME =~ ${bank_name}/u_control_pipeline/controls_out_reg* && REF_NAME =~ FD*"]
  set indices {}; foreach cell $controls {lappend indices [all_links_control_index $cell]}; set indices [lsort -integer $indices]
  set reset_reg [get_cells -hier -quiet -filter "NAME == ${bank_name}/local_resetn_reg && REF_NAME =~ FD*"]
  if {$indices ne $expected_control_indices || [llength $reset_reg] != 1} {close $out; error "SLR$slr boundary indices/reset=$indices/[llength $reset_reg]"}
  foreach cell [concat $controls $reset_reg] {
    if {[all_links_cell_slr $cell] ne "SLR$slr"} {lappend boundary_failures [list [get_property NAME $cell] [all_links_cell_slr $cell]]}
  }
  set reset_q [get_pins -quiet -of_objects $reset_reg -filter {REF_PIN_NAME == Q}]
  set reset_loads [get_pins -quiet -leaf -of_objects [get_nets -quiet -of_objects $reset_q] -filter {DIRECTION == IN}]
  if {![llength $reset_loads]} {close $out; error "SLR$slr local reset has no loads"}
  foreach load $reset_loads {if {![string match "${bank_name}/*" [get_property NAME $load]]} {close $out; error "SLR$slr reset escapes: $load"}}

  set roots [get_cells -hier -quiet -filter "NAME =~ ${bank_name}/*/u_prbs_test_controller && REF_NAME =~ gt_prbs_test_controller*"]
  if {[llength $roots] != [lindex $expected_counts $slr]} {close $out; error "SLR$slr controller ownership [llength $roots]"}
  foreach root $roots {
    set root_name [get_property NAME $root]
    foreach cell [get_cells -hier -quiet -filter "NAME =~ ${root_name}/* && IS_PRIMITIVE"] {
      incr controller_total
      if {[get_property REF_NAME $cell] in {VCC GND}} {continue}
      set actual [all_links_cell_slr $cell]
      if {$actual eq "" || $actual eq "SLR$slr"} {continue}
      set name [get_property NAME $cell]
      set outs [get_pins -quiet -of_objects $cell -filter {DIRECTION == OUT}]
      set endpoints [all_fanout -quiet -flat -endpoints_only -from $outs]
      if {[regexp {/exact_error_counts\[[0-9]+\]_i_} $name] || [regexp {/i___[0-9]+$} $name]} {
        foreach endpoint $endpoints {if {[string first "${root_name}/exact_error_counts_reg" [get_property NAME $endpoint]] != 0} {lappend publication_failures [list $name unexpected_endpoint=$endpoint]}}
      } elseif {[regexp {/exact_error_counts_reg\[[0-9]+\]$} $name]} {
        foreach endpoint $endpoints {if {[string first "/u_engine/u_core/copy_record_stage_reg" [get_property NAME $endpoint]] < 0} {lappend publication_failures [list $name unexpected_endpoint=$endpoint]}}
      } else {lappend publication_failures [list $name unexpected_controller_escape=$actual]}
      if {![llength $endpoints]} {lappend publication_failures [list $name no_endpoint]}
      foreach endpoint $endpoints {
        set paths [get_timing_paths -quiet -to $endpoint -max_paths 1]
        if {![llength $paths] || [get_property REQUIREMENT [lindex $paths 0]] eq ""} {lappend publication_failures [list $name untimed_endpoint=$endpoint]} else {incr constrained_publication_paths}
      }
      lappend publication_escapes [list CONTROLLER $name expected=SLR$slr actual=$actual endpoints=$endpoints]
    }
  }
  foreach cell [get_cells -hier -quiet -filter "NAME =~ ${bank_name}/u_local_aggregate/* && IS_PRIMITIVE"] {
    incr reducer_total
    if {[get_property REF_NAME $cell] in {VCC GND}} {continue}
    set actual [all_links_cell_slr $cell]
    if {$actual eq "" || $actual eq "SLR$slr"} {continue}
    set name [get_property NAME $cell]; set outs [get_pins -quiet -of_objects $cell -filter {DIRECTION == OUT}]
    set endpoints [all_fanout -quiet -flat -endpoints_only -from $outs]
    if {![string match "*/diagnostics_reg*" $name] && ![string match "*/quad_fault_reg*" $name]} {lappend publication_failures [list $name unexpected_reducer_escape=$actual]}
    foreach endpoint $endpoints {
      if {![string match "*/g_all_links.u_quad_aggregate/*/D" [get_property NAME $endpoint]]} {lappend publication_failures [list $name unexpected_endpoint=$endpoint]}
      set paths [get_timing_paths -quiet -from $outs -to $endpoint -max_paths 1]
      if {![llength $paths] || [get_property REQUIREMENT [lindex $paths 0]] eq ""} {lappend publication_failures [list $name untimed_endpoint=$endpoint]} else {incr constrained_publication_paths}
    }
    lappend publication_escapes [list REDUCER $name expected=SLR$slr actual=$actual endpoints=$endpoints]
  }
  puts $out "SLR$slr controls=$indices reset=1 controllers=[llength $roots] reset_loads=[llength $reset_loads]"
}

set timing [report_timing_summary -delay_type min_max -max_paths 100 -report_unconstrained -return_string -file [file join $report_dir timing_placed_corrected.rpt]]
if {![regexp {Setup\s*:\s*([0-9]+)\s+Failing Endpoints,\s+Worst Slack\s+([-0-9.]+)ns,\s+Total Violation\s+([-0-9.]+)ns} $timing -> setup_failed wns tns] ||
    ![regexp {Hold\s*:\s*([0-9]+)\s+Failing Endpoints,\s+Worst Slack\s+([-0-9.]+)ns,\s+Total Violation\s+([-0-9.]+)ns} $timing -> hold_failed whs ths]} {close $out; error "Cannot parse placed timing"}
set skew [report_bus_skew -warn_on_violation -return_string -file [file join $report_dir bus_skew_placed_corrected.rpt]]
set skew_met [regexp -all {Slack \(MET\)} $skew]; set skew_violated [regexp -all {Slack \(VIOLATED\)} $skew]
set por_endpoints {}
foreach path [get_timing_paths -quiet -delay_type max -slack_lesser_than 0 -max_paths 10000 -nworst 1] {
  set end_cell [get_cells -quiet -of_objects [get_property ENDPOINT_PIN $path]]
  if {[regexp -nocase {(por|resetn).*reg|reg.*(por|resetn)} [get_property NAME $end_cell]]} {lappend por_endpoints [get_property NAME $end_cell]}
}
report_timing -delay_type max -max_paths 500 -file [file join $report_dir critical_paths_placed_corrected.rpt]
puts $out "controller_leaves=$controller_total reducer_leaves=$reducer_total"
puts $out "publication_escapes=[llength $publication_escapes] constrained_publication_paths=$constrained_publication_paths"
puts $out "publication_escape_detail=$publication_escapes"
puts $out "boundary_failures=$boundary_failures publication_failures=$publication_failures"
puts $out "setup WNS=$wns TNS=$tns endpoints=$setup_failed; hold WHS=$whs THS=$ths endpoints=$hold_failed"
puts $out "bus_skew_met=$skew_met violated=$skew_violated POR_endpoints=[llength $por_endpoints]"
puts $out "interpretation=control_bit_1_is_constant_disabled_runtime_detector_feed; publication_escapes_do_not_feed_controllers"
set structural_ok [expr {![llength $boundary_failures] && ![llength $publication_failures] && [llength $publication_escapes] == 47}]
set timing_improved [expr {$wns > -1.089 && $setup_failed < 1743 && $tns > -605.050}]
set pass [expr {$structural_ok && $timing_improved && $skew_met == 28 && $skew_violated == 0 && ![llength $por_endpoints]}]
puts $out "categories structural=$structural_ok timing_improved=$timing_improved skew=[expr {$skew_met == 28 && $skew_violated == 0}] POR_clear=[expr {![llength $por_endpoints]}]"
if {!$pass} {close $out; error "Corrected SLR-bank placement gate failed"}
puts $out "PASS: corrected placed gate; default phys_opt_design and route_design permitted exactly once"
close $out
puts "PASS: corrected SLR-bank placed gate WNS=$wns TNS=$tns setup_endpoints=$setup_failed WHS=$whs hold_endpoints=$hold_failed"
