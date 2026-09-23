set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set dcp [file join $repo_dir build gt_test_all_links_v2_timing_hardened \
  gt_test_all_links_v2_timing_hardened.runs synth_1 gt_test_all_links_v1_top.dcp]
open_checkpoint $dcp
foreach pattern {
  {*quad_resetn*}
  {*u_result_copy_slr*record_stage_reg*}
  {*u_result_copy_slr*mismatch_stage_reg*}
  {*g_split_snapshot*g_chunk*dest_hsdata_ff_reg*}
} {
  set cells [get_cells -hier -quiet -filter "NAME =~ $pattern"]
  puts "INSPECT pattern=$pattern count=[llength $cells]"
  foreach c [lrange $cells 0 39] {
    set keep "NA"
    if {[lsearch -exact [list_property $c] KEEP] >= 0} {set keep [get_property KEEP $c]}
    puts "INSPECT_CELL [get_property NAME $c] REF=[get_property REF_NAME $c] KEEP=$keep"
  }
}
set split_regs [get_cells -hier -quiet -filter {
  NAME =~ *g_split_snapshot*g_chunk*dest_hsdata_ff_reg* && REF_NAME =~ FD*}]
set ce_pins [get_pins -quiet -of_objects $split_regs -filter {REF_PIN_NAME == CE}]
set ce_nets [lsort -unique [get_nets -quiet -of_objects $ce_pins]]
puts "INSPECT split_fd=[llength $split_regs] ce_pins=[llength $ce_pins] ce_nets=[llength $ce_nets]"
foreach n [lrange $ce_nets 0 7] {
  puts "INSPECT_CE $n loads=[llength [get_pins -quiet -of_objects $n -filter {DIRECTION == IN}]]"
}
close_design
