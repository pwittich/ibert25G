set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set golden [file join $repo_dir build gt_test_milestone3_v15 gt_test_milestone3_v15.runs impl_1 gt_test_milestone3_top_routed.dcp]
if {![file isfile $golden]} {error "Missing golden routed checkpoint $golden"}
set properties {
  ADAPT_CFG1 RXCDR_CFG3 RXDFE_GC_CFG2 RX_DEGEN_CTRL RX_DFE_AGC_CFG1
  RX_SUM_DEGEN_AVTT_OVERITE RX_SUM_VCMTUNE PCI3_AUTO_REALIGN
  PCIE_PLL_SEL_MODE_GEN4 RX_PROGDIV_CFG RX_PROGDIV_RATE
  RX_WIDEMODE_CDR_GEN3 RXCDR_CFG3_GEN2 RXCDR_CFG3_GEN3 RXCDR_CFG3_GEN4
  TXDIFFCTRL TXMAINCURSOR TXPOSTCURSOR TXPRECURSOR RXLPMEN
}
open_checkpoint $golden
set count 0
foreach y [lsort -integer {4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59}] {
  set site GTYE4_CHANNEL_X1Y$y
  set cells [get_cells -hier -filter "REF_NAME == GTYE4_CHANNEL && LOC == $site"]
  if {[llength $cells] != 1} {error "Golden image does not uniquely own $site"}
  set words {}
  foreach property $properties {lappend words "$property=[get_property $property [lindex $cells 0]]"}
  puts "GOLDEN $site [join $words { }]"
  incr count
}
if {$count != 56} {error "Expected 56 golden right-side channels"}
puts "PASS: reported golden properties for all 56 direct-channel primitives"
