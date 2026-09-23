set repo [file dirname [file dirname [file normalize [info script]]]]
set dcp [file join $repo build gt_test_direct_all_v7r3 gt_test_direct_all_v7r3_routed.dcp]
open_checkpoint $dcp

set report [open [file join $repo build direct_all_v7_reports routed_locality.tsv] w]
puts $report "kind\tquad\tname\tref\tsite\tslr"
for {set q 0} {$q < 14} {incr q} {
  set prefix [format {u_all_direct/g_all_direct.g_quad[%d].u_managed_direct/} $q]
  set cells [get_cells -hier -quiet -filter "NAME =~ ${prefix}*"]
  array unset counts
  foreach cell $cells {
    if {[get_property IS_PRIMITIVE $cell] && [get_property REF_NAME $cell] ni {
      GTYE4_CHANNEL GTYE4_COMMON}} {
      set slr [get_property -quiet SLR $cell]
      if {$slr eq ""} {set slr NONE}
      if {![info exists counts($slr)]} {set counts($slr) 0}
      incr counts($slr)
    }
  }
  foreach slr [lsort [array names counts]] {
    puts $report "wrapper_soft_count\t$q\t-\t-\t-\t$slr:$counts($slr)"
  }
  foreach suffix {u_prbs_test_controller/state_reg[0]
                  u_prbs_test_controller/lock_seen_reg[0]
                  u_prbs_test_controller/exact_error_counts_reg[0]} {
    set wanted "${prefix}${suffix}"
    set cell [get_cells -quiet [list $wanted]]
    if {[llength $cell] == 1} {
      puts $report "sample\t$q\t$wanted\t[get_property REF_NAME $cell]\t[get_property SITE $cell]\t[get_property SLR $cell]"
    }
  }
}
foreach wanted {
  u_all_direct/u_engine/u_core/state_reg[0]
  u_all_direct/u_engine/u_core/measurement_active_reg
  u_all_direct/u_engine/u_core/active_prbs_mode_reg[0]
  u_all_direct/u_engine/u_core/active_lane_mask_reg[111]
} {
  set cell [get_cells -quiet [list $wanted]]
  if {[llength $cell] == 1} {
    puts $report "source\t-\t$wanted\t[get_property REF_NAME $cell]\t[get_property SITE $cell]\t[get_property SLR $cell]"
  }
}
close $report
report_timing -delay_type max -max_paths 30 -sort_by group \
  -file [file join $repo build direct_all_v7_reports routed_top30_diagnostic.rpt]
puts "PASS: wrote routed locality and top-30 path diagnostics"
