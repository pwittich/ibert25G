set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set candidate [file join $repo_dir build gt_test_direct_quad_v6_f2 gt_test_direct_quad_v6_f2_routed.dcp]
set golden [file join $repo_dir build gt_test_milestone3_v15 gt_test_milestone3_v15.runs impl_1 gt_test_milestone3_top_routed.dcp]
foreach checkpoint [list $candidate $golden] {
  if {![file exists $checkpoint]} {error "Missing checkpoint: $checkpoint"}
}

proc site_properties {checkpoint site} {
  open_checkpoint $checkpoint
  set cells [get_cells -hier -filter "REF_NAME == GTYE4_CHANNEL && LOC == $site"]
  if {[llength $cells] != 1} {error "Expected one channel at $site in $checkpoint"}
  set cell [lindex $cells 0]
  set result [dict create]
  foreach property [list_property $cell] {
    if {![catch {get_property $property $cell} value]} {
      dict set result $property $value
    }
  }
  close_design
  return $result
}

set candidate_properties [site_properties $candidate GTYE4_CHANNEL_X1Y55]
set golden_properties [site_properties $golden GTYE4_CHANNEL_X1Y55]
set keys [lsort -dictionary -unique [concat [dict keys $candidate_properties] [dict keys $golden_properties]]]
set differing 0
foreach property $keys {
  set candidate_value [expr {[dict exists $candidate_properties $property] ? [dict get $candidate_properties $property] : "<missing>"}]
  set golden_value [expr {[dict exists $golden_properties $property] ? [dict get $golden_properties $property] : "<missing>"}]
  if {$candidate_value ne $golden_value} {
    incr differing
    puts "DIFF $property candidate={$candidate_value} golden={$golden_value}"
  }
}
puts "SUMMARY compared=[llength $keys] differing=$differing"
