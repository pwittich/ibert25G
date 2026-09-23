set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
if {![info exists ::all_links_slr_report_dir]} {set ::all_links_slr_report_dir [file join $repo_dir build all_links_v1_reports slr_bank_closeout_route]}
set report_dir $::all_links_slr_report_dir
file mkdir $report_dir
proc closeout_cell_slr {cell} {
  set sites [get_sites -quiet -of_objects $cell]
  if {[llength $sites] != 1} {return ""}
  set slrs [get_slrs -quiet -of_objects $sites]
  if {[llength $slrs] != 1} {return ""}
  return [get_property NAME [lindex $slrs 0]]
}
set timing [report_timing_summary -delay_type min_max -max_paths 100 -report_unconstrained -return_string -file [file join $report_dir timing_routed.rpt]]
if {![regexp {Setup\s*:\s*([0-9]+)\s+Failing Endpoints,\s+Worst Slack\s+([-0-9.]+)ns,\s+Total Violation\s+([-0-9.]+)ns} $timing -> setup_failed wns tns] ||
    ![regexp {Hold\s*:\s*([0-9]+)\s+Failing Endpoints,\s+Worst Slack\s+([-0-9.]+)ns,\s+Total Violation\s+([-0-9.]+)ns} $timing -> hold_failed whs ths]} {error "Cannot parse routed timing"}
# The report's complete Intra Clock Table is the bounded, authoritative
# per-group evidence.  Do not issue hundreds of individual get_timing_paths
# queries against the 112 GT clock groups.
set group_out [open [file join $report_dir timing_by_clock_group.rpt] w]
set in_table 0; set group_failures {}
foreach line [split $timing "\n"] {
  if {[string match {*Intra Clock Table*} $line]} {set in_table 1}
  if {$in_table} {puts $group_out $line}
  if {$in_table && [regexp {^\s*(\S+)\s+(-[0-9.]+)\s+(-?[0-9.]+)\s+([0-9]+)} $line -> group group_wns group_tns group_setup_failed]} {
    lappend group_failures $group
  }
  if {$in_table && [string match {*Inter Clock Table*} $line]} {break}
}
close $group_out
set routing [report_route_status -return_string -file [file join $report_dir route_status_routed.rpt]]
if {![regexp {# of routable nets[. ]*:[ ]*([0-9]+)} $routing -> routable] ||
    ![regexp {# of fully routed nets[. ]*:[ ]*([0-9]+)} $routing -> fully_routed] ||
    ![regexp {# of nets with routing errors[. ]*:[ ]*([0-9]+)} $routing -> routing_errors] ||
    $routable != $fully_routed || $routing_errors != 0} {
  error "Routed net status is not clean: routable=$routable fully=$fully_routed errors=$routing_errors"
}
set skew [report_bus_skew -warn_on_violation -return_string -file [file join $report_dir bus_skew_routed.rpt]]
if {[regexp -all {Slack \(MET\)} $skew] != 28 || [string match {*VIOLATED*} $skew]} {error "Expected 28 passing bus-skew groups"}
report_drc -file [file join $report_dir drc_routed.rpt]
foreach violation [get_drc_violations -quiet] {if {[get_property SEVERITY $violation] eq "Error"} {error "DRC error $violation"}}
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {error "Compression disabled"}
foreach {pattern expected} {
  {REF_NAME == GTYE4_CHANNEL && IS_PRIMITIVE} 112
  {REF_NAME == GTYE4_COMMON && IS_PRIMITIVE} 28
  {REF_NAME == IBUFDS_GTE4 && IS_PRIMITIVE && NAME =~ *u_refclk_buffers*} 12
  {NAME =~ */u_prbs_test_controller && REF_NAME =~ gt_prbs_test_controller*} 28
  {NAME =~ *session_meta_reg && REF_NAME =~ FD*} 28
  {NAME =~ *session_sync_reg && REF_NAME =~ FD*} 28
  {NAME =~ *session_applied_meta_reg && REF_NAME =~ FD*} 28
  {NAME =~ *session_applied_sync_reg && REF_NAME =~ FD*} 28
} {
  set cells [get_cells -hier -quiet -filter $pattern]
  if {[llength $cells] != $expected} {error "Inventory '$pattern' is [llength $cells], expected $expected"}
}
set expected_indices {0 2 3 4 5 6}; set expected_counts {6 8 8 6}
for {set slr 0} {$slr < 4} {incr slr} {
  set bank [get_cells -hier -quiet -filter "NAME =~ *g_bank_slr$slr && REF_NAME =~ all_links_v1_slr_bank*"]
  if {[llength $bank] != 1 || ![string equal -nocase [get_property USER_SLR_ASSIGNMENT $bank] "SLR$slr"]} {error "SLR$slr bank mismatch"}
  set name [get_property NAME $bank]
  set controls [get_cells -hier -quiet -filter "NAME =~ ${name}/u_control_pipeline/controls_out_reg* && REF_NAME =~ FD*"]
  set indices {}; foreach cell $controls {if {![regexp {controls_out_reg\[([0-9]+)\]$} [get_property NAME $cell] -> i]} {error "Bad control name $cell"}; lappend indices $i}; set indices [lsort -integer $indices]
  set reset [get_cells -hier -quiet -filter "NAME == ${name}/local_resetn_reg && REF_NAME =~ FD*"]
  if {$indices ne $expected_indices || [llength $reset] != 1} {error "SLR$slr boundary inventory $indices/[llength $reset]"}
  foreach cell [concat $controls $reset] {if {[closeout_cell_slr $cell] ne "SLR$slr"} {error "SLR$slr boundary escaped: $cell"}}
  set loads [get_pins -quiet -leaf -of_objects [get_nets -quiet -of_objects [get_pins -quiet -of_objects $reset -filter {REF_PIN_NAME == Q}]] -filter {DIRECTION == IN}]
  foreach load $loads {if {![string match "${name}/*" [get_property NAME $load]]} {error "SLR$slr reset escapes bank: $load"}}
  set roots [get_cells -hier -quiet -filter "NAME =~ ${name}/*/u_prbs_test_controller && REF_NAME =~ gt_prbs_test_controller*"]
  if {[llength $roots] != [lindex $expected_counts $slr]} {error "SLR$slr controller ownership [llength $roots]"}
  # Any cross-SLR controller leaf is allowed only on exact-error publication,
  # whose fanout is either another exact-count publication register or engine copy.
  foreach root $roots {
    set root_name [get_property NAME $root]
    foreach cell [get_cells -hier -quiet -filter "NAME =~ ${root_name}/* && IS_PRIMITIVE"] {
      set actual [closeout_cell_slr $cell]
      if {[get_property REF_NAME $cell] in {VCC GND} || $actual eq "" || $actual eq "SLR$slr"} {continue}
      set cname [get_property NAME $cell]
      if {![regexp {/exact_error_counts} $cname] && ![regexp {/i___[0-9]+$} $cname]} {error "Non-publication controller escape: $cname"}
      foreach ep [all_fanout -quiet -flat -endpoints_only -from [get_pins -quiet -of_objects $cell -filter {DIRECTION == OUT}]] {
        set ename [get_property NAME $ep]
        if {[string first "${root_name}/exact_error_counts_reg" $ename] != 0 && [string first "/u_engine/u_core/copy_record_stage_reg" $ename] < 0} {error "Controller escape feeds back: $cname -> $ename"}
      }
    }
  }
}
foreach pattern {all_links_v1_quads_slr* all_links_v1_locality_slr* all_links_v1_kh_locality_slr*} {if {[llength [get_pblocks -quiet $pattern]]} {error "Obsolete pblock $pattern"}}
if {$setup_failed != 0 || $hold_failed != 0 || $wns < 0 || $whs < 0 || [llength $group_failures]} {
  error "Routed timing failed: setup=$wns/$tns/$setup_failed hold=$whs/$ths/$hold_failed groups=$group_failures"
}
puts "PASS: routed closeout gate setup=$wns/$tns hold=$whs/$ths, zero endpoints, 28 skew groups, clean route/DRC and exact topology"
