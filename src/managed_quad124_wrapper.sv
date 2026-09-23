`timescale 1ns/1ps

// Physical owner of GTY quad 124 (global lanes 12-15 / FireFly 5).  This is
// the boundary between generic test-engine controls and the Vivado GT Wizard:
// it performs clock-domain crossings, supervises quad readiness, sequences PMA
// loopback resets, and reads exact native PRBS error counters through DRP.
module managed_quad124_wrapper #(
  parameter integer DIAGNOSTIC_TRACE = 0,
  parameter bit STAGED_RX_ACQUISITION = 1'b0,
  parameter bit REQUIRE_ERROR_FREE_QUALIFICATION = 1'b1,
  parameter bit EXTERNAL_RX_RECOVERY = 1'b0,
  parameter bit EXTERNAL_QUAD_RECOVERY = 1'b0,
  parameter bit EXTERNAL_STARTUP_QUAD_RESTART = 1'b0,
  parameter bit POST_CAPTURE_RX_REQUAL = 1'b0,
  parameter bit POST_CAPTURE_QUAD_RESTART = 1'b0,
  parameter bit RUNTIME_INTEGRITY_DETECTOR = 1'b0,
  parameter bit INTEGRITY_HEARTBEAT_TEST_HOOK = 1'b0
) (
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
  input  wire         acquisition_active,
  input  wire         measurement_enable,
  input  wire         measurement_run_toggle,
  input  wire [31:0]  engine_protocol_debug,
  input  wire [7:0]   diagnostic_selector,
  input  wire [1:0]   diagnostic_bank,
  output wire [255:0] diagnostic_record,
  input  wire         result_capture_request,
  input  wire [3:0]   tx_error_inject_toggle,
  output wire         rx_usrclk2,
  output wire [3:0]   rx_prbs_locked,
  output wire [3:0]   rx_cdr_locked,
  output wire [3:0]   rx_prbs_error,
  output wire         lane_rx_reset,
  output wire         refclk_odiv2,
  output wire         quad_ready,
  output wire         quad_fault,
  output wire [7:0]   quad_fault_reason,
  output wire [15:0]  quad_diagnostic,
  output wire [223:0] platform_diagnostics,
  output wire [255:0] recovery_diagnostics,
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
  wire rx_checker_enable;
  wire runtime_rx_reset_active, quad_restart_request;
  wire prbs_controller_fault;
  wire [4:0] prbs_diagnostic_state;
  wire [31:0] prbs_diagnostic_live, prbs_diagnostic_rx;
  wire [31:0] prbs_diagnostic_counter, quad_diagnostic_live;
  logic [31:0] fault_prbs_snapshot = 0;
  logic [31:0] fault_rx_snapshot = 0;
  logic [31:0] fault_quad_snapshot = 0;
  logic [30:0] fault_counter_snapshot = 0;
  logic fault_snapshot_valid = 0;
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
  logic [15:0] rx_clock_heartbeat_divider = 0;

  // The Wizard exposes one shared RXUSRCLK2 for this quad.  A divided toggle
  // is slow enough to cross safely and proves only that this fabric clock is
  // advancing; it is not a lane-local recovered-clock or CDR indication.
  always_ff @(posedge rx_usrclk2)
    rx_clock_heartbeat_divider <= rx_clock_heartbeat_divider + 1'b1;
  // Diagnostic targets may withhold only the monitor's observation of the
  // shared heartbeat through the existing lane-15 injection toggle. The GT,
  // RXUSRCLK2, and frequency monitor remain untouched. The associated two
  // one-cycle lane-15 error injections are intentionally far below the data-
  // integrity threshold. Historical targets keep this hook elaborated off.
  wire monitored_rx_clock_heartbeat = rx_clock_heartbeat_divider[15] &
    ~(INTEGRITY_HEARTBEAT_TEST_HOOK && tx_error_inject_toggle[3]);

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
    assign rxprbssel[lane*4 +: 4] = rx_checker_enable ?
      // RX PRBS selection is consumed in the common Wizard RX control path;
      // the engine holds it stable throughout the command.
      {1'b0, rx_prbs_select[lane*3 +: 3]} : 4'b0000;
    assign loopback[lane*3 +: 3] = loopback_sync;
    assign tx_error_pulse[lane] = inject_sync ^ inject_seen;
  end

  managed_quad124_lane_reset_policy u_lane_reset_policy (
    .rx_clk(rx_usrclk2),
    .resetn(resetn),
    .quad_ready(quad_ready),
    .acquisition_active(acquisition_active),
    .lane_rx_reset(lane_rx_reset)
  );
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
  assign platform_diagnostics = {
    {fault_snapshot_valid, fault_counter_snapshot},
    fault_quad_snapshot, fault_rx_snapshot, fault_prbs_snapshot,
    quad_diagnostic_live, prbs_diagnostic_rx, prbs_diagnostic_live
  };

  if (DIAGNOSTIC_TRACE) begin : g_trace
    (* ASYNC_REG = "TRUE" *) logic [31:0] sel_meta = 0, sel_sync = 0;
    (* ASYNC_REG = "TRUE" *) logic [31:0] status_meta = 0, status_sync = 0;
    (* ASYNC_REG = "TRUE" *) logic [3:0] err_meta = 0, err_sync = 0;
    logic [3:0] error_seen = 0;
    logic acquire_previous = 0;
    wire [255:0] trace_record, trace_meta;
    wire [1023:0] rx_profiles;
    always_ff @(posedge mgmt_clk) begin
      sel_meta <= {txprbssel, rxprbssel}; sel_sync <= sel_meta;
      err_meta <= rx_prbs_error; err_sync <= err_meta;
      status_meta <= {gtwiz_reset_all, lane_rx_reset,
        sequenced_prbs_counter_reset, rxpmareset, gtwiz_reset_rx_datapath,
        txresetdone, rxresetdone, rx_cdr_locked, rx_prbs_locked,
        error_seen, rx_checker_enable};
      status_sync <= status_meta;
      acquire_previous <= acquisition_active;
      if (!resetn || (acquisition_active && !acquire_previous)) error_seen <= 0;
      else error_seen <= error_seen | err_sync;
    end
    localparam integer TRACE_ADDR_WIDTH = DIAGNOSTIC_TRACE == 2 ? 8 : 6;
    wire [7:0] trace_address = {diagnostic_bank, diagnostic_selector[5:0]};
    gt_transition_trace #(.ADDR_WIDTH(TRACE_ADDR_WIDTH)) trace (
      .clk(mgmt_clk), .resetn(resetn), .acquisition_active(acquisition_active),
      .engine_busy(engine_protocol_debug[7]), .controller_idle(test_controller_idle),
      .fault(quad_fault),
      .sample({engine_protocol_debug, sel_sync, status_sync,
        prbs_diagnostic_live, (prbs_diagnostic_rx & 32'hff00001f),
        quad_diagnostic_live}),
      .read_index(trace_address[TRACE_ADDR_WIDTH-1:0]), .record(trace_record), .metadata(trace_meta)
    );
    for (genvar n = 0; n < 4; n++) begin : g_profile
      gt_rx_error_profile profile (
        .mgmt_clk(mgmt_clk), .resetn(resetn), .rx_clk(rx_usrclk2),
        .measurement_enable(measurement_enable),
        .measurement_run_toggle(measurement_run_toggle),
        .rx_error(rx_prbs_error[n]),
        .diagnostics(rx_profiles[n*256 +: 256])
      );
    end
    assign diagnostic_record = diagnostic_selector == 8'hfc ? trace_meta :
      diagnostic_selector >= 8'hf8 && diagnostic_selector <= 8'hfb ?
        rx_profiles[diagnostic_selector[1:0]*256 +: 256] : trace_record;
  end else begin : g_no_trace
    assign diagnostic_record = 256'd0;
  end

  // Preserve the first platform-fault context until FPGA reset. Later engine
  // cleanup, PRBS-control removal, or a secondary fault cannot erase it.
  always_ff @(posedge mgmt_clk) begin
    if (!resetn) begin
      fault_snapshot_valid <= 0;
      fault_prbs_snapshot <= 0;
      fault_rx_snapshot <= 0;
      fault_quad_snapshot <= 0;
      fault_counter_snapshot <= 0;
    end else if (!fault_snapshot_valid &&
                 (quad_controller_fault || prbs_controller_fault)) begin
      fault_snapshot_valid <= 1;
      fault_prbs_snapshot <= prbs_diagnostic_live;
      fault_rx_snapshot <= prbs_diagnostic_rx;
      fault_quad_snapshot <= quad_diagnostic_live;
      fault_counter_snapshot <= prbs_diagnostic_counter[30:0];
    end
  end

  gt_prbs_test_controller #(
    .STAGED_RX_ACQUISITION(STAGED_RX_ACQUISITION),
    .REQUIRE_ERROR_FREE_QUALIFICATION(REQUIRE_ERROR_FREE_QUALIFICATION),
    .EXTERNAL_RX_RECOVERY(EXTERNAL_RX_RECOVERY),
    .EXTERNAL_QUAD_RECOVERY(EXTERNAL_QUAD_RECOVERY),
    .EXTERNAL_STARTUP_QUAD_RESTART(EXTERNAL_STARTUP_QUAD_RESTART),
    .POST_CAPTURE_RX_REQUAL(POST_CAPTURE_RX_REQUAL),
    .POST_CAPTURE_QUAD_RESTART(POST_CAPTURE_QUAD_RESTART),
    .RUNTIME_INTEGRITY_DETECTOR(RUNTIME_INTEGRITY_DETECTOR),
    .INTEGRITY_HEARTBEAT_TEST_HOOK(INTEGRITY_HEARTBEAT_TEST_HOOK)
  ) u_prbs_test_controller (
    // Owns only per-test RX disruption and post-run DRP reads.
    .mgmt_clk(mgmt_clk), .resetn(resetn),
    .lane_running_async(lane_running),
    .rx_prbs_locked_async(rx_prbs_locked),
    .rx_prbs_error_async(rx_prbs_error),
    .requested_loopback(loopback_mode),
    .acquisition_active(acquisition_active),
    .measurement_enable(measurement_enable),
    .rx_clock_heartbeat_async(monitored_rx_clock_heartbeat),
    .result_capture_request(result_capture_request),
    .gtwiz_reset_rx_done_async(gtwiz_reset_rx_done),
    .rxresetdone_async(rxresetdone),
    .rxpmaresetdone_async(rxpmaresetdone),
    .quad_ready(quad_ready),
    .applied_loopback(applied_loopback),
    .gtwiz_reset_rx_datapath(gtwiz_reset_rx_datapath),
    .rxpmareset(rxpmareset),
    .sequenced_prbs_counter_reset(sequenced_prbs_counter_reset),
    .rx_checker_enable(rx_checker_enable),
    .acquisition_ready(acquisition_ready),
    .runtime_rx_reset_active(runtime_rx_reset_active),
    .quad_restart_request(quad_restart_request),
    .controller_idle(test_controller_idle),
    .controller_fault(prbs_controller_fault),
    .diagnostic_state(prbs_diagnostic_state),
    .diagnostic_live(prbs_diagnostic_live),
    .diagnostic_rx(prbs_diagnostic_rx),
    .diagnostic_counter(prbs_diagnostic_counter),
    .recovery_diagnostics(recovery_diagnostics),
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
    .runtime_quad_restart_request(quad_restart_request),
    .gtwiz_reset_all(gtwiz_reset_all),
    .quad_ready(quad_ready),
    .quad_fault(quad_controller_fault),
    .fault_reason(quad_controller_fault_reason),
    .state(quad_state), .diagnostic_live(quad_diagnostic_live)
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
    .rxcdrlock_out(rx_cdr_locked),
    .rxprbserr_out(rx_prbs_error),
    .rxprbslocked_out(rx_prbs_locked),
    .rxresetdone_out(rxresetdone),
    .txpmaresetdone_out(txpmaresetdone),
    .txresetdone_out(txresetdone)
  );
endmodule
