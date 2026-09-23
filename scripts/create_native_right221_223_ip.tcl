# Reproducible native-GT IP recipe for the q221-223 proof.
#
# Source this only from a new proof project's creation Tcl after the Phase-0
# baseline has been reviewed.  It intentionally does not run by itself, does
# not import an IBERT XCI, and does not modify any v15/historical project.
set script_dir [file dirname [file normalize [info script]]]
source [file join $script_dir native_right221_223_config.tcl]

proc create_native_right221_223_ip {} {
  global native_proof_wizard_channels native_proof_line_rate_gbps
  global native_proof_refclk_mhz native_proof_user_data_width

  create_ip -name gtwizard_ultrascale -vendor xilinx.com -library ip \
    -version 1.7 -module_name native_right221_223_gt
  set native_gt [get_ips native_right221_223_gt]
  set_property -dict [list \
    CONFIG.CHANNEL_ENABLE $native_proof_wizard_channels \
    CONFIG.TX_LINE_RATE $native_proof_line_rate_gbps \
    CONFIG.RX_LINE_RATE $native_proof_line_rate_gbps \
    CONFIG.TX_REFCLK_FREQUENCY $native_proof_refclk_mhz \
    CONFIG.RX_REFCLK_FREQUENCY $native_proof_refclk_mhz \
    CONFIG.INS_LOSS_NYQ {3} \
    CONFIG.TX_PLL_TYPE {QPLL0} \
    CONFIG.RX_PLL_TYPE {QPLL0} \
    CONFIG.TX_USER_DATA_WIDTH $native_proof_user_data_width \
    CONFIG.RX_USER_DATA_WIDTH $native_proof_user_data_width \
    CONFIG.TX_INT_DATA_WIDTH $native_proof_user_data_width \
    CONFIG.RX_INT_DATA_WIDTH $native_proof_user_data_width \
    CONFIG.TX_MASTER_CHANNEL {X1Y4} \
    CONFIG.RX_MASTER_CHANNEL {X1Y4} \
    CONFIG.FREERUN_FREQUENCY {200} \
    CONFIG.LOCATE_RESET_CONTROLLER {CORE} \
    CONFIG.LOCATE_COMMON {CORE} \
    CONFIG.LOCATE_TX_USER_CLOCKING {CORE} \
    CONFIG.LOCATE_RX_USER_CLOCKING {CORE} \
    CONFIG.ENABLE_OPTIONAL_PORTS {
      drpaddr_in drpclk_in drpdi_in drpdo_out drpen_in drprdy_out drpwe_in
      loopback_in qpll0lock_out rxcdrlock_out rxpmareset_in rxprbscntreset_in
      rxprbserr_out rxprbslocked_out rxprbssel_in rxresetdone_out
      txprbsforceerr_in txprbssel_in txresetdone_out
    }] $native_gt

  foreach {property expected} [list \
    CONFIG.TX_LINE_RATE $native_proof_line_rate_gbps \
    CONFIG.RX_LINE_RATE $native_proof_line_rate_gbps \
    CONFIG.TX_REFCLK_FREQUENCY $native_proof_refclk_mhz \
    CONFIG.RX_REFCLK_FREQUENCY $native_proof_refclk_mhz \
    CONFIG.INS_LOSS_NYQ 3] {
    if {[get_property $property $native_gt] ne "$expected"} {
      error "native q221-223 IP $property is [get_property $property $native_gt], expected $expected"
    }
  }
  if {[lsort [get_property CONFIG.CHANNEL_ENABLE $native_gt]] ne
      [lsort $native_proof_wizard_channels]} {
    error "native q221-223 Wizard channel enable list differs from the baseline"
  }
  return $native_gt
}
