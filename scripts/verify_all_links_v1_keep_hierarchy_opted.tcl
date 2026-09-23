set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set report_dir [file join $repo_dir build all_links_v1_reports keep_hierarchy]
file mkdir $report_dir
set out [open [file join $report_dir locality_opted.rpt] w]
set expected {55 73 73 55}
set union [dict create]
for {set slr 0} {$slr < 4} {incr slr} {
  set roots [get_cells -quiet -of_objects [get_pblocks all_links_v1_kh_locality_slr$slr]]
  if {[llength $roots] != [lindex $expected $slr]} {
    close $out; error "Post-opt SLR$slr roots [llength $roots], expected [lindex $expected $slr]"
  }
  foreach root $roots {
    set name [get_property NAME $root]
    if {[dict exists $union $name]} {close $out; error "Post-opt overlapping root $name"}
    dict set union $name $slr
    set ref [get_property REF_NAME $root]
    if {[string match GTYE4_* $ref] || [string match BUFG* $ref] ||
        [string match IBUFDS_GTE4 $ref] || [string match *reset* [string tolower $ref]] ||
        [string match *session* [string tolower $name]]} {
      close $out; error "Post-opt excluded root $name ($ref)"
    }
  }
  puts $out "SLR$slr roots [llength $roots]"
}
if {[dict size $union] != 256} {close $out; error "Post-opt root union [dict size $union]"}
puts $out "PASS: post-opt exact 256 roots, zero overlap/excluded families"
close $out
puts "PASS: all-links v1 KEEP_HIERARCHY post-opt root gate"
