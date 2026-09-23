set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set report_dir [file join $repo_dir build all_links_v1_reports keep_hierarchy]
file mkdir $report_dir
proc kh_regexp_quote {value} {
  regsub -all {[][{}().^$*+?|\\]} $value {\\&} quoted
  return $quoted
}
set out [open [file join $report_dir locality_placed.rpt] w]
set expected {55 73 73 55}
set seen_roots [dict create]
set seen_leaves [dict create]
set misplaced {}
set mixed {}
set duplicates {}
set excluded {}
set constants 0
for {set slr 0} {$slr < 4} {incr slr} {
  set roots [get_cells -quiet -of_objects [get_pblocks all_links_v1_kh_locality_slr$slr]]
  if {[llength $roots] != [lindex $expected $slr]} {
    close $out; error "Placed SLR$slr root count [llength $roots], expected [lindex $expected $slr]"
  }
  foreach root $roots {
    set root_name [get_property NAME $root]
    if {[dict exists $seen_roots $root_name]} {lappend duplicates $root_name}
    dict set seen_roots $root_name $slr
    set pattern "^[kh_regexp_quote $root_name]/.*$"
    set leaves [get_cells -hier -regexp -quiet -filter {IS_PRIMITIVE} $pattern]
    if {[llength $leaves] == 0} {lappend misplaced [list EMPTY $root_name]}
    set root_slrs {}
    foreach leaf $leaves {
      set name [get_property NAME $leaf]
      if {[dict exists $seen_leaves $name]} {lappend duplicates $name}
      dict set seen_leaves $name $root_name
      set ref [get_property REF_NAME $leaf]
      if {[string match GTYE4_* $ref] || [string match BUFG* $ref] ||
          [string match IBUFDS_GTE4 $ref] || [string match *reset_tree* $name] ||
          [string match *session* $name]} {lappend excluded $name}
      set sites [get_sites -quiet -of_objects $leaf]
      set actual_slrs [get_slrs -quiet -of_objects $sites]
      if {[llength $sites] != 1 || [llength $actual_slrs] != 1} {
        if {$ref in {VCC GND}} {incr constants; continue}
        lappend misplaced [list UNPLACED $name expected=SLR$slr]
        continue
      }
      set actual [get_property NAME [lindex $actual_slrs 0]]
      lappend root_slrs $actual
      if {$actual ne "SLR$slr"} {lappend misplaced [list $name expected=SLR$slr actual=$actual]}
    }
    set root_slrs [lsort -unique $root_slrs]
    if {[llength $root_slrs] != 1 || [lindex $root_slrs 0] ne "SLR$slr"} {
      lappend mixed [list $root_name $root_slrs]
    }
  }
}
set timing [report_timing_summary -delay_type min_max -max_paths 100 -report_unconstrained \
  -return_string -file [file join $report_dir timing_placed.rpt]]
set worst_paths [get_timing_paths -quiet -delay_type max -max_paths 1]
if {[llength $worst_paths] != 1} {close $out; error "No placed setup path"}
set wns [get_property SLACK [lindex $worst_paths 0]]
report_timing -delay_type max -max_paths 100 -file [file join $report_dir path_classes_placed.rpt]
set skew [report_bus_skew -warn_on_violation -return_string \
  -file [file join $report_dir bus_skew_placed.rpt]]
set skew_groups [regexp -all {Slack \(MET\)|Slack \(VIOLATED\)} $skew]
puts $out "roots [dict size $seen_roots] leaves [dict size $seen_leaves] constants $constants"
puts $out "misplaced [llength $misplaced] mixed [llength $mixed] duplicates [llength $duplicates] excluded [llength $excluded]"
puts $out "placed WNS $wns ns; prior locality placement estimate -1.240 ns"
puts $out "bus-skew groups $skew_groups"
puts $out "first misplaced [lrange $misplaced 0 49]"
puts $out "mixed roots $mixed"
if {[dict size $seen_roots] != 256 || [llength $misplaced] || [llength $mixed] ||
    [llength $duplicates] || [llength $excluded] || $skew_groups != 28} {
  close $out; error "All-links v1 KEEP_HIERARCHY placement containment failed"
}
# Require at least 0.100 ns improvement over the previous -1.240 ns placement
# estimate before spending the one allowed phys-opt/route attempt.
if {$wns <= -1.140} {
  close $out; error "Placed setup did not materially improve: WNS=$wns ns, gate > -1.140 ns"
}
puts $out "PASS: zero escaped/mixed roots and materially improved placement timing"
close $out
puts "PASS: all-links v1 KEEP_HIERARCHY placement gate; WNS=$wns ns"
