set script_dir [file dirname [file normalize [info script]]]
set root [file dirname $script_dir]
set dcp [file join $root build gt_test_firefly1_loopback_v1 gt_test_firefly1_loopback_v1.runs impl_1 gt_test_milestone25_top_routed.dcp]
open_checkpoint $dcp

puts "--- GT logical cells ---"
foreach c [lsort [get_cells -hier -filter {REF_NAME =~ *GTY*}]] {
  puts "CELL=$c REF=[get_property REF_NAME $c] PRIMITIVE=[get_property IS_PRIMITIVE $c] LOC=[get_property LOC $c] SITE=[get_property SITE $c] SITES=[get_sites -quiet -of_objects $c]"
}
puts "--- occupied channel/common sites ---"
foreach s [lsort [concat [get_sites -filter {SITE_TYPE =~ GTYE4_CHANNEL*}] [get_sites -filter {SITE_TYPE =~ GTYE4_COMMON*}]]] {
  set cells [get_cells -quiet -of_objects $s]
  if {[llength $cells]} { puts "SITE=$s TYPE=[get_property SITE_TYPE $s] CELLS=$cells" }
}
