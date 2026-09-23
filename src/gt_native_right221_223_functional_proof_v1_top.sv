`timescale 1ns/1ps

// Functional companion to the routed q221-223 topology proof.  It remains a
// non-deployment target: no MCU, AXI, firmware, or board side effects.  It
// binds the native Wizard wrapper to the selection-aware scalar-platform
// adapter used by the existing engine.  The static proof case deliberately
// selects q222 only while q221/q223 are non-ready/faulted; the adapter must
// keep q222 ready, clear of fault, and be the only restart recipient.
module gt_native_right221_223_functional_proof_v1_top (
  input wire p_clk_200,
  input wire n_clk_200,
  input wire p_rt_r0_n,
  input wire n_rt_r0_n
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

  wire [111:0] proof_selected_lanes = {48'd0, 4'hf, 60'd0}; // q222: 60..63
  wire [27:0] proof_quad_ready = 28'h0000_8000;
  wire [27:0] proof_quad_idle = 28'h0000_8000;
  wire [27:0] proof_quad_fault = 28'h0001_4000; // inactive q221/q223 only
  wire [27:0] active_quads, active_quad_restart;
  wire platform_ready, platform_fault;
  (* DONT_TOUCH = "TRUE", KEEP_HIERARCHY = "yes" *)
  gt_native_active_quad_platform #(.LANES(112), .QUADS(28)) u_active_platform (
    .selected_lanes(proof_selected_lanes), .quad_ready(proof_quad_ready),
    .quad_idle(proof_quad_idle), .quad_fault(proof_quad_fault),
    .quad_restart_request(1'b1), .active_quads(active_quads),
    .platform_ready(platform_ready), .platform_fault(platform_fault),
    .active_quad_restart(active_quad_restart)
  );

  wire [2:0] qpll0lock, qpll0outclk, qpll0outrefclk;
  wire [11:0] gtpowergood, rxcdrlock, rxpmaresetdone, rxprbserr;
  wire [11:0] rxprbslocked, rxresetdone, txpmaresetdone, txresetdone;
  (* DONT_TOUCH = "TRUE", KEEP_HIERARCHY = "yes" *)
  native_right221_223_gt_topology u_native_right221_223 (
    .gtwiz_userclk_tx_reset_in(1'b0), .gtwiz_userclk_tx_srcclk_out(),
    .gtwiz_userclk_tx_usrclk_out(), .gtwiz_userclk_tx_usrclk2_out(),
    .gtwiz_userclk_tx_active_out(), .gtwiz_userclk_rx_reset_in(1'b0),
    .gtwiz_userclk_rx_srcclk_out(), .gtwiz_userclk_rx_usrclk_out(),
    .gtwiz_userclk_rx_usrclk2_out(), .gtwiz_userclk_rx_active_out(),
    .gtwiz_reset_clk_freerun_in(clk_200), .gtwiz_reset_all_in(1'b0),
    .gtwiz_reset_tx_pll_and_datapath_in(1'b0), .gtwiz_reset_tx_datapath_in(1'b0),
    .gtwiz_reset_rx_pll_and_datapath_in(1'b0), .gtwiz_reset_rx_datapath_in(1'b0),
    .gtwiz_reset_rx_cdr_stable_out(), .gtwiz_reset_tx_done_out(),
    .gtwiz_reset_rx_done_out(), .gtwiz_userdata_tx_in(960'b0),
    .gtwiz_userdata_rx_out(), .gtrefclk00_in({1'b0, q222_refclk, 1'b0}),
    .qpll0lock_out(qpll0lock), .qpll0outclk_out(qpll0outclk),
    .qpll0outrefclk_out(qpll0outrefclk), .drpaddr_in(120'b0),
    .drpclk_in({12{clk_200}}), .drpdi_in(192'b0), .drpen_in(12'b0),
    .drpwe_in(12'b0), .gtyrxn_in(12'b0), .gtyrxp_in(12'b0),
    .loopback_in(36'b0), .rxpmareset_in(12'b0), .rxprbscntreset_in(12'b0),
    .rxprbssel_in(48'b0), .txprbsforceerr_in(12'b0), .txprbssel_in(48'b0),
    .drpdo_out(), .drprdy_out(), .gtpowergood_out(gtpowergood),
    .gtytxn_out(), .gtytxp_out(), .rxcdrlock_out(rxcdrlock),
    .rxpmaresetdone_out(rxpmaresetdone), .rxprbserr_out(rxprbserr),
    .rxprbslocked_out(rxprbslocked), .rxresetdone_out(rxresetdone),
    .txpmaresetdone_out(txpmaresetdone), .txresetdone_out(txresetdone)
  );
endmodule
