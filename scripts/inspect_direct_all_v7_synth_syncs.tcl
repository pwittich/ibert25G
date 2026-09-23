set repo [file dirname [file dirname [file normalize [info script]]]]
set dcp [file join $repo build gt_test_direct_all_v7r3 gt_test_direct_all_v7r3_synth.dcp]
set out [file join $repo build direct_all_v7_reports synth_sync_cells.tsv]
open_checkpoint $dcp
set fd [open $out w]
puts $fd "name\tref\tasync\tclock"
foreach c [lsort [get_cells -hier -filter {IS_SEQUENTIAL}]] {
  set async [get_property ASYNC_REG $c]
  set n [get_property NAME $c]
  if {$async eq "TRUE" || [string match *meta* $n] || [string match *sync* $n] ||
      [string match *launch* $n] ||
      [string match *u_quad_aggregate* $n]} {
    set cp [get_pins -quiet $c/C]
    puts $fd "$n\t[get_property REF_NAME $c]\t$async\t[get_clocks -quiet -of_objects $cp]"
  }
}
close $fd
puts "GROUP_HIERARCHY=[get_cells -hier -quiet -filter {REF_NAME =~ direct_all_v7_quad_group_aggregate*}]"
puts "GROUP_NAMES=[get_cells -hier -quiet -filter {NAME =~ *g_slr*}]"
puts "PASS: wrote $out"
