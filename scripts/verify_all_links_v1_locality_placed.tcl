# Placement-time proof for the enumerated-leaf all-links v1 locality attempt.
# Re-expand every canonical pblock root and verify every optimized primitive.

set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set report_dir [file join $repo_dir build all_links_v1_reports locality_attempt]
file mkdir $report_dir
proc locality_slr_for_index {index modulus} {
  set within [expr {$index % $modulus}]
  return [expr {$within < 12 ? 0 : $within < 28 ? 1 : $within < 44 ? 2 : 3}]
}
proc locality_regexp_quote {value} {
  regsub -all {[][{}().^$*+?|\\]} $value {\\&} quoted
  return $quoted
}

set out [open [file join $report_dir locality_placement.rpt] w]
puts $out "All-links v1 canonical-root re-expansion placement proof"
puts $out "design [current_design]"
set expected_roots [dict create controller {6 8 8 6} engine {24 32 32 24} \
  pwrgood {24 32 32 24} reducer {1 1 1 1}]
set observed_roots [dict create]
set leaf_counts [dict create]
set seen_roots [dict create]
set seen_leaves [dict create]
set empty_roots {}
set duplicate_roots {}
set duplicate_leaves {}
set misplaced {}
set nonplaceable_constants {}
set mixed_roots {}
set hard_hits {}
set pwrgood_support_hits {}
set reset_hits {}
set unexpected_roots {}

for {set pblock_slr 0} {$pblock_slr < 4} {incr pblock_slr} {
  set pb [get_pblocks all_links_v1_locality_slr$pblock_slr]
  set roots [get_cells -quiet -of_objects $pb]
  puts $out "SLR$pblock_slr canonical roots [llength $roots]"
  foreach root $roots {
    set root_name [get_property NAME $root]
    set ref [get_property REF_NAME $root]
    if {[dict exists $seen_roots $root_name]} {
      lappend duplicate_roots [list $root_name [dict get $seen_roots $root_name] $pblock_slr]
    }
    dict set seen_roots $root_name $pblock_slr
    set family {}
    set expected -1
    if {[string match gt_prbs_test_controller* $ref] &&
        [regexp {g_(left|right)_quad\[([0-9]+)\]} $root_name -> side q]} {
      set family controller
      set expected [locality_slr_for_index [expr {4*$q}] 56]
    } elseif {[string match gt_lane_engine* $ref] &&
        [regexp {g_lane\[([0-9]+)\]} $root_name -> lane]} {
      set family engine
      set expected [locality_slr_for_index $lane 56]
    } elseif {[string match direct_all_v7_quad_group_aggregate* $ref] &&
        [regexp {u_quad_aggregate/g_slr([0-3])$} $root_name -> expected]} {
      set family reducer
    } elseif {[string match *gen_pwrgood_delay_inst* $root_name] &&
        [string match *.delay_powergood_inst $root_name] &&
        [regexp {g_(left|right)_quad\[([0-9]+)\]} $root_name -> side q]} {
      set family pwrgood
      set expected [locality_slr_for_index [expr {4*$q}] 56]
    } else {
      lappend unexpected_roots [list $root_name $ref]
      continue
    }
    dict incr observed_roots "$family,$expected"
    if {$expected != $pblock_slr} {
      lappend misplaced [list ROOT $root_name expected=SLR$expected pblock=SLR$pblock_slr]
    }
    set pattern "^[locality_regexp_quote $root_name]/.*$"
    set leaves [get_cells -hier -regexp -quiet -filter {IS_PRIMITIVE} $pattern]
    if {[llength $leaves] == 0} {lappend empty_roots $root_name}
    dict incr leaf_counts $family [llength $leaves]
    set root_actual_slrs {}
    foreach cell $leaves {
      set name [get_property NAME $cell]
      if {[dict exists $seen_leaves $name]} {
        lappend duplicate_leaves [list $name [dict get $seen_leaves $name] $root_name]
      }
      dict set seen_leaves $name $root_name
      set cref [get_property REF_NAME $cell]
      if {[string match GTYE4_* $cref] || [string match BUFG* $cref] ||
          [string match IBUFDS_GTE4 $cref]} {lappend hard_hits $name}
      if {$family eq "pwrgood" && ([string match *session* $name] ||
          [string match *native* $name] || [string match *reset_tree* $name])} {
        lappend pwrgood_support_hits $name
      }
      if {[string match *power_on_reset_reg* $name] || [string match *reset_tree* $name]} {
        lappend reset_hits $name
      }
      set sites [get_sites -quiet -of_objects $cell]
      set actual_slrs [get_slrs -quiet -of_objects $sites]
      if {[llength $sites] != 1 || [llength $actual_slrs] != 1} {
        if {$cref in {GND VCC}} {
          lappend nonplaceable_constants $name
          continue
        }
        lappend misplaced [list LEAF $name expected=SLR$expected actual=UNPLACED]
        lappend root_actual_slrs UNPLACED
        continue
      }
      set actual [get_property NAME [lindex $actual_slrs 0]]
      lappend root_actual_slrs $actual
      if {$actual ne "SLR$expected"} {
        lappend misplaced [list LEAF $name expected=SLR$expected actual=$actual]
      }
    }
    set root_unique [lsort -unique $root_actual_slrs]
    if {[llength $root_unique] != 1} {lappend mixed_roots [list $root_name $root_unique]}
  }
}

set count_failures {}
foreach family {controller engine pwrgood reducer} {
  set family_total 0
  for {set slr 0} {$slr < 4} {incr slr} {
    set observed 0
    if {[dict exists $observed_roots "$family,$slr"]} {set observed [dict get $observed_roots "$family,$slr"]}
    set expected [lindex [dict get $expected_roots $family] $slr]
    puts $out "$family SLR$slr roots $observed expected $expected"
    if {$observed != $expected} {lappend count_failures "$family SLR$slr roots $observed expected $expected"}
    incr family_total $observed
  }
  set leaves 0
  if {[dict exists $leaf_counts $family]} {set leaves [dict get $leaf_counts $family]}
  puts $out "$family roots $family_total optimized primitive leaves $leaves"
}
puts $out "canonical root union [dict size $seen_roots] duplicate roots [llength $duplicate_roots]"
puts $out "optimized leaf union [dict size $seen_leaves] duplicate leaves [llength $duplicate_leaves]"
puts $out "empty roots [llength $empty_roots]"
puts $out "misplaced/unplaced root or leaf entries [llength $misplaced]"
puts $out "non-placeable VCC/GND pseudo-primitives [llength $nonplaceable_constants]"
puts $out "mixed-SLR roots [llength $mixed_roots]"
puts $out "internal cross-SLR constrained-root endpoint pairs 0 when mixed-SLR roots is zero"
puts $out "excluded GT/GT-common/BUFG/REFCLK primitives [llength $hard_hits]"
puts $out "excluded pwrgood session/native/reset-tree leaves [llength $pwrgood_support_hits]"
puts $out "excluded global-reset leaves [llength $reset_hits]"
puts $out "root-count failures $count_failures"
puts $out "unexpected roots $unexpected_roots"
puts $out "duplicate roots $duplicate_roots"
puts $out "duplicate leaves $duplicate_leaves"
puts $out "empty roots $empty_roots"
puts $out "mixed roots $mixed_roots"
puts $out "first 100 misplaced entries [lrange $misplaced 0 99]"
if {[llength $count_failures] != 0 || [llength $unexpected_roots] != 0 ||
    [llength $duplicate_roots] != 0 || [llength $duplicate_leaves] != 0 ||
    [llength $empty_roots] != 0 || [llength $misplaced] != 0 ||
    [llength $mixed_roots] != 0 || [llength $hard_hits] != 0 ||
    [llength $pwrgood_support_hits] != 0 || [llength $reset_hits] != 0} {
  close $out
  error "All-links v1 canonical-root placement proof failed"
}
puts $out "PASS: every optimized primitive descendant of every constrained root is in its expected SLR"
close $out
puts "PASS: all-links v1 locality placement proof; [dict size $seen_leaves] leaves, zero mixed roots"
