set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set dcp [file join $repo_dir build diagnostic_archive all-links-v1-slr-bank-attempt \
  gt_test_all_links_v1_slr_bank_placed_failed.dcp]
open_checkpoint $dcp

proc cell_slr {cell} {
  set sites [get_sites -quiet -of_objects $cell]
  if {[llength $sites] != 1} {return ""}
  set slrs [get_slrs -quiet -of_objects $sites]
  if {[llength $slrs] != 1} {return ""}
  return [get_property NAME [lindex $slrs 0]]
}

for {set slr 0} {$slr < 4} {incr slr} {
  set bank [lindex [get_cells -hier -quiet -filter "NAME =~ *g_bank_slr$slr && REF_NAME =~ all_links_v1_slr_bank*"] 0]
  set bank_name [get_property NAME $bank]
  puts "BANK $slr $bank_name keep=[get_property KEEP_HIERARCHY $bank] soft=[get_property USER_SLR_ASSIGNMENT $bank]"
  set roots [get_cells -hier -quiet -filter "NAME =~ ${bank_name}/*/u_prbs_test_controller && REF_NAME =~ gt_prbs_test_controller*"]
  foreach root $roots {
    set root_name [get_property NAME $root]
    foreach cell [get_cells -hier -quiet -filter "NAME =~ ${root_name}/* && IS_PRIMITIVE"] {
      set actual [cell_slr $cell]
      if {$actual eq "" || $actual eq "SLR$slr" || [get_property REF_NAME $cell] in {VCC GND}} {continue}
      set outs [get_pins -quiet -of_objects $cell -filter {DIRECTION == OUT}]
      set endpoints [all_fanout -quiet -flat -endpoints_only -from $outs]
      puts "ESC CONTROLLER expected=SLR$slr actual=$actual cell=[get_property NAME $cell] endpoints=$endpoints"
    }
  }
  foreach cell [get_cells -hier -quiet -filter "NAME =~ ${bank_name}/u_local_aggregate/* && IS_PRIMITIVE"] {
    set actual [cell_slr $cell]
    if {$actual eq "" || $actual eq "SLR$slr" || [get_property REF_NAME $cell] in {VCC GND}} {continue}
    set outs [get_pins -quiet -of_objects $cell -filter {DIRECTION == OUT}]
    set endpoints [all_fanout -quiet -flat -endpoints_only -from $outs]
    puts "ESC REDUCER expected=SLR$slr actual=$actual cell=[get_property NAME $cell] endpoints=$endpoints"
  }
}
