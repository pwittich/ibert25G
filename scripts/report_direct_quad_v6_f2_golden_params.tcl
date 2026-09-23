set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set candidate [file join $repo_dir build gt_test_direct_quad_v6_f2 gt_test_direct_quad_v6_f2_routed.dcp]
set golden [file join $repo_dir build gt_test_milestone3_v15 gt_test_milestone3_v15.runs impl_1 gt_test_milestone3_top_routed.dcp]
set properties {
  ADAPT_CFG1 RXCDR_CFG3 RXDFE_GC_CFG2 RX_DEGEN_CTRL RX_DFE_AGC_CFG1
  RX_SUM_DEGEN_AVTT_OVERITE RX_SUM_VCMTUNE PCI3_AUTO_REALIGN
  PCIE_PLL_SEL_MODE_GEN4 RX_PROGDIV_CFG RX_PROGDIV_RATE
  RX_WIDEMODE_CDR_GEN3 RXCDR_CFG3_GEN2 RXCDR_CFG3_GEN3 RXCDR_CFG3_GEN4
}

proc report_sites {label checkpoint properties} {
  open_checkpoint $checkpoint
  foreach y {52 53 54 55} {
    set site GTYE4_CHANNEL_X1Y$y
    set cells [get_cells -hier -filter "REF_NAME == GTYE4_CHANNEL && LOC == $site"]
    if {[llength $cells] != 1} {error "Expected one $site channel in $checkpoint"}
    set cell [lindex $cells 0]
    set words {}
    foreach property $properties {
      lappend words "$property=[get_property $property $cell]"
    }
    puts "$label $site [join $words { }]"
  }
  close_design
}

report_sites CANDIDATE $candidate $properties
report_sites GOLDEN $golden $properties
puts "PASS: reported per-site F2 and golden q233 primitive parameters"
