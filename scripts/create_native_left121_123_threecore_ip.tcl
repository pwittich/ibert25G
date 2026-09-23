# Three independent four-channel Wizards for the FireFly-1 feasibility group.
set script_dir [file dirname [file normalize [info script]]]
source [file join $script_dir native_left121_123_config.tcl]
proc create_native_left121_123_threecore_ip {} {
  global native_left_line_rate_gbps native_left_refclk_mhz native_left_user_data_width
  foreach {quad channels master} {
    121 {X0Y4 X0Y5 X0Y6 X0Y7} X0Y4
    122 {X0Y8 X0Y9 X0Y10 X0Y11} X0Y8
    123 {X0Y12 X0Y13 X0Y14 X0Y15} X0Y12
  } {
    set name native_left${quad}_gt
    create_ip -name gtwizard_ultrascale -vendor xilinx.com -library ip -version 1.7 -module_name $name
    set ip [get_ips $name]
    set_property -dict [list \
      CONFIG.TX_LINE_RATE $native_left_line_rate_gbps \
      CONFIG.RX_LINE_RATE $native_left_line_rate_gbps \
      CONFIG.TX_REFCLK_FREQUENCY $native_left_refclk_mhz \
      CONFIG.RX_REFCLK_FREQUENCY $native_left_refclk_mhz \
      CONFIG.TX_PLL_TYPE {QPLL0} CONFIG.RX_PLL_TYPE {QPLL0} \
      CONFIG.TX_USER_DATA_WIDTH $native_left_user_data_width \
      CONFIG.RX_USER_DATA_WIDTH $native_left_user_data_width \
      CONFIG.TX_INT_DATA_WIDTH $native_left_user_data_width \
      CONFIG.RX_INT_DATA_WIDTH $native_left_user_data_width \
      CONFIG.FREERUN_FREQUENCY {200} CONFIG.LOCATE_RESET_CONTROLLER {CORE} \
      CONFIG.LOCATE_COMMON {CORE} CONFIG.LOCATE_TX_USER_CLOCKING {CORE} \
      CONFIG.LOCATE_RX_USER_CLOCKING {CORE}] $ip
    set_property CONFIG.CHANNEL_ENABLE $channels $ip
    set_property CONFIG.TX_MASTER_CHANNEL $master $ip
    set_property CONFIG.RX_MASTER_CHANNEL $master $ip
  }
}
