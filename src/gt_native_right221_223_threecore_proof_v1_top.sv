`timescale 1ns/1ps

// Physical proof for the independently resettable q221/q222/q223 split.
// This remains deliberately isolated: it has no MCU/AXI path and is never a
// deployment image.  Its purpose is to prove that three native Wizard reset
// domains can retain the baseline q222 south/local/north REFCLK0 topology.
module gt_native_right221_223_threecore_proof_v1_top (
  input wire p_clk_200, input wire n_clk_200,
  input wire p_rt_r0_n, input wire n_rt_r0_n
);
  wire clk_200_raw, clk_200, q222_refclk, q222_refclk_odiv2;
  IBUFDS #(.DIFF_TERM("TRUE"), .IBUF_LOW_PWR("FALSE")) u_clk_200_ibuf (
    .I(p_clk_200), .IB(n_clk_200), .O(clk_200_raw)
  );
  BUFG u_clk_200_bufg (.I(clk_200_raw), .O(clk_200));
  IBUFDS_GTE4 u_q222_refclk_ibuf (
    .I(p_rt_r0_n), .IB(n_rt_r0_n), .CEB(1'b0),
    .O(q222_refclk), .ODIV2(q222_refclk_odiv2)
  );

  // Kept as three distinct nets so the route and netlist prove that each
  // four-channel core retains its own reset-controller input.
  (* KEEP = "TRUE" *) wire [2:0] gtwiz_reset_all = 3'b000;
  wire [2:0] tx_active, rx_active, tx_done, rx_done;
  wire [11:0] gtpowergood, rx_pma_done, tx_pma_done;

  (* DONT_TOUCH = "TRUE", KEEP_HIERARCHY = "yes" *)
  native_right221_gt_topology u_q221 (
    .gtwiz_userclk_tx_reset_in(1'b0), .gtwiz_userclk_tx_srcclk_out(),
    .gtwiz_userclk_tx_usrclk_out(), .gtwiz_userclk_tx_usrclk2_out(),
    .gtwiz_userclk_tx_active_out(tx_active[0]),
    .gtwiz_userclk_rx_reset_in(1'b0), .gtwiz_userclk_rx_srcclk_out(),
    .gtwiz_userclk_rx_usrclk_out(), .gtwiz_userclk_rx_usrclk2_out(),
    .gtwiz_userclk_rx_active_out(rx_active[0]), .gtwiz_reset_clk_freerun_in(clk_200),
    .gtwiz_reset_all_in(gtwiz_reset_all[0]), .gtwiz_reset_tx_pll_and_datapath_in(1'b0),
    .gtwiz_reset_tx_datapath_in(1'b0), .gtwiz_reset_rx_pll_and_datapath_in(1'b0),
    .gtwiz_reset_rx_datapath_in(1'b0), .gtwiz_reset_rx_cdr_stable_out(),
    .gtwiz_reset_tx_done_out(tx_done[0]), .gtwiz_reset_rx_done_out(rx_done[0]),
    .gtwiz_userdata_tx_in(320'b0), .gtwiz_userdata_rx_out(), .gtrefclk00_in(q222_refclk),
    .qpll0outclk_out(), .qpll0outrefclk_out(), .gtyrxn_in(4'b0), .gtyrxp_in(4'b0),
    .gtpowergood_out(gtpowergood[3:0]), .gtytxn_out(), .gtytxp_out(),
    .rxpmaresetdone_out(rx_pma_done[3:0]), .txpmaresetdone_out(tx_pma_done[3:0])
  );
  (* DONT_TOUCH = "TRUE", KEEP_HIERARCHY = "yes" *)
  native_right222_gt_topology u_q222 (
    .gtwiz_userclk_tx_reset_in(1'b0), .gtwiz_userclk_tx_srcclk_out(),
    .gtwiz_userclk_tx_usrclk_out(), .gtwiz_userclk_tx_usrclk2_out(),
    .gtwiz_userclk_tx_active_out(tx_active[1]),
    .gtwiz_userclk_rx_reset_in(1'b0), .gtwiz_userclk_rx_srcclk_out(),
    .gtwiz_userclk_rx_usrclk_out(), .gtwiz_userclk_rx_usrclk2_out(),
    .gtwiz_userclk_rx_active_out(rx_active[1]), .gtwiz_reset_clk_freerun_in(clk_200),
    .gtwiz_reset_all_in(gtwiz_reset_all[1]), .gtwiz_reset_tx_pll_and_datapath_in(1'b0),
    .gtwiz_reset_tx_datapath_in(1'b0), .gtwiz_reset_rx_pll_and_datapath_in(1'b0),
    .gtwiz_reset_rx_datapath_in(1'b0), .gtwiz_reset_rx_cdr_stable_out(),
    .gtwiz_reset_tx_done_out(tx_done[1]), .gtwiz_reset_rx_done_out(rx_done[1]),
    .gtwiz_userdata_tx_in(320'b0), .gtwiz_userdata_rx_out(), .gtrefclk00_in(q222_refclk),
    .qpll0outclk_out(), .qpll0outrefclk_out(), .gtyrxn_in(4'b0), .gtyrxp_in(4'b0),
    .gtpowergood_out(gtpowergood[7:4]), .gtytxn_out(), .gtytxp_out(),
    .rxpmaresetdone_out(rx_pma_done[7:4]), .txpmaresetdone_out(tx_pma_done[7:4])
  );
  (* DONT_TOUCH = "TRUE", KEEP_HIERARCHY = "yes" *)
  native_right223_gt_topology u_q223 (
    .gtwiz_userclk_tx_reset_in(1'b0), .gtwiz_userclk_tx_srcclk_out(),
    .gtwiz_userclk_tx_usrclk_out(), .gtwiz_userclk_tx_usrclk2_out(),
    .gtwiz_userclk_tx_active_out(tx_active[2]),
    .gtwiz_userclk_rx_reset_in(1'b0), .gtwiz_userclk_rx_srcclk_out(),
    .gtwiz_userclk_rx_usrclk_out(), .gtwiz_userclk_rx_usrclk2_out(),
    .gtwiz_userclk_rx_active_out(rx_active[2]), .gtwiz_reset_clk_freerun_in(clk_200),
    .gtwiz_reset_all_in(gtwiz_reset_all[2]), .gtwiz_reset_tx_pll_and_datapath_in(1'b0),
    .gtwiz_reset_tx_datapath_in(1'b0), .gtwiz_reset_rx_pll_and_datapath_in(1'b0),
    .gtwiz_reset_rx_datapath_in(1'b0), .gtwiz_reset_rx_cdr_stable_out(),
    .gtwiz_reset_tx_done_out(tx_done[2]), .gtwiz_reset_rx_done_out(rx_done[2]),
    .gtwiz_userdata_tx_in(320'b0), .gtwiz_userdata_rx_out(), .gtrefclk00_in(q222_refclk),
    .qpll0outclk_out(), .qpll0outrefclk_out(), .gtyrxn_in(4'b0), .gtyrxp_in(4'b0),
    .gtpowergood_out(gtpowergood[11:8]), .gtytxn_out(), .gtytxp_out(),
    .rxpmaresetdone_out(rx_pma_done[11:8]), .txpmaresetdone_out(tx_pma_done[11:8])
  );
endmodule
