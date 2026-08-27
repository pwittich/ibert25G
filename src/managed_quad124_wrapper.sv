`timescale 1ns/1ps

// Physical owner of GTY quad 124 (global lanes 12-15 / FireFly 5).  This is
// the boundary between generic test-engine controls and the Vivado GT Wizard:
// it performs clock-domain crossings, supervises quad readiness, sequences PMA
// loopback resets, and reads exact native PRBS error counters through DRP.
module managed_quad124_wrapper (
  input  wire         mgmt_clk,
  input  wire         resetn,
  input  wire         refclk_p,
  input  wire         refclk_n,
  input  wire [3:0]   rx_p,
  input  wire [3:0]   rx_n,
  output wire [3:0]   tx_p,
  output wire [3:0]   tx_n,
  input  wire [11:0]  tx_prbs_select,
  input  wire [11:0]  rx_prbs_select,
  input  wire [3:0]   prbs_counter_reset,
  input  wire [3:0]   lane_running,
  input  wire [2:0]   loopback_mode,
  input  wire         result_capture_request,
  input  wire [3:0]   tx_error_inject_toggle,
  output wire         rx_usrclk2,
  output wire [3:0]   rx_prbs_locked,
  output wire [3:0]   rx_prbs_error,
  output wire         lane_rx_reset,
  output wire         refclk_odiv2,
  output wire         quad_ready,
  output wire         quad_fault,
  output wire [7:0]   quad_fault_reason,
  output wire [15:0]  quad_diagnostic,
  output wire [2:0]   quad_state,
  output wire         test_controller_idle,
  output wire         acquisition_ready,
  output wire         result_capture_done,
  output wire [127:0] exact_error_counts,
  output wire [3:0]   exact_error_valid,
  output wire [3:0]   exact_error_saturated
);
  wire refclk;
  wire tx_usrclk2;
  wire tx_userclk_active, rx_userclk_active;
  wire gtwiz_reset_all;
  wire qpll0lock;
  wire [3:0] gtpowergood, txresetdone, rxresetdone;
  wire [3:0] txpmaresetdone, rxpmaresetdone;
  wire [15:0] txprbssel, rxprbssel;
  wire [11:0] loopback;
  wire [2:0] applied_loopback;
  wire [3:0] sequenced_prbs_counter_reset, rxpmareset;
  wire runtime_rx_reset_active, prbs_controller_fault;
  wire [4:0] prbs_diagnostic_state;
  wire quad_controller_fault;
  wire [7:0] quad_controller_fault_reason;
  wire gtwiz_reset_rx_datapath, gtwiz_reset_rx_done;
  wire [39:0] drpaddr;
  wire [3:0] drpclk, drpen, drpwe, drprdy;
  wire [63:0] drpdi, drpdo;
  wire [3:0] tx_error_pulse;
  wire [319:0] unused_rx_data;
  wire unused_reset_rx_cdr_stable;
  wire unused_reset_tx_done, unused_reset_rx_done;
  wire unused_qpll0outclk, unused_qpll0outrefclk;
  wire unused_tx_srcclk, unused_tx_usrclk;
  wire unused_rx_srcclk, unused_rx_usrclk;

  IBUFDS_GTE4 u_refclk_ibuf (
    .I(refclk_p), .IB(refclk_n), .CEB(1'b0),
    .O(refclk), .ODIV2(refclk_odiv2)
  );

  for (genvar lane = 0; lane < 4; lane++) begin : g_prbs_control
    // TX controls must enter TXUSRCLK2.  Error injection is transported as a
    // toggle and reconstructed as a one-cycle pulse, so a narrow management
    // pulse cannot disappear at the clock boundary.
    (* ASYNC_REG = "TRUE" *) logic [3:0] txsel_meta = 0, txsel_sync = 0;
    (* ASYNC_REG = "TRUE" *) logic [2:0] loopback_meta = 0;
    (* ASYNC_REG = "TRUE" *) logic [2:0] loopback_sync = 0;
    (* ASYNC_REG = "TRUE" *) logic inject_meta = 0, inject_sync = 0;
    logic inject_seen = 0;

    always_ff @(posedge tx_usrclk2) begin
      txsel_meta <= {1'b0, tx_prbs_select[lane*3 +: 3]};
      txsel_sync <= txsel_meta;
      loopback_meta <= applied_loopback;
      loopback_sync <= loopback_meta;
      inject_meta <= tx_error_inject_toggle[lane];
      inject_sync <= inject_meta;
      inject_seen <= inject_sync;
    end

    assign txprbssel[lane*4 +: 4] = txsel_sync;
    assign rxprbssel[lane*4 +: 4] =
      // RX PRBS selection is consumed in the common Wizard RX control path;
      // the engine holds it stable throughout the command.
      {1'b0, rx_prbs_select[lane*3 +: 3]};
    assign loopback[lane*3 +: 3] = loopback_sync;
    assign tx_error_pulse[lane] = inject_sync ^ inject_seen;
  end

  (* ASYNC_REG = "TRUE" *) logic quad_ready_rx_meta = 0;
  (* ASYNC_REG = "TRUE" *) logic quad_ready_rx_sync = 0;
  always_ff @(posedge rx_usrclk2) begin
    // Hold lane engines in reset until the management supervisor has qualified
    // all four channels; synchronize readiness before using it in RXUSRCLK2.
    quad_ready_rx_meta <= quad_ready;
    quad_ready_rx_sync <= quad_ready_rx_meta;
  end
  assign lane_rx_reset = !quad_ready_rx_sync;
  assign quad_fault = quad_controller_fault | prbs_controller_fault;
  assign quad_fault_reason = prbs_controller_fault
    ? 8'h80 : quad_controller_fault_reason;
  assign quad_diagnostic = {
    // Packed live observability for AXI 0x070.  fault_reason remains separately
    // latched so a transient qualification loss is not erased by reset action.
    gtwiz_reset_rx_done, &rxpmaresetdone, &rxresetdone,
    rx_prbs_locked, prbs_diagnostic_state,
    runtime_rx_reset_active, applied_loopback
  };

  gt_prbs_test_controller u_prbs_test_controller (
    // Owns only per-test RX disruption and post-run DRP reads.
    .mgmt_clk(mgmt_clk), .resetn(resetn),
    .lane_running_async(lane_running),
    .rx_prbs_locked_async(rx_prbs_locked),
    .requested_loopback(loopback_mode),
    .result_capture_request(result_capture_request),
    .gtwiz_reset_rx_done_async(gtwiz_reset_rx_done),
    .rxresetdone_async(rxresetdone),
    .rxpmaresetdone_async(rxpmaresetdone),
    .applied_loopback(applied_loopback),
    .gtwiz_reset_rx_datapath(gtwiz_reset_rx_datapath),
    .rxpmareset(rxpmareset),
    .sequenced_prbs_counter_reset(sequenced_prbs_counter_reset),
    .acquisition_ready(acquisition_ready),
    .runtime_rx_reset_active(runtime_rx_reset_active),
    .controller_idle(test_controller_idle),
    .controller_fault(prbs_controller_fault),
    .diagnostic_state(prbs_diagnostic_state),
    .drpaddr(drpaddr), .drpclk(drpclk), .drpdi(drpdi),
    .drpen(drpen), .drpwe(drpwe), .drpdo(drpdo), .drprdy(drprdy),
    .result_capture_done(result_capture_done),
    .exact_error_counts(exact_error_counts),
    .exact_error_valid(exact_error_valid),
    .exact_error_saturated(exact_error_saturated)
  );

  gt_quad_controller u_quad_controller (
    // Owns initial bring-up and fatal platform qualification.
    .mgmt_clk(mgmt_clk),
    .resetn(resetn),
    .gtpowergood_async(gtpowergood),
    .qpll0lock_async(qpll0lock),
    .tx_userclk_active_async(tx_userclk_active),
    .rx_userclk_active_async(rx_userclk_active),
    .txresetdone_async(txresetdone),
    .rxresetdone_async(rxresetdone),
    .runtime_rx_reset_active(runtime_rx_reset_active),
    .gtwiz_reset_all(gtwiz_reset_all),
    .quad_ready(quad_ready),
    .quad_fault(quad_controller_fault),
    .fault_reason(quad_controller_fault_reason),
    .state(quad_state)
  );

  managed_quad124_gt u_gt (
    // Vivado owns the generated GT Wizard internals.  Keep integration logic
    // at this wrapper boundary and preserve the generated port structure.
    .gtwiz_userclk_tx_reset_in({!resetn}),
    .gtwiz_userclk_tx_srcclk_out(unused_tx_srcclk),
    .gtwiz_userclk_tx_usrclk_out(unused_tx_usrclk),
    .gtwiz_userclk_tx_usrclk2_out(tx_usrclk2),
    .gtwiz_userclk_tx_active_out(tx_userclk_active),
    .gtwiz_userclk_rx_reset_in({!resetn}),
    .gtwiz_userclk_rx_srcclk_out(unused_rx_srcclk),
    .gtwiz_userclk_rx_usrclk_out(unused_rx_usrclk),
    .gtwiz_userclk_rx_usrclk2_out(rx_usrclk2),
    .gtwiz_userclk_rx_active_out(rx_userclk_active),
    .gtwiz_reset_clk_freerun_in(mgmt_clk),
    .gtwiz_reset_all_in(gtwiz_reset_all),
    .gtwiz_reset_tx_pll_and_datapath_in(1'b0),
    .gtwiz_reset_tx_datapath_in(1'b0),
    .gtwiz_reset_rx_pll_and_datapath_in(1'b0),
    .gtwiz_reset_rx_datapath_in(gtwiz_reset_rx_datapath),
    .gtwiz_reset_rx_cdr_stable_out(unused_reset_rx_cdr_stable),
    .gtwiz_reset_tx_done_out(unused_reset_tx_done),
    .gtwiz_reset_rx_done_out(gtwiz_reset_rx_done),
    .gtwiz_userdata_tx_in(320'd0),
    .gtwiz_userdata_rx_out(unused_rx_data),
    .gtrefclk00_in(refclk),
    .qpll0lock_out(qpll0lock),
    .qpll0outclk_out(unused_qpll0outclk),
    .qpll0outrefclk_out(unused_qpll0outrefclk),
    .gtyrxn_in(rx_n),
    .gtyrxp_in(rx_p),
    .loopback_in(loopback),
    .drpaddr_in(drpaddr),
    .drpclk_in(drpclk),
    .drpdi_in(drpdi),
    .drpen_in(drpen),
    .drpwe_in(drpwe),
    .drpdo_out(drpdo),
    .drprdy_out(drprdy),
    .rxpmareset_in(rxpmareset),
    .rxprbscntreset_in(prbs_counter_reset |
                       sequenced_prbs_counter_reset),
    .rxprbssel_in(rxprbssel),
    .txprbsforceerr_in(tx_error_pulse),
    .txprbssel_in(txprbssel),
    .gtpowergood_out(gtpowergood),
    .gtytxn_out(tx_n),
    .gtytxp_out(tx_p),
    .rxpmaresetdone_out(rxpmaresetdone),
    .rxprbserr_out(rx_prbs_error),
    .rxprbslocked_out(rx_prbs_locked),
    .rxresetdone_out(rxresetdone),
    .txpmaresetdone_out(txpmaresetdone),
    .txresetdone_out(txresetdone)
  );
endmodule
