`timescale 1ns/1ps

// Reusable managed boundary for one FireFly-1 native four-channel Wizard.
// QUAD selects a statically elaborated Wizard wrapper; all runtime control is
// otherwise shared with the proven q124 controller/reset sequence.
module managed_native_left_quad_wrapper #(
  parameter bit ENABLE_TX_SESSION = 1'b0,
  parameter integer QUAD = 121,
  parameter bit STAGED_RX_ACQUISITION = 1'b0,
  parameter bit REQUIRE_ERROR_FREE_QUALIFICATION = 1'b1
) (
  input wire mgmt_clk, input wire resetn,
  input wire tx_session_active,
  input wire refclk, input wire refclk_odiv2,
  input wire [3:0] rx_p, input wire [3:0] rx_n,
  output wire [3:0] tx_p, output wire [3:0] tx_n,
  input wire [11:0] tx_prbs_select, input wire [11:0] rx_prbs_select,
  input wire [3:0] prbs_counter_reset, input wire [3:0] lane_running,
  input wire [2:0] loopback_mode, input wire acquisition_active,
  input wire measurement_enable, input wire result_capture_request,
  input wire [3:0] tx_error_inject_toggle,
  output wire rx_usrclk2, output wire [3:0] rx_prbs_locked,
  output wire [3:0] rx_cdr_locked, output wire [3:0] rx_prbs_error,
  output wire lane_rx_reset,
  output wire quad_ready, output wire quad_fault,
  output wire [7:0] quad_fault_reason, output wire test_controller_idle,
  output wire acquisition_ready, output wire result_capture_done,
  output wire [127:0] exact_error_counts, output wire [3:0] exact_error_valid,
  output wire [3:0] exact_error_saturated,
  output wire [223:0] platform_diagnostics
);
  wire tx_usrclk2, tx_userclk_active, rx_userclk_active;
  wire gtwiz_reset_all, qpll0lock, gtwiz_reset_rx_datapath, gtwiz_reset_rx_done;
  wire [3:0] gtpowergood, txresetdone, rxresetdone, txpmaresetdone, rxpmaresetdone;
  wire [15:0] txprbssel, rxprbssel;
  wire [11:0] loopback;
  wire [2:0] applied_loopback;
  wire [3:0] sequenced_prbs_counter_reset, rxpmareset, tx_error_pulse;
  wire rx_checker_enable, runtime_rx_reset_active, quad_restart_request;
  wire prbs_controller_fault, quad_controller_fault;
  wire [7:0] quad_controller_fault_reason;
  wire [39:0] drpaddr; wire [3:0] drpclk, drpen, drpwe, drprdy;
  wire [63:0] drpdi, drpdo;
  wire [4:0] unused_diagnostic_state;
  wire [31:0] unused_diagnostic_live, unused_diagnostic_rx, unused_diagnostic_counter;
  wire [255:0] unused_recovery_diagnostics;
  wire [31:0] quad_diagnostic_live;
  logic fault_snapshot_valid = 0;
  logic [31:0] fault_prbs = 0, fault_rx = 0, fault_quad = 0;
  logic [30:0] fault_counter = 0;
  assign platform_diagnostics = {{fault_snapshot_valid, fault_counter},
    fault_quad, fault_rx, fault_prbs, quad_diagnostic_live,
    unused_diagnostic_rx, unused_diagnostic_live};
  always_ff @(posedge mgmt_clk) begin
    if (!resetn) begin
      fault_snapshot_valid <= 0;
      fault_prbs <= 0; fault_rx <= 0; fault_quad <= 0; fault_counter <= 0;
    end else if (!fault_snapshot_valid && quad_fault) begin
      fault_snapshot_valid <= 1;
      fault_prbs <= unused_diagnostic_live;
      fault_rx <= unused_diagnostic_rx;
      fault_quad <= quad_diagnostic_live;
      fault_counter <= unused_diagnostic_counter[30:0];
    end
  end
  wire unused_tx_srcclk, unused_tx_usrclk, unused_rx_srcclk, unused_rx_usrclk;
  wire unused_rx_cdr_stable, unused_reset_tx_done, unused_reset_rx_done;
  wire unused_qpll0outclk, unused_qpll0outrefclk;
  wire [319:0] unused_rx_data;
  logic [15:0] rx_clock_heartbeat_divider = 0;

  always_ff @(posedge rx_usrclk2) rx_clock_heartbeat_divider <= rx_clock_heartbeat_divider + 1'b1;
  // One single-bit CDC per quad, clocked only by the local TX clock.
  // The external PRBS generator no longer depends on the RX lane engine.
  (* ASYNC_REG = "TRUE" *) logic session_meta = 0, session_sync = 0;
  always_ff @(posedge tx_usrclk2) begin
    session_meta <= ENABLE_TX_SESSION && tx_session_active;
    session_sync <= session_meta;
  end

  for (genvar lane = 0; lane < 4; lane++) begin : g_prbs_control
    (* ASYNC_REG = "TRUE" *) logic [3:0] txsel_meta = 0, txsel_sync = 0;
    (* ASYNC_REG = "TRUE" *) logic [2:0] loopback_meta = 0, loopback_sync = 0;
    (* ASYNC_REG = "TRUE" *) logic inject_meta = 0, inject_sync = 0;
    logic inject_seen = 0;
    always_ff @(posedge tx_usrclk2) begin
      txsel_meta <= {1'b0, tx_prbs_select[lane*3 +: 3]}; txsel_sync <= txsel_meta;
      loopback_meta <= applied_loopback; loopback_sync <= loopback_meta;
      inject_meta <= tx_error_inject_toggle[lane]; inject_sync <= inject_meta;
      inject_seen <= inject_sync;
    end
    assign txprbssel[lane*4 +: 4] = ENABLE_TX_SESSION && loopback_sync == 0 ?
      (session_sync ? 4'd5 : 4'd0) : txsel_sync;
    assign rxprbssel[lane*4 +: 4] = rx_checker_enable ?
      {1'b0, rx_prbs_select[lane*3 +: 3]} : 4'b0;
    assign loopback[lane*3 +: 3] = loopback_sync;
    assign tx_error_pulse[lane] = inject_sync ^ inject_seen;
  end

  managed_quad124_lane_reset_policy u_lane_reset_policy (
    .rx_clk(rx_usrclk2), .resetn(resetn), .quad_ready(quad_ready),
    .acquisition_active(acquisition_active), .lane_rx_reset(lane_rx_reset));
  assign quad_fault = quad_controller_fault | prbs_controller_fault;
  assign quad_fault_reason = prbs_controller_fault ? 8'h80 : quad_controller_fault_reason;

  gt_prbs_test_controller #(
    .STAGED_RX_ACQUISITION(STAGED_RX_ACQUISITION),
    .REQUIRE_ERROR_FREE_QUALIFICATION(REQUIRE_ERROR_FREE_QUALIFICATION)
  ) u_prbs_test_controller (
    .mgmt_clk(mgmt_clk), .resetn(resetn), .lane_running_async(lane_running),
    .rx_prbs_locked_async(rx_prbs_locked), .rx_prbs_error_async(rx_prbs_error),
    .requested_loopback(loopback_mode), .acquisition_active(acquisition_active),
    .measurement_enable(measurement_enable),
    .rx_clock_heartbeat_async(rx_clock_heartbeat_divider[15]),
    .result_capture_request(result_capture_request),
    .gtwiz_reset_rx_done_async(gtwiz_reset_rx_done), .rxresetdone_async(rxresetdone),
    .rxpmaresetdone_async(rxpmaresetdone), .quad_ready(quad_ready),
    .applied_loopback(applied_loopback), .gtwiz_reset_rx_datapath(gtwiz_reset_rx_datapath),
    .rxpmareset(rxpmareset), .sequenced_prbs_counter_reset(sequenced_prbs_counter_reset),
    .rx_checker_enable(rx_checker_enable), .acquisition_ready(acquisition_ready),
    .runtime_rx_reset_active(runtime_rx_reset_active), .quad_restart_request(quad_restart_request),
    .controller_idle(test_controller_idle), .controller_fault(prbs_controller_fault),
    .diagnostic_state(unused_diagnostic_state), .diagnostic_live(unused_diagnostic_live),
    .diagnostic_rx(unused_diagnostic_rx), .diagnostic_counter(unused_diagnostic_counter),
    .recovery_diagnostics(unused_recovery_diagnostics), .drpaddr(drpaddr), .drpclk(drpclk),
    .drpdi(drpdi), .drpen(drpen), .drpwe(drpwe), .drpdo(drpdo), .drprdy(drprdy),
    .result_capture_done(result_capture_done), .exact_error_counts(exact_error_counts),
    .exact_error_valid(exact_error_valid), .exact_error_saturated(exact_error_saturated));

  gt_quad_controller u_quad_controller (
    .mgmt_clk(mgmt_clk), .resetn(resetn), .gtpowergood_async(gtpowergood),
    .qpll0lock_async(qpll0lock), .tx_userclk_active_async(tx_userclk_active),
    .rx_userclk_active_async(rx_userclk_active), .txresetdone_async(txresetdone),
    .rxresetdone_async(rxresetdone), .runtime_rx_reset_active(runtime_rx_reset_active),
    .runtime_quad_restart_request(quad_restart_request), .gtwiz_reset_all(gtwiz_reset_all),
    .quad_ready(quad_ready), .quad_fault(quad_controller_fault),
    .fault_reason(quad_controller_fault_reason), .state(), .diagnostic_live(quad_diagnostic_live));

`define NATIVE_LEFT_FUNCTIONAL_PORTS \
    .gtwiz_userclk_tx_reset_in(!resetn), .gtwiz_userclk_tx_srcclk_out(unused_tx_srcclk), \
    .gtwiz_userclk_tx_usrclk_out(unused_tx_usrclk), .gtwiz_userclk_tx_usrclk2_out(tx_usrclk2), \
    .gtwiz_userclk_tx_active_out(tx_userclk_active), .gtwiz_userclk_rx_reset_in(!resetn), \
    .gtwiz_userclk_rx_srcclk_out(unused_rx_srcclk), .gtwiz_userclk_rx_usrclk_out(unused_rx_usrclk), \
    .gtwiz_userclk_rx_usrclk2_out(rx_usrclk2), .gtwiz_userclk_rx_active_out(rx_userclk_active), \
    .gtwiz_reset_clk_freerun_in(mgmt_clk), .gtwiz_reset_all_in(gtwiz_reset_all), \
    .gtwiz_reset_tx_pll_and_datapath_in(1'b0), .gtwiz_reset_tx_datapath_in(1'b0), \
    .gtwiz_reset_rx_pll_and_datapath_in(1'b0), .gtwiz_reset_rx_datapath_in(gtwiz_reset_rx_datapath), \
    .gtwiz_reset_rx_cdr_stable_out(unused_rx_cdr_stable), .gtwiz_reset_tx_done_out(unused_reset_tx_done), \
    .gtwiz_reset_rx_done_out(gtwiz_reset_rx_done), .gtwiz_userdata_tx_in(320'b0), \
    .gtwiz_userdata_rx_out(unused_rx_data), .gtrefclk00_in(refclk), .qpll0lock_out(qpll0lock), \
    .qpll0outclk_out(unused_qpll0outclk), .qpll0outrefclk_out(unused_qpll0outrefclk), \
    .drpaddr_in(drpaddr), .drpclk_in(drpclk), .drpdi_in(drpdi), .drpen_in(drpen), .drpwe_in(drpwe), \
    .gtyrxn_in(rx_n), .gtyrxp_in(rx_p), .loopback_in(loopback), .rxpmareset_in(rxpmareset), \
    .rxprbscntreset_in(prbs_counter_reset | sequenced_prbs_counter_reset), .rxprbssel_in(rxprbssel), \
    .txprbsforceerr_in(tx_error_pulse), .txprbssel_in(txprbssel), .drpdo_out(drpdo), .drprdy_out(drprdy), \
    .gtpowergood_out(gtpowergood), .gtytxn_out(tx_n), .gtytxp_out(tx_p), .rxcdrlock_out(rx_cdr_locked), \
    .rxpmaresetdone_out(rxpmaresetdone), .rxprbserr_out(rx_prbs_error), \
    .rxprbslocked_out(rx_prbs_locked), .rxresetdone_out(rxresetdone), \
    .txpmaresetdone_out(txpmaresetdone), .txresetdone_out(txresetdone)

  generate
    if (QUAD == 121) begin : g_q121
      native_left121_functional_gt_topology u_gt (`NATIVE_LEFT_FUNCTIONAL_PORTS);
    end else if (QUAD == 122) begin : g_q122
      native_left122_functional_gt_topology u_gt (`NATIVE_LEFT_FUNCTIONAL_PORTS);
    end else if (QUAD == 123) begin : g_q123
      native_left123_functional_gt_topology u_gt (`NATIVE_LEFT_FUNCTIONAL_PORTS);
    end else begin : g_invalid_quad
      initial $error("Unsupported FireFly-1 native quad %0d", QUAD);
    end
  endgenerate
`undef NATIVE_LEFT_FUNCTIONAL_PORTS
endmodule
