# New functional IP only; preserve historical proofs and v5 products.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set name direct_quad_v6_ip
set dir [file join $repo_dir build $name]
if {[file exists $dir]} {error "Refusing to overwrite existing v6 IP project: $dir"}
create_project $name $dir -part xcvu13p-flga2577-2-e
set_property target_language Verilog [current_project]
foreach {quad channels master} {
  222 {X1Y8 X1Y9 X1Y10 X1Y11} X1Y8
  233 {X1Y52 X1Y53 X1Y54 X1Y55} X1Y52
} {
  set core direct_v6_q${quad}_gt
  create_ip -name gtwizard_ultrascale -vendor xilinx.com -library ip -version 1.7 -module_name $core
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
  # Placement last: PLL/rate changes can reset Wizard channel selection.
  set_property CONFIG.CHANNEL_ENABLE $channels $ip
  set_property CONFIG.TX_MASTER_CHANNEL $master $ip
  set_property CONFIG.RX_MASTER_CHANNEL $master $ip
  foreach {property expected} [list CONFIG.CHANNEL_ENABLE $channels \
    CONFIG.TX_MASTER_CHANNEL $master CONFIG.RX_MASTER_CHANNEL $master \
    CONFIG.TX_LINE_RATE 25.78125 CONFIG.RX_LINE_RATE 25.78125 \
    CONFIG.TX_REFCLK_FREQUENCY 322.265625 CONFIG.RX_REFCLK_FREQUENCY 322.265625] {
    if {[get_property $property $ip] ne $expected} {error "$core $property changed unexpectedly"}
  }
  if {[get_property IS_LOCKED $ip]} {error "$core is locked"}
}
generate_target all [get_ips]
report_ip_status -file [file join $dir ip_status.rpt]
puts "PASS: v6 q222/q233 functional IP generated; application RTL/simulation/build/audit still required"
