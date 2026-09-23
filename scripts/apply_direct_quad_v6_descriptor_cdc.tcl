# Bound all sixteen management-to-RX descriptor bits; never false-path them.
set descriptors [get_pins -hier -filter {
  NAME =~ */g_lane*.g_managed.u_lane/selected_meta_reg/D ||
  NAME =~ */g_lane*.g_managed.u_lane/prbs_meta_reg*/D}]
if {[llength $descriptors] != 16} {error "Expected sixteen descriptor endpoints"}
set descriptor_clock_pins {}
foreach p $descriptors {lappend descriptor_clock_pins [get_pins [get_property PARENT_CELL $p]/C]}
set rx_clocks [get_clocks -quiet -of_objects $descriptor_clock_pins]
set session_clock_pins [get_pins -hier -filter {
  NAME =~ */u_managed_direct/session_meta_reg/C ||
  NAME =~ */u_managed_direct/session_sync_reg/C}]
set tx_clocks [get_clocks -quiet -of_objects $session_clock_pins]
if {[llength $rx_clocks] != 1 || [llength $tx_clocks] != 1} {
  error "Expected one RX descriptor clock and one TX session clock"
}
set native_clocks [concat $rx_clocks $tx_clocks]
set other_clocks {}
foreach c [get_clocks] {if {[lsearch -exact $native_clocks $c] < 0} {lappend other_clocks $c}}
set sinks [get_pins -of_objects [all_registers -clock $native_clocks] -filter {DIRECTION == IN && IS_CLOCK == 0}]
set excepted {}
foreach p $sinks {if {[lsearch -exact $descriptors $p] < 0} {lappend excepted $p}}
set_false_path -from $other_clocks -to $excepted
set async_sinks [all_registers -clock $native_clocks -async_pins]
if {[llength $async_sinks]} {set_false_path -from $other_clocks -to $async_sinks}
set_false_path -from $native_clocks -to $other_clocks
set_false_path -from $rx_clocks -to $tx_clocks
set_false_path -from $tx_clocks -to $rx_clocks
set_max_delay -datapath_only 3.000 -from [get_clocks clk_200] -to $descriptors
set sources [all_fanin -flat -startpoints_only -to $descriptors]
if {![llength $sources]} {error "Descriptor sources missing"}
set_bus_skew 3.000 -from $sources -to $descriptors
puts "DIRECT_V6_DESCRIPTOR_CDC: sixteen endpoints at 3 ns; one bus-skew constraint"

# The right-side IBERT primitive configuration is site-specific.  The first
# F2 image accidentally inherited the managed left-bank Wizard settings; its
# X1Y55 receiver then failed the one-shot near-end PMA lock gate while the
# other three lanes locked.  The partial seven-property repair recovered X1Y55
# but left X1Y53 continuously error-active in the next preserved one-shot run.
# Match every remaining non-metadata primitive difference against the audited
# full-IBERT q233 settings on all four F2 channels.  Keep F1/q222 unchanged:
# its original PMA gate passed.
set q233_channels [get_cells -hier -filter {
  REF_NAME == GTYE4_CHANNEL && IS_PRIMITIVE && NAME =~ *g_q233*}]
if {[llength $q233_channels]} {
  if {[llength $q233_channels] != 4} {error "Expected four F2 q233 channels"}
  foreach channel $q233_channels {
    set_property -dict [list \
      ADAPT_CFG1 16'hFB1C RXCDR_CFG3 16'h0010 RXDFE_GC_CFG2 16'hFFE0 \
      RX_DEGEN_CTRL 3'b111 RX_DFE_AGC_CFG1 4 \
      RX_SUM_DEGEN_AVTT_OVERITE 1 RX_SUM_VCMTUNE 4'b1001 \
      PCI3_AUTO_REALIGN FRST_SMPL PCIE_PLL_SEL_MODE_GEN4 2'h0 \
      RX_PROGDIV_CFG 20.0 RX_PROGDIV_RATE 16'h0000 \
      RX_WIDEMODE_CDR_GEN3 2'b01 RXCDR_CFG3_GEN2 6'h10 \
      RXCDR_CFG3_GEN3 16'h0010 RXCDR_CFG3_GEN4 16'h0010] $channel
    foreach {property expected} {
      ADAPT_CFG1 16'hFB1C RXCDR_CFG3 16'h0010 RXDFE_GC_CFG2 16'hFFE0
      RX_DEGEN_CTRL 3'b111 RX_DFE_AGC_CFG1 4
      RX_SUM_DEGEN_AVTT_OVERITE 1 RX_SUM_VCMTUNE 4'b1001
      PCI3_AUTO_REALIGN FRST_SMPL PCIE_PLL_SEL_MODE_GEN4 2'h0
      RX_PROGDIV_CFG 20.000 RX_PROGDIV_RATE 16'h0000
      RX_WIDEMODE_CDR_GEN3 2'b01 RXCDR_CFG3_GEN2 6'h10
      RXCDR_CFG3_GEN3 16'h0010 RXCDR_CFG3_GEN4 16'h0010
    } {
      if {[get_property $property $channel] ne $expected} {
        error "F2 q233 property application failed: $channel $property"
      }
    }
  }
  puts "DIRECT_V6_F2_GOLDEN_RX: applied complete q233 full-IBERT primitive settings"
}
