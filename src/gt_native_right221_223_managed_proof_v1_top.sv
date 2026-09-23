`timescale 1ns/1ps

// Isolated physical proof that q221/q222/q223 can be governed by three live
// native quad supervisors.  This is not an MCU image: status is deliberately
// kept internal, while the post-route audit proves the concrete GT placement
// and the board check verifies programming plus safe power/thermal operation.
module gt_native_right221_223_managed_proof_v1_top (
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

  // Give configuration and the free-running clock a deterministic settling
  // interval before releasing the three supervisors.  This is distinct from
  // each supervisor's required 256-cycle Wizard reset hold.
  reg [17:0] por_count = 18'd0;
  reg resetn = 1'b0;
  always @(posedge clk_200) begin
    if (!resetn) begin
      por_count <= por_count + 1'b1;
      if (&por_count) resetn <= 1'b1;
    end
  end

  wire [2:0] gtwiz_reset_all, tx_active, rx_active, tx_done, rx_done, qpll0lock;
  wire [11:0] gtpowergood, rx_pma_done, tx_pma_done;
  wire [2:0] quad_ready, quad_fault;
  wire [23:0] fault_reason;
  wire [8:0] quad_state;

  // The Wizard's reset-done outputs are per-core completion indications for
  // this 4-channel configuration.  Replicating them here is intentionally
  // confined to this integration proof; the production wrapper will export
  // individual channel status before it becomes a lane-control source.
  (* DONT_TOUCH = "TRUE", KEEP_HIERARCHY = "yes" *)
  gt_native_right221_223_supervisor_bank u_supervisors (
    .mgmt_clk(clk_200), .resetn(resetn), .gtpowergood(gtpowergood),
    .qpll0lock(qpll0lock), .tx_userclk_active(tx_active),
    .rx_userclk_active(rx_active),
    .txresetdone({{4{tx_done[2]}}, {4{tx_done[1]}}, {4{tx_done[0]}}}),
    .rxresetdone({{4{rx_done[2]}}, {4{rx_done[1]}}, {4{rx_done[0]}}}),
    .runtime_rx_reset_active(3'b000), .active_quad_restart(3'b000),
    .gtwiz_reset_all(gtwiz_reset_all), .quad_ready(quad_ready),
    .quad_fault(quad_fault), .fault_reason(fault_reason), .state(quad_state)
  );

  (* DONT_TOUCH = "TRUE", KEEP_HIERARCHY = "yes" *)
  native_right221_gt_topology u_q221 (
    .gtwiz_userclk_tx_reset_in(1'b0), .gtwiz_userclk_tx_srcclk_out(), .gtwiz_userclk_tx_usrclk_out(), .gtwiz_userclk_tx_usrclk2_out(), .gtwiz_userclk_tx_active_out(tx_active[0]),
    .gtwiz_userclk_rx_reset_in(1'b0), .gtwiz_userclk_rx_srcclk_out(), .gtwiz_userclk_rx_usrclk_out(), .gtwiz_userclk_rx_usrclk2_out(), .gtwiz_userclk_rx_active_out(rx_active[0]), .gtwiz_reset_clk_freerun_in(clk_200),
    .gtwiz_reset_all_in(gtwiz_reset_all[0]), .gtwiz_reset_tx_pll_and_datapath_in(1'b0), .gtwiz_reset_tx_datapath_in(1'b0), .gtwiz_reset_rx_pll_and_datapath_in(1'b0), .gtwiz_reset_rx_datapath_in(1'b0), .gtwiz_reset_rx_cdr_stable_out(), .gtwiz_reset_tx_done_out(tx_done[0]), .gtwiz_reset_rx_done_out(rx_done[0]),
    .gtwiz_userdata_tx_in(320'b0), .gtwiz_userdata_rx_out(), .gtrefclk00_in(q222_refclk), .qpll0lock_out(qpll0lock[0]), .qpll0outclk_out(), .qpll0outrefclk_out(), .gtyrxn_in(4'b0), .gtyrxp_in(4'b0), .gtpowergood_out(gtpowergood[3:0]), .gtytxn_out(), .gtytxp_out(), .rxpmaresetdone_out(rx_pma_done[3:0]), .txpmaresetdone_out(tx_pma_done[3:0])
  );
  (* DONT_TOUCH = "TRUE", KEEP_HIERARCHY = "yes" *)
  native_right222_gt_topology u_q222 (
    .gtwiz_userclk_tx_reset_in(1'b0), .gtwiz_userclk_tx_srcclk_out(), .gtwiz_userclk_tx_usrclk_out(), .gtwiz_userclk_tx_usrclk2_out(), .gtwiz_userclk_tx_active_out(tx_active[1]),
    .gtwiz_userclk_rx_reset_in(1'b0), .gtwiz_userclk_rx_srcclk_out(), .gtwiz_userclk_rx_usrclk_out(), .gtwiz_userclk_rx_usrclk2_out(), .gtwiz_userclk_rx_active_out(rx_active[1]), .gtwiz_reset_clk_freerun_in(clk_200),
    .gtwiz_reset_all_in(gtwiz_reset_all[1]), .gtwiz_reset_tx_pll_and_datapath_in(1'b0), .gtwiz_reset_tx_datapath_in(1'b0), .gtwiz_reset_rx_pll_and_datapath_in(1'b0), .gtwiz_reset_rx_datapath_in(1'b0), .gtwiz_reset_rx_cdr_stable_out(), .gtwiz_reset_tx_done_out(tx_done[1]), .gtwiz_reset_rx_done_out(rx_done[1]),
    .gtwiz_userdata_tx_in(320'b0), .gtwiz_userdata_rx_out(), .gtrefclk00_in(q222_refclk), .qpll0lock_out(qpll0lock[1]), .qpll0outclk_out(), .qpll0outrefclk_out(), .gtyrxn_in(4'b0), .gtyrxp_in(4'b0), .gtpowergood_out(gtpowergood[7:4]), .gtytxn_out(), .gtytxp_out(), .rxpmaresetdone_out(rx_pma_done[7:4]), .txpmaresetdone_out(tx_pma_done[7:4])
  );
  (* DONT_TOUCH = "TRUE", KEEP_HIERARCHY = "yes" *)
  native_right223_gt_topology u_q223 (
    .gtwiz_userclk_tx_reset_in(1'b0), .gtwiz_userclk_tx_srcclk_out(), .gtwiz_userclk_tx_usrclk_out(), .gtwiz_userclk_tx_usrclk2_out(), .gtwiz_userclk_tx_active_out(tx_active[2]),
    .gtwiz_userclk_rx_reset_in(1'b0), .gtwiz_userclk_rx_srcclk_out(), .gtwiz_userclk_rx_usrclk_out(), .gtwiz_userclk_rx_usrclk2_out(), .gtwiz_userclk_rx_active_out(rx_active[2]), .gtwiz_reset_clk_freerun_in(clk_200),
    .gtwiz_reset_all_in(gtwiz_reset_all[2]), .gtwiz_reset_tx_pll_and_datapath_in(1'b0), .gtwiz_reset_tx_datapath_in(1'b0), .gtwiz_reset_rx_pll_and_datapath_in(1'b0), .gtwiz_reset_rx_datapath_in(1'b0), .gtwiz_reset_rx_cdr_stable_out(), .gtwiz_reset_tx_done_out(tx_done[2]), .gtwiz_reset_rx_done_out(rx_done[2]),
    .gtwiz_userdata_tx_in(320'b0), .gtwiz_userdata_rx_out(), .gtrefclk00_in(q222_refclk), .qpll0lock_out(qpll0lock[2]), .qpll0outclk_out(), .qpll0outrefclk_out(), .gtyrxn_in(4'b0), .gtyrxp_in(4'b0), .gtpowergood_out(gtpowergood[11:8]), .gtytxn_out(), .gtytxp_out(), .rxpmaresetdone_out(rx_pma_done[11:8]), .txpmaresetdone_out(tx_pma_done[11:8])
  );
endmodule
