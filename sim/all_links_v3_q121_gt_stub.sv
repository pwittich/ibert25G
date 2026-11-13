// Simulation-only GT stub: clocks/status and electrical-idle observation.
module all_links_v1_q121_gt_v3_topology (
  txelecidle_in,
  gtwiz_userclk_tx_reset_in,
  gtwiz_userclk_tx_srcclk_out,
  gtwiz_userclk_tx_usrclk_out,
  gtwiz_userclk_tx_usrclk2_out,
  gtwiz_userclk_tx_active_out,
  gtwiz_userclk_rx_reset_in,
  gtwiz_userclk_rx_srcclk_out,
  gtwiz_userclk_rx_usrclk_out,
  gtwiz_userclk_rx_usrclk2_out,
  gtwiz_userclk_rx_active_out,
  gtwiz_reset_clk_freerun_in,
  gtwiz_reset_all_in,
  gtwiz_reset_tx_pll_and_datapath_in,
  gtwiz_reset_tx_datapath_in,
  gtwiz_reset_rx_pll_and_datapath_in,
  gtwiz_reset_rx_datapath_in,
  gtwiz_reset_rx_cdr_stable_out,
  gtwiz_reset_tx_done_out,
  gtwiz_reset_rx_done_out,
  gtwiz_userdata_tx_in,
  gtwiz_userdata_rx_out,
  gtrefclk00_in,
  qpll0lock_out,
  qpll0outclk_out,
  qpll0outrefclk_out,
  drpaddr_in,
  drpclk_in,
  drpdi_in,
  drpen_in,
  drpwe_in,
  gtyrxn_in,
  gtyrxp_in,
  loopback_in,
  rxpmareset_in,
  rxpolarity_in,
  rxprbscntreset_in,
  rxprbssel_in,
  txdiffctrl_in,
  txpolarity_in,
  txpostcursor_in,
  txprbsforceerr_in,
  txprbssel_in,
  txprecursor_in,
  drpdo_out,
  drprdy_out,
  gtpowergood_out,
  gtytxn_out,
  gtytxp_out,
  rxcdrlock_out,
  rxpmaresetdone_out,
  rxprbserr_out,
  rxprbslocked_out,
  rxresetdone_out,
  txpmaresetdone_out,
  txresetdone_out
);
input wire [3:0] txelecidle_in;
input wire [0 : 0] gtwiz_userclk_tx_reset_in;
output wire [0 : 0] gtwiz_userclk_tx_srcclk_out;
output wire [0 : 0] gtwiz_userclk_tx_usrclk_out;
output wire [0 : 0] gtwiz_userclk_tx_usrclk2_out;
output wire [0 : 0] gtwiz_userclk_tx_active_out;
input wire [0 : 0] gtwiz_userclk_rx_reset_in;
output wire [0 : 0] gtwiz_userclk_rx_srcclk_out;
output wire [0 : 0] gtwiz_userclk_rx_usrclk_out;
output wire [0 : 0] gtwiz_userclk_rx_usrclk2_out;
output wire [0 : 0] gtwiz_userclk_rx_active_out;
input wire [0 : 0] gtwiz_reset_clk_freerun_in;
input wire [0 : 0] gtwiz_reset_all_in;
input wire [0 : 0] gtwiz_reset_tx_pll_and_datapath_in;
input wire [0 : 0] gtwiz_reset_tx_datapath_in;
input wire [0 : 0] gtwiz_reset_rx_pll_and_datapath_in;
input wire [0 : 0] gtwiz_reset_rx_datapath_in;
output wire [0 : 0] gtwiz_reset_rx_cdr_stable_out;
output wire [0 : 0] gtwiz_reset_tx_done_out;
output wire [0 : 0] gtwiz_reset_rx_done_out;
input wire [319 : 0] gtwiz_userdata_tx_in;
output wire [319 : 0] gtwiz_userdata_rx_out;
input wire [0 : 0] gtrefclk00_in;
output wire [0 : 0] qpll0lock_out;
output wire [0 : 0] qpll0outclk_out;
output wire [0 : 0] qpll0outrefclk_out;
input wire [39 : 0] drpaddr_in;
input wire [3 : 0] drpclk_in;
input wire [63 : 0] drpdi_in;
input wire [3 : 0] drpen_in;
input wire [3 : 0] drpwe_in;
input wire [3 : 0] gtyrxn_in;
input wire [3 : 0] gtyrxp_in;
input wire [11 : 0] loopback_in;
input wire [3 : 0] rxpmareset_in;
input wire [3 : 0] rxpolarity_in;
input wire [3 : 0] rxprbscntreset_in;
input wire [15 : 0] rxprbssel_in;
input wire [19 : 0] txdiffctrl_in;
input wire [3 : 0] txpolarity_in;
input wire [19 : 0] txpostcursor_in;
input wire [3 : 0] txprbsforceerr_in;
input wire [15 : 0] txprbssel_in;
input wire [19 : 0] txprecursor_in;
output wire [63 : 0] drpdo_out;
output wire [3 : 0] drprdy_out;
output wire [3 : 0] gtpowergood_out;
output wire [3 : 0] gtytxn_out;
output wire [3 : 0] gtytxp_out;
output wire [3 : 0] rxcdrlock_out;
output wire [3 : 0] rxpmaresetdone_out;
output wire [3 : 0] rxprbserr_out;
output wire [3 : 0] rxprbslocked_out;
output wire [3 : 0] rxresetdone_out;
output wire [3 : 0] txpmaresetdone_out;
output wire [3 : 0] txresetdone_out;
logic force_rx_fault = 0;
assign gtwiz_userclk_tx_srcclk_out = gtrefclk00_in;
assign gtwiz_userclk_tx_usrclk_out = gtrefclk00_in;
assign gtwiz_userclk_tx_usrclk2_out = gtrefclk00_in;
assign gtwiz_userclk_tx_active_out = !gtwiz_userclk_tx_reset_in;
assign gtwiz_userclk_rx_srcclk_out = gtrefclk00_in;
assign gtwiz_userclk_rx_usrclk_out = gtrefclk00_in;
assign gtwiz_userclk_rx_usrclk2_out = gtrefclk00_in;
assign gtwiz_userclk_rx_active_out = !gtwiz_userclk_tx_reset_in;
assign gtwiz_reset_rx_cdr_stable_out = '0;
assign gtwiz_reset_tx_done_out = !gtwiz_reset_all_in;
assign gtwiz_reset_rx_done_out = !gtwiz_reset_all_in;
assign gtwiz_userdata_rx_out = '0;
assign qpll0lock_out = !gtwiz_reset_all_in;
assign qpll0outclk_out = '0;
assign qpll0outrefclk_out = '0;
assign drpdo_out = '0;
assign drprdy_out = '0;
assign gtpowergood_out = {4{!gtwiz_reset_all_in}};
assign gtytxn_out = txelecidle_in;
assign gtytxp_out = ~txelecidle_in;
assign rxcdrlock_out = 4'hf;
assign rxpmaresetdone_out = {4{!gtwiz_reset_all_in && !force_rx_fault}};
assign rxprbserr_out = '0;
assign rxprbslocked_out = 4'hf;
assign rxresetdone_out = {4{!gtwiz_reset_all_in && !force_rx_fault}};
assign txpmaresetdone_out = {4{!gtwiz_reset_all_in}};
assign txresetdone_out = {4{!gtwiz_reset_all_in}};
endmodule
