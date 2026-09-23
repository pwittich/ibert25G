`timescale 1ns/1ps

// Isolated q221-223 topology proof only.  It has no MCU, AXI, firmware, or
// board-management interface and is never a deployment target.  The q222
// MGTREFCLK0 input is deliberately the sole source for the derived native
// wrapper's q221=south/q222=local/q223=north COMMON and CHANNEL routes.
module gt_native_right221_223_proof_v1_top (
  input wire p_clk_200,
  input wire n_clk_200,
  input wire p_rt_r0_n,
  input wire n_rt_r0_n
);
  wire clk_200_raw;
  wire clk_200;
  wire q222_refclk;
  wire q222_refclk_odiv2;

  IBUFDS #(.DIFF_TERM("TRUE"), .IBUF_LOW_PWR("FALSE")) u_clk_200_ibuf (
    .I(p_clk_200), .IB(n_clk_200), .O(clk_200_raw)
  );
  BUFG u_clk_200_bufg (.I(clk_200_raw), .O(clk_200));

  // AY13/AY12 is MGTREFCLK0_222 in the established right-side baseline.
  IBUFDS_GTE4 u_q222_refclk_ibuf (
    .I(p_rt_r0_n), .IB(n_rt_r0_n), .CEB(1'b0),
    .O(q222_refclk), .ODIV2(q222_refclk_odiv2)
  );

  wire [2:0] qpll0lock;
  wire [2:0] qpll0outclk;
  wire [2:0] qpll0outrefclk;
  wire [11:0] gtpowergood, rxcdrlock, rxpmaresetdone, rxprbserr;
  wire [11:0] rxprbslocked, rxresetdone, txpmaresetdone, txresetdone;

  // Preserve every GT primitive for the physical dedicated-refclk proof even
  // though this deliberately interface-free target consumes no serial data.
  (* DONT_TOUCH = "TRUE", KEEP_HIERARCHY = "yes" *)
  native_right221_223_gt_topology u_native_right221_223 (
    .gtwiz_userclk_tx_reset_in(1'b0),
    .gtwiz_userclk_tx_srcclk_out(), .gtwiz_userclk_tx_usrclk_out(),
    .gtwiz_userclk_tx_usrclk2_out(), .gtwiz_userclk_tx_active_out(),
    .gtwiz_userclk_rx_reset_in(1'b0),
    .gtwiz_userclk_rx_srcclk_out(), .gtwiz_userclk_rx_usrclk_out(),
    .gtwiz_userclk_rx_usrclk2_out(), .gtwiz_userclk_rx_active_out(),
    .gtwiz_reset_clk_freerun_in(clk_200),
    .gtwiz_reset_all_in(1'b0), .gtwiz_reset_tx_pll_and_datapath_in(1'b0),
    .gtwiz_reset_tx_datapath_in(1'b0),
    .gtwiz_reset_rx_pll_and_datapath_in(1'b0),
    .gtwiz_reset_rx_datapath_in(1'b0),
    .gtwiz_reset_rx_cdr_stable_out(), .gtwiz_reset_tx_done_out(),
    .gtwiz_reset_rx_done_out(),
    .gtwiz_userdata_tx_in(960'b0), .gtwiz_userdata_rx_out(),
    .gtrefclk00_in({1'b0, q222_refclk, 1'b0}),
    .qpll0lock_out(qpll0lock), .qpll0outclk_out(qpll0outclk),
    .qpll0outrefclk_out(qpll0outrefclk),
    .drpaddr_in(120'b0), .drpclk_in({12{clk_200}}), .drpdi_in(192'b0),
    .drpen_in(12'b0), .drpwe_in(12'b0),
    .gtyrxn_in(12'b0), .gtyrxp_in(12'b0), .loopback_in(36'b0),
    .rxpmareset_in(12'b0), .rxprbscntreset_in(12'b0), .rxprbssel_in(48'b0),
    .txprbsforceerr_in(12'b0), .txprbssel_in(48'b0),
    .drpdo_out(), .drprdy_out(), .gtpowergood_out(gtpowergood),
    .gtytxn_out(), .gtytxp_out(), .rxcdrlock_out(rxcdrlock),
    .rxpmaresetdone_out(rxpmaresetdone), .rxprbserr_out(rxprbserr),
    .rxprbslocked_out(rxprbslocked), .rxresetdone_out(rxresetdone),
    .txpmaresetdone_out(txpmaresetdone), .txresetdone_out(txresetdone)
  );
endmodule
