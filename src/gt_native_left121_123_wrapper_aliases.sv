// Adapter-only compatibility layer for the isolated FireFly-1 proof.  All
// interfaces match the generated four-channel Wizard wrappers; no generated
// file is changed.  This lets the independently audited proof harness retain
// its three reset domains while the physical primitives are q121-123.
`define GT_NATIVE_4CH_PORTS \
  input wire [0:0] gtwiz_userclk_tx_reset_in, output wire [0:0] gtwiz_userclk_tx_srcclk_out, output wire [0:0] gtwiz_userclk_tx_usrclk_out, output wire [0:0] gtwiz_userclk_tx_usrclk2_out, output wire [0:0] gtwiz_userclk_tx_active_out, \
  input wire [0:0] gtwiz_userclk_rx_reset_in, output wire [0:0] gtwiz_userclk_rx_srcclk_out, output wire [0:0] gtwiz_userclk_rx_usrclk_out, output wire [0:0] gtwiz_userclk_rx_usrclk2_out, output wire [0:0] gtwiz_userclk_rx_active_out, \
  input wire [0:0] gtwiz_reset_clk_freerun_in, input wire [0:0] gtwiz_reset_all_in, input wire [0:0] gtwiz_reset_tx_pll_and_datapath_in, input wire [0:0] gtwiz_reset_tx_datapath_in, input wire [0:0] gtwiz_reset_rx_pll_and_datapath_in, input wire [0:0] gtwiz_reset_rx_datapath_in, output wire [0:0] gtwiz_reset_rx_cdr_stable_out, output wire [0:0] gtwiz_reset_tx_done_out, output wire [0:0] gtwiz_reset_rx_done_out, \
  input wire [319:0] gtwiz_userdata_tx_in, output wire [319:0] gtwiz_userdata_rx_out, input wire [0:0] gtrefclk00_in, output wire [0:0] qpll0lock_out, output wire [0:0] qpll0outclk_out, output wire [0:0] qpll0outrefclk_out, input wire [3:0] gtyrxn_in, input wire [3:0] gtyrxp_in, output wire [3:0] gtpowergood_out, output wire [3:0] gtytxn_out, output wire [3:0] gtytxp_out, output wire [3:0] rxpmaresetdone_out, output wire [3:0] txpmaresetdone_out
module native_right221_gt_topology (`GT_NATIVE_4CH_PORTS);
  native_left121_gt_topology u_left121 (.*);
endmodule
module native_right222_gt_topology (`GT_NATIVE_4CH_PORTS);
  native_left122_gt_topology u_left122 (.*);
endmodule
module native_right223_gt_topology (`GT_NATIVE_4CH_PORTS);
  native_left123_gt_topology u_left123 (.*);
endmodule
`undef GT_NATIVE_4CH_PORTS
