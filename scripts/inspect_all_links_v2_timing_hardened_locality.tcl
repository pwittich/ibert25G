set repo [file normalize [file join [file dirname [info script]] ..]]
set dcp [file join $repo build gt_test_all_links_v2_timing_hardened gt_test_all_links_v2_timing_hardened_routed.dcp]
open_checkpoint $dcp

proc cell_slr {cell} {
  return [get_property NAME [get_slrs -quiet -of_objects [get_sites -quiet -of_objects $cell]]]
}

for {set slr 0} {$slr < 4} {incr slr} {
  set bank [get_cells -hier -quiet -filter "NAME =~ *g_bank_slr$slr && REF_NAME =~ all_links_v1_slr_bank*"]
  set pb [get_pblocks all_links_v1_control_slr$slr]
  puts "BANK SLR$slr name=$bank assigned=[get_property USER_SLR_ASSIGNMENT $bank]"
  puts "PB SLR$slr soft=[get_property IS_SOFT $pb] contain_routing=[get_property CONTAIN_ROUTING $pb] ranges=[get_property GRID_RANGES $pb]"
  set reset [get_cells -hier -quiet -filter "NAME == [get_property NAME $bank]/local_resetn_reg && REF_NAME =~ FD*"]
  puts "RESET SLR$slr cell=$reset actual=[cell_slr $reset] in_pb=[expr {[lsearch -exact [get_cells -quiet -of_objects $pb] $reset] >= 0}] loc=[get_property LOC $reset]"
  set participation [get_cells -hier -quiet -filter \
    "(NAME =~ [get_property NAME $bank]/left_quad_selected_reg* || NAME =~ [get_property NAME $bank]/right_quad_selected_reg*) && REF_NAME =~ FD*"]
  array set part_counts {SLR0 0 SLR1 0 SLR2 0 SLR3 0 NONE 0}
  foreach cell $participation {
    set actual [cell_slr $cell]
    if {$actual eq ""} {set actual NONE}
    incr part_counts($actual)
    if {$actual ne "SLR$slr"} {puts "PART_ESCAPE expected=SLR$slr actual=$actual cell=$cell loc=[get_property LOC $cell]"}
  }
  puts "PART_COUNTS expected=SLR$slr total=[llength $participation] SLR0=$part_counts(SLR0) SLR1=$part_counts(SLR1) SLR2=$part_counts(SLR2) SLR3=$part_counts(SLR3) NONE=$part_counts(NONE)"
  set quad_resets [get_cells -hier -quiet -filter \
    "NAME =~ [get_property NAME $bank]/g_localize_quad_reset.*_quad_resetn_reg* && REF_NAME =~ FD*"]
  array set qr_counts {SLR0 0 SLR1 0 SLR2 0 SLR3 0 NONE 0}
  foreach cell $quad_resets {
    set actual [cell_slr $cell]
    if {$actual eq ""} {set actual NONE}
    incr qr_counts($actual)
    if {$actual ne "SLR$slr"} {puts "QRESET_ESCAPE expected=SLR$slr actual=$actual cell=$cell loc=[get_property LOC $cell]"}
  }
  puts "QRESET_COUNTS expected=SLR$slr total=[llength $quad_resets] SLR0=$qr_counts(SLR0) SLR1=$qr_counts(SLR1) SLR2=$qr_counts(SLR2) SLR3=$qr_counts(SLR3) NONE=$qr_counts(NONE)"
}

set copy_banks [get_cells -hier -quiet -filter {REF_NAME =~ all_links_v2_result_copy_bank*}]
foreach bank $copy_banks {
  regexp {u_result_copy_slr([0-3])$} [get_property NAME $bank] -> slr
  set stages [get_cells -hier -quiet -filter \
    "(NAME =~ [get_property NAME $bank]/record_stage_reg* || NAME == [get_property NAME $bank]/mismatch_stage_reg) && REF_NAME =~ FD*"]
  array set counts {SLR0 0 SLR1 0 SLR2 0 SLR3 0 NONE 0}
  foreach cell $stages {
    set actual [cell_slr $cell]
    if {$actual eq ""} {set actual NONE}
    incr counts($actual)
  }
  puts "COPY_COUNTS expected=SLR$slr total=[llength $stages] assigned=[get_property USER_SLR_ASSIGNMENT $bank] SLR0=$counts(SLR0) SLR1=$counts(SLR1) SLR2=$counts(SLR2) SLR3=$counts(SLR3) NONE=$counts(NONE)"
}
exit
