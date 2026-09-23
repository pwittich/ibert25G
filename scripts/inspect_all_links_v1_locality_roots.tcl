set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set dcp [file join $repo_dir build gt_test_all_links_v1 gt_test_all_links_v1_synth.dcp]
open_checkpoint $dcp

proc locality_slr_for_index {index modulus} {
  set within [expr {$index % $modulus}]
  return [expr {$within < 12 ? 0 : $within < 28 ? 1 : $within < 44 ? 2 : 3}]
}

set controllers [get_cells -hier -quiet -filter {REF_NAME =~ gt_prbs_test_controller*}]
set engines [get_cells -hier -quiet -filter {REF_NAME =~ gt_lane_engine*}]
set reducers [get_cells -hier -quiet -filter {
  REF_NAME =~ direct_all_v7_quad_group_aggregate* && NAME =~ *u_quad_aggregate*}]
puts "ROOT_COUNTS controllers=[llength $controllers] engines=[llength $engines] reducers=[llength $reducers]"

set family_by_slr {}
for {set slr 0} {$slr < 4} {incr slr} {
  foreach family {controller engine pwrgood reducer} {
    dict set family_by_slr $slr $family 0
  }
}
set pwrgood_groups {}
set excluded_refs 0
set pwrgood_excluded_names 0
set global_reset_cells 0
set overlaps 0
foreach cell [get_cells -hier -quiet -filter {IS_PRIMITIVE}] {
  set name [get_property NAME $cell]
  set hits {}
  set slr -1
  if {[regexp {g_(left|right)_quad\[([0-9]+)\].*/u_prbs_test_controller/} $name -> side q]} {
    lappend hits controller
    set slr [locality_slr_for_index [expr {4*$q}] 56]
  }
  if {[regexp {u_engine/u_core/g_lane\[([0-9]+)\]\.g_managed\.u_lane/} $name -> lane]} {
    lappend hits engine
    set slr [locality_slr_for_index $lane 56]
  }
  if {[string first {gen_pwrgood_delay_inst[} $name] >= 0 &&
      [regexp {g_(left|right)_quad\[([0-9]+)\]} $name -> side q]} {
    lappend hits pwrgood
    set slr [locality_slr_for_index [expr {4*$q}] 56]
    lappend pwrgood_groups ${side}_${q}
  }
  if {[regexp {u_quad_aggregate/g_slr([0-3])/} $name -> reducer_slr]} {
    lappend hits reducer
    set slr $reducer_slr
  }
  if {[llength $hits] > 1} {incr overlaps}
  foreach family $hits {
    dict set family_by_slr $slr $family \
      [expr {[dict get $family_by_slr $slr $family] + 1}]
    set ref [get_property REF_NAME $cell]
    if {[string match GTYE4_* $ref] || [string match BUFG* $ref] ||
        [string match IBUFDS_GTE4 $ref]} {incr excluded_refs}
    if {[string match *power_on_reset_reg* $name] || [string match *reset_tree* $name]} {
      incr global_reset_cells
    }
    if {$family eq "pwrgood" && ([string match *session* $name] ||
        [string match *native* $name] || [string match *reset_tree* $name])} {
      incr pwrgood_excluded_names
    }
  }
}

set total_union 0
for {set slr 0} {$slr < 4} {incr slr} {
  set summary {}
  set slr_total 0
  foreach family {controller engine pwrgood reducer} {
    set count [dict get $family_by_slr $slr $family]
    lappend summary $family $count
    incr slr_total $count
    incr total_union $count
  }
  puts "SLR$slr $summary total=$slr_total"
}
puts "PWRGOOD_WIZARD_GROUPS [llength [lsort -unique $pwrgood_groups]]"
puts "UNION total=$total_union overlaps=$overlaps excluded_refs=$excluded_refs pwrgood_excluded_names=$pwrgood_excluded_names global_reset_cells=$global_reset_cells"

set high_fanout 0
foreach net [get_nets -hier -quiet] {
  set name [get_property NAME $net]
  if {[string match *power_on_reset* $name]} {
    set fanout [get_property FLAT_PIN_COUNT $net]
    if {$fanout > $high_fanout} {set high_fanout $fanout}
  }
}
puts "GLOBAL_RESET_MAX_FLAT_PIN_COUNT $high_fanout"
close_design
