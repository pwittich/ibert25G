# Generate fourteen independent four-lane native FireFly GT cores. The six
# physical REFCLK0 sources are q122/q124/q126/q129/q131/q133; outer wrappers
# are derived separately without editing Vivado-owned generated sources.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set name all_links_v1_left_ip
set dir [file join $repo_dir build $name]
if {[file exists $dir]} {error "Refusing to overwrite $dir"}
create_project $name $dir -part xcvu13p-flga2577-2-e
set_property target_language Verilog [current_project]
foreach quad {121 122 123 124 125 126 127 128 129 130 131 132 133 134} {
  set first [expr {4 * ($quad - 120)}]
  set channels {}
  for {set y $first} {$y < $first + 4} {incr y} {lappend channels X0Y$y}
  set core all_links_v1_q${quad}_gt
  create_ip -name gtwizard_ultrascale -vendor xilinx.com -library ip \
    -version 1.7 -module_name $core
  set ip [get_ips $core]
  set_property -dict [list \
    CONFIG.TX_LINE_RATE {25.78125} CONFIG.RX_LINE_RATE {25.78125} \
    CONFIG.TX_REFCLK_FREQUENCY {322.265625} CONFIG.RX_REFCLK_FREQUENCY {322.265625} \
    CONFIG.INS_LOSS_NYQ {3} CONFIG.TX_PLL_TYPE {QPLL0} CONFIG.RX_PLL_TYPE {QPLL0} \
    CONFIG.TX_USER_DATA_WIDTH {80} CONFIG.RX_USER_DATA_WIDTH {80} \
    CONFIG.TX_INT_DATA_WIDTH {80} CONFIG.RX_INT_DATA_WIDTH {80} \
    CONFIG.FREERUN_FREQUENCY {200} CONFIG.LOCATE_RESET_CONTROLLER {CORE} \
    CONFIG.LOCATE_COMMON {CORE} CONFIG.LOCATE_TX_USER_CLOCKING {CORE} \
    CONFIG.LOCATE_RX_USER_CLOCKING {CORE} \
    CONFIG.ENABLE_OPTIONAL_PORTS {
      drpaddr_in drpclk_in drpdi_in drpdo_out drpen_in drprdy_out drpwe_in
      loopback_in qpll0lock_out rxcdrlock_out rxpmareset_in rxprbscntreset_in
      rxprbserr_out rxprbslocked_out rxprbssel_in rxresetdone_out
      txprbsforceerr_in txprbssel_in txresetdone_out
      txdiffctrl_in txprecursor_in txpostcursor_in rxpolarity_in txpolarity_in
    }] $ip
  set_property CONFIG.CHANNEL_ENABLE $channels $ip
  set_property CONFIG.TX_MASTER_CHANNEL [lindex $channels 0] $ip
  set_property CONFIG.RX_MASTER_CHANNEL [lindex $channels 0] $ip
  foreach {property expected} [list CONFIG.CHANNEL_ENABLE $channels \
    CONFIG.TX_MASTER_CHANNEL [lindex $channels 0] \
    CONFIG.RX_MASTER_CHANNEL [lindex $channels 0] \
    CONFIG.TX_LINE_RATE 25.78125 CONFIG.RX_LINE_RATE 25.78125 \
    CONFIG.TX_REFCLK_FREQUENCY 322.265625 CONFIG.RX_REFCLK_FREQUENCY 322.265625 \
    CONFIG.TX_PLL_TYPE QPLL0 CONFIG.RX_PLL_TYPE QPLL0] {
    if {[get_property $property $ip] ne $expected} {
      error "$core $property is [get_property $property $ip], expected $expected"
    }
  }
  if {[get_property IS_LOCKED $ip]} {error "$core is locked"}
}
generate_target all [get_ips]
report_ip_status -file [file join $dir ip_status.rpt]
puts "PASS: all-links v1 left IP generated: 56 channels, 14 commons"
