# Three independently resettable four-channel Wizard cores.  This replaces
# the one 12-channel core only in a new proof project; it never edits v15.
set script_dir [file dirname [file normalize [info script]]]
source [file join $script_dir native_right221_223_config.tcl]
proc create_native_right221_223_threecore_ip {} {
  global native_proof_line_rate_gbps native_proof_refclk_mhz native_proof_user_data_width
  foreach {quad channels master} {
    221 {X1Y4 X1Y5 X1Y6 X1Y7} X1Y4
    222 {X1Y8 X1Y9 X1Y10 X1Y11} X1Y8
    223 {X1Y12 X1Y13 X1Y14 X1Y15} X1Y12
  } {
    set name native_right${quad}_gt
    create_ip -name gtwizard_ultrascale -vendor xilinx.com -library ip -version 1.7 -module_name $name
    set ip [get_ips $name]
    # Apply channel/master placement last.  The Wizard recomputes topology
    # after line-rate/PLL changes and otherwise silently restores X0Y0.
    set_property -dict [list \
      CONFIG.TX_LINE_RATE $native_proof_line_rate_gbps \
      CONFIG.RX_LINE_RATE $native_proof_line_rate_gbps \
      CONFIG.TX_REFCLK_FREQUENCY $native_proof_refclk_mhz \
      CONFIG.RX_REFCLK_FREQUENCY $native_proof_refclk_mhz \
      CONFIG.TX_PLL_TYPE {QPLL0} CONFIG.RX_PLL_TYPE {QPLL0} \
      CONFIG.TX_USER_DATA_WIDTH $native_proof_user_data_width \
      CONFIG.RX_USER_DATA_WIDTH $native_proof_user_data_width \
      CONFIG.TX_INT_DATA_WIDTH $native_proof_user_data_width \
      CONFIG.RX_INT_DATA_WIDTH $native_proof_user_data_width \
      CONFIG.FREERUN_FREQUENCY {200} CONFIG.LOCATE_RESET_CONTROLLER {CORE} \
      CONFIG.LOCATE_COMMON {CORE} CONFIG.LOCATE_TX_USER_CLOCKING {CORE} \
      CONFIG.LOCATE_RX_USER_CLOCKING {CORE}] $ip
    set_property CONFIG.CHANNEL_ENABLE $channels $ip
    set_property CONFIG.TX_MASTER_CHANNEL $master $ip
    set_property CONFIG.RX_MASTER_CHANNEL $master $ip
  }
}
