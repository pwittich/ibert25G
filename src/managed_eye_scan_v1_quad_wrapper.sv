`timescale 1ns/1ps

// Separate eye-scan v1 implementation, based on preserved v3 commit a82d50b.

// One managed direct FPGA-to-FPGA quad, with independent bounded TX session.
module managed_eye_scan_v1_quad_wrapper #(
  parameter bit ENABLE_TX_SESSION = 1'b1,
  parameter integer QUAD = 222,
  parameter bit ALL_DIRECT_V7 = 1'b0,
  parameter bit ALL_LINKS_LEFT_V1 = 1'b0,
  parameter bit STAGED_RX_ACQUISITION = 1'b1,
  parameter bit REQUIRE_ERROR_FREE_QUALIFICATION = 1'b0
) (
  input wire mgmt_clk, input wire resetn,
  input wire [68:0] eye_controls,
  output wire [255:0] eye_packet,
  output wire eye_fatal,
  input wire tx_session_active,
  input wire [1:0] session_tag,
  output wire [1:0] session_tag_ack,
  input wire tx_enable, rx_enable,
  output wire tx_enable_applied,
  output wire config_idle,
  output wire tx_session_applied,
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
  wire [39:0] prbs_drpaddr;
  wire [63:0] prbs_drpdi, prbs_drpdo;
  wire [3:0] prbs_drpen, prbs_drpwe, prbs_drprdy;
  localparam integer EYE_QUAD = ALL_LINKS_LEFT_V1 ? QUAD-121 : 14+QUAD-221;
  (* ASYNC_REG = "TRUE" *) logic [11:0] eye_health_meta=0, eye_health_sync=0;
  (* KEEP = "TRUE" *) logic [3:0] eye_phase_guard=0;
  (* KEEP = "TRUE" *) logic eye_phase_seen=0, eye_active_phase=0;
  logic eye_start=0, eye_protocol_fault=0;
  wire eye_selected = eye_controls[6:2] == EYE_QUAD;
  wire eye_start_ready,eye_busy,eye_valid,eye_cleanup,eye_point_fatal;
  wire [7:0] eye_status;
  wire [1:0] eye_measurements,eye_range,eye_lane;
  wire [15:0] eye_errors0,eye_samples0,eye_errors1,eye_samples1;
  wire eye_result_lpm;
  wire signed [10:0] eye_h;
  wire signed [8:0] eye_v;
  wire [4:0] eye_prescale;
  wire [2:0] eye_port_fault;
  wire eye_request,eye_release,eye_granted,eye_blocked;
  wire eye_cmd_valid,eye_cmd_ready,eye_cmd_we,eye_rsp_valid,eye_rsp_ready,eye_rsp_error;
  wire [9:0] eye_cmd_addr;
  wire [15:0] eye_cmd_di,eye_rsp_do;
  logic [31:0] eye_elapsed=0;
  wire [6:0] eye_global_lane = 7'(EYE_QUAD*4) + {5'd0,eye_lane};
  assign eye_fatal = eye_point_fatal || eye_protocol_fault || (|eye_port_fault);
  assign eye_packet = {64'd0,32'h50020101,eye_elapsed,
    eye_samples1,eye_errors1,eye_samples0,eye_errors0,
    12'd0,eye_v,eye_h,
    2'd0,(eye_elapsed==32'hffffffff),eye_range,eye_global_lane,eye_prescale,
    eye_result_lpm,eye_status,eye_measurements,eye_cleanup,eye_fatal,eye_active_phase,eye_valid};
  always_ff @(posedge mgmt_clk) begin
    if (!resetn) begin
      eye_health_meta<=0; eye_health_sync<=0; eye_phase_guard<=0;
      eye_phase_seen<=0; eye_active_phase<=0; eye_start<=0; eye_protocol_fault<=0; eye_elapsed<=0;
    end else begin
      eye_health_meta <= {rx_cdr_locked,rxresetdone,rxpmaresetdone};
      eye_health_sync <= eye_health_meta;
      eye_phase_guard <= {eye_phase_guard[2:0],eye_controls[64]};
      eye_start<=0;
      if (eye_phase_guard[3] != eye_phase_seen) begin
        eye_phase_seen<=eye_phase_guard[3];
        if (eye_selected) begin
          eye_active_phase<=eye_phase_guard[3];
          if (eye_start_ready) eye_start<=1; else eye_protocol_fault<=1;
        end
      end
      if (eye_start) eye_elapsed<=0;
      else if (eye_busy && eye_elapsed != 32'hffffffff) eye_elapsed<=eye_elapsed+1'b1;
    end
  end
  eye_scan_point u_eye_point (
    .mgmt_clk(mgmt_clk),.resetn(resetn),.start(eye_start),
    .cancel(eye_controls[66] && eye_selected),.permit(eye_controls[67] && eye_selected),
    .rx_healthy(rx_enable && quad_ready && !quad_fault && eye_health_sync[eye_controls[1:0]] &&
      eye_health_sync[4+eye_controls[1:0]] && eye_health_sync[8+eye_controls[1:0]]),
    .profile_ok(1'b1),.lpm_mode(1'b1),.lane(eye_controls[1:0]),
    .horizontal(eye_controls[17:7]),.vertical(eye_controls[26:18]),
    .prescale(eye_controls[31:27]),.sample_timeout_cycles(eye_controls[63:32]),
    .start_ready(eye_start_ready),.busy(eye_busy),.result_valid(eye_valid),
    .result_ready(eye_controls[65] && eye_selected),.result_status(eye_status),
    .cleanup_verified(eye_cleanup),.fatal(eye_point_fatal),.result_measurements(eye_measurements),
    .errors0(eye_errors0),.samples0(eye_samples0),.errors1(eye_errors1),.samples1(eye_samples1),
    .result_lpm(eye_result_lpm),.result_horizontal(eye_h),.result_vertical(eye_v),
    .result_prescale(eye_prescale),.result_vertical_range(eye_range),
    .scan_request(eye_request),.scan_lane(eye_lane),.scan_release(eye_release),
    .scan_granted(eye_granted),.port_fault(eye_port_fault),
    .cmd_valid(eye_cmd_valid),.cmd_ready(eye_cmd_ready),.cmd_addr(eye_cmd_addr),.cmd_di(eye_cmd_di),
    .cmd_we(eye_cmd_we),.rsp_valid(eye_rsp_valid),.rsp_ready(eye_rsp_ready),
    .rsp_do(eye_rsp_do),.rsp_error(eye_rsp_error));
  eye_scan_drp_arbiter u_eye_drp (
    .mgmt_clk(mgmt_clk),.resetn(resetn),.prbs_idle(test_controller_idle),
    .scan_eligible(rx_enable && test_controller_idle),
    .prbs_addr(prbs_drpaddr),.prbs_di(prbs_drpdi),.prbs_en(prbs_drpen),.prbs_we(prbs_drpwe),
    .prbs_do(prbs_drpdo),.prbs_rdy(prbs_drprdy),
    .scan_request(eye_request),.scan_lane(eye_lane),.scan_release(eye_release),
    .scan_granted(eye_granted),.blocked(eye_blocked),.fault(eye_port_fault),
    .cmd_valid(eye_cmd_valid),.cmd_ready(eye_cmd_ready),.cmd_addr(eye_cmd_addr),.cmd_di(eye_cmd_di),
    .cmd_we(eye_cmd_we),.rsp_valid(eye_rsp_valid),.rsp_ready(eye_rsp_ready),
    .rsp_do(eye_rsp_do),.rsp_error(eye_rsp_error),
    .gt_addr(drpaddr),.gt_di(drpdi),.gt_en(drpen),.gt_we(drpwe),.gt_do(drpdo),.gt_rdy(drprdy));
  wire [4:0] unused_diagnostic_state;
  wire [31:0] unused_diagnostic_live, unused_diagnostic_rx, unused_diagnostic_counter;
  wire [255:0] unused_recovery_diagnostics;
  wire [31:0] quad_diagnostic_live;
  (* ASYNC_REG = "TRUE" *) logic session_meta = 0, session_sync = 0;
  logic fault_snapshot_valid = 0;
  (* ASYNC_REG = "TRUE" *) logic [1:0] session_tag_meta = 0, session_tag_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic [1:0] session_tag_guard0 = 0, session_tag_guard1 = 0;
  (* ASYNC_REG = "TRUE" *) logic [1:0] session_tag_guard2 = 0, session_tag_guard3 = 0;
  logic [1:0] session_tag_latched = 0, session_tag_applied = 0;
  logic session_effective = 0;
  (* ASYNC_REG = "TRUE" *) logic [1:0] session_tag_return_meta = 0, session_tag_return_sync = 0;
  always_ff @(posedge tx_usrclk2) begin
    session_tag_meta <= session_tag; session_tag_sync <= session_tag_meta;
    session_tag_guard0 <= session_tag_sync; session_tag_guard1 <= session_tag_guard0;
    session_tag_guard2 <= session_tag_guard1; session_tag_guard3 <= session_tag_guard2;
    if (session_tag_guard3 != session_tag_latched) begin
      session_tag_latched <= session_tag_guard3;
      session_effective <= session_sync;
    end
    session_tag_applied <= session_tag_latched;
  end
  always_ff @(posedge mgmt_clk) begin
    if (!resetn) begin session_tag_return_meta <= 0; session_tag_return_sync <= 0; end
    else begin session_tag_return_meta <= session_tag_applied; session_tag_return_sync <= session_tag_return_meta; end
  end
  assign session_tag_ack = session_tag_return_sync;
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
  (* ASYNC_REG = "TRUE" *) logic tx_enable_meta = 0, tx_enable_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic enable_applied_meta = 0, enable_applied_sync = 0;
  always_ff @(posedge tx_usrclk2) begin
    tx_enable_meta <= resetn && tx_enable;
    tx_enable_sync <= tx_enable_meta;
  end
  always_ff @(posedge mgmt_clk) begin
    if (!resetn) begin enable_applied_meta <= 0; enable_applied_sync <= 0; end
    else begin enable_applied_meta <= tx_enable_sync; enable_applied_sync <= enable_applied_meta; end
  end
  assign tx_enable_applied = enable_applied_sync;

  always_ff @(posedge rx_usrclk2) rx_clock_heartbeat_divider <= rx_clock_heartbeat_divider + 1'b1;
  // One single-bit CDC per quad, clocked only by the local TX clock.
  // The external PRBS generator no longer depends on the RX lane engine.
  (* ASYNC_REG = "TRUE" *) logic session_applied_meta = 0,
    session_applied_sync = 0;
  always_ff @(posedge tx_usrclk2) begin
    session_meta <= ENABLE_TX_SESSION && tx_session_active && tx_enable;
    session_sync <= session_meta;
  end
  always_ff @(posedge mgmt_clk) begin
    if (!resetn) begin
      session_applied_meta <= 0;
      session_applied_sync <= 0;
    end else begin
      session_applied_meta <= session_effective;
      session_applied_sync <= session_applied_meta;
    end
  end
  assign tx_session_applied = ENABLE_TX_SESSION && session_applied_sync;

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
    // A TX lease owns the generator independently of the RX controller's
    // retained loopback history. The old loopback-qualified mux could report
    // a management session active before PRBS31 was actually selected.
    logic [3:0] txprbs_registered = 0;
    always_ff @(posedge tx_usrclk2)
      txprbs_registered <= tx_enable_sync ? (session_effective ? 4'd5 : txsel_sync) : 4'd0;
    assign txprbssel[lane*4 +: 4] = txprbs_registered;
    assign rxprbssel[lane*4 +: 4] = rx_enable && rx_checker_enable ?
      {1'b0, rx_prbs_select[lane*3 +: 3]} : 4'b0;
    assign loopback[lane*3 +: 3] = loopback_sync;
    assign tx_error_pulse[lane] = tx_enable_sync && (inject_sync ^ inject_seen);
  end

  managed_quad124_lane_reset_policy u_lane_reset_policy (
    .rx_clk(rx_usrclk2), .resetn(resetn), .quad_ready(quad_ready),
    .acquisition_active(acquisition_active), .lane_rx_reset(lane_rx_reset));
  assign config_idle = test_controller_idle || prbs_controller_fault;
  assign quad_fault = quad_controller_fault | prbs_controller_fault;
  assign quad_fault_reason = prbs_controller_fault ? 8'h80 : quad_controller_fault_reason;

  gt_prbs_test_controller #(
    .STAGED_RX_ACQUISITION(STAGED_RX_ACQUISITION),
    .REQUIRE_ERROR_FREE_QUALIFICATION(REQUIRE_ERROR_FREE_QUALIFICATION),
    .POST_CAPTURE_RX_REQUAL(1'b1),
    .RETAIN_POST_CLEANUP_IDLE_GUARD(1'b1)
  ) u_prbs_test_controller (
    .mgmt_clk(mgmt_clk), .resetn(resetn), .lane_running_async(lane_running & {4{rx_enable}}),
    .rx_prbs_locked_async(rx_prbs_locked), .rx_prbs_error_async(rx_prbs_error),
    .requested_loopback(loopback_mode), .acquisition_active(acquisition_active && rx_enable),
    .measurement_enable(measurement_enable && rx_enable),
    .rx_clock_heartbeat_async(rx_clock_heartbeat_divider[15]),
    .result_capture_request(result_capture_request && rx_enable),
    .gtwiz_reset_rx_done_async(gtwiz_reset_rx_done), .rxresetdone_async(rxresetdone),
    .rxpmaresetdone_async(rxpmaresetdone), .quad_ready(quad_ready),
    .applied_loopback(applied_loopback), .gtwiz_reset_rx_datapath(gtwiz_reset_rx_datapath),
    .rxpmareset(rxpmareset), .sequenced_prbs_counter_reset(sequenced_prbs_counter_reset),
    .rx_checker_enable(rx_checker_enable), .acquisition_ready(acquisition_ready),
    .runtime_rx_reset_active(runtime_rx_reset_active), .quad_restart_request(quad_restart_request),
    .controller_idle(test_controller_idle), .controller_fault(prbs_controller_fault),
    .diagnostic_state(unused_diagnostic_state), .diagnostic_live(unused_diagnostic_live),
    .diagnostic_rx(unused_diagnostic_rx), .diagnostic_counter(unused_diagnostic_counter),
    .recovery_diagnostics(unused_recovery_diagnostics), .drpaddr(prbs_drpaddr), .drpclk(drpclk),
    .drpdi(prbs_drpdi), .drpen(prbs_drpen), .drpwe(prbs_drpwe), .drpdo(prbs_drpdo), .drprdy(prbs_drprdy),
    .result_capture_done(result_capture_done), .exact_error_counts(exact_error_counts),
    .exact_error_valid(exact_error_valid), .exact_error_saturated(exact_error_saturated));

  all_links_v3_quad_controller u_quad_controller (
    .rx_enable(rx_enable),
    .mgmt_clk(mgmt_clk), .resetn(resetn), .gtpowergood_async(gtpowergood),
    .qpll0lock_async(qpll0lock), .tx_userclk_active_async(tx_userclk_active),
    .rx_userclk_active_async(rx_userclk_active), .txresetdone_async(txresetdone),
    .rxresetdone_async(rxresetdone), .runtime_rx_reset_active(runtime_rx_reset_active),
    .runtime_quad_restart_request(quad_restart_request), .gtwiz_reset_all(gtwiz_reset_all),
    .quad_ready(quad_ready), .quad_fault(quad_controller_fault),
    .fault_reason(quad_controller_fault_reason), .state(), .diagnostic_live(quad_diagnostic_live));

`define DIRECT_V6_FUNCTIONAL_PORTS \
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
    .eyescanreset_in(4'b0), .txelecidle_in({4{!tx_enable_sync}}), .gtyrxn_in(rx_n), .gtyrxp_in(rx_p), .loopback_in(loopback), .rxpmareset_in(rxpmareset), \
    .rxprbscntreset_in(prbs_counter_reset | sequenced_prbs_counter_reset), .rxprbssel_in(rxprbssel), \
    .txprbsforceerr_in(tx_error_pulse), .txprbssel_in(txprbssel), .drpdo_out(drpdo), .drprdy_out(drprdy), \
    .gtpowergood_out(gtpowergood), .gtytxn_out(tx_n), .gtytxp_out(tx_p), .rxcdrlock_out(rx_cdr_locked), \
    .rxpmaresetdone_out(rxpmaresetdone), .rxprbserr_out(rx_prbs_error), \
    .rxprbslocked_out(rx_prbs_locked), .rxresetdone_out(rxresetdone), \
    .txpmaresetdone_out(txpmaresetdone), .txresetdone_out(txresetdone), \
    .txdiffctrl_in({4{5'd24}}), .txprecursor_in(20'd0), .txpostcursor_in(20'd0), \
    .txpolarity_in(4'd0), .rxpolarity_in(4'd0)

  generate
    if (ALL_LINKS_LEFT_V1 && QUAD == 121) begin : g_all_links_q121
      all_links_v1_q121_gt_eye_v1_topology u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else if (ALL_LINKS_LEFT_V1 && QUAD == 122) begin : g_all_links_q122
      all_links_v1_q122_gt_eye_v1_topology u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else if (ALL_LINKS_LEFT_V1 && QUAD == 123) begin : g_all_links_q123
      all_links_v1_q123_gt_eye_v1_topology u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else if (ALL_LINKS_LEFT_V1 && QUAD == 124) begin : g_all_links_q124
      all_links_v1_q124_gt_eye_v1_topology u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else if (ALL_LINKS_LEFT_V1 && QUAD == 125) begin : g_all_links_q125
      all_links_v1_q125_gt_eye_v1_topology u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else if (ALL_LINKS_LEFT_V1 && QUAD == 126) begin : g_all_links_q126
      all_links_v1_q126_gt_eye_v1_topology u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else if (ALL_LINKS_LEFT_V1 && QUAD == 127) begin : g_all_links_q127
      all_links_v1_q127_gt_eye_v1_topology u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else if (ALL_LINKS_LEFT_V1 && QUAD == 128) begin : g_all_links_q128
      all_links_v1_q128_gt_eye_v1_topology u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else if (ALL_LINKS_LEFT_V1 && QUAD == 129) begin : g_all_links_q129
      all_links_v1_q129_gt_eye_v1_topology u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else if (ALL_LINKS_LEFT_V1 && QUAD == 130) begin : g_all_links_q130
      all_links_v1_q130_gt_eye_v1_topology u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else if (ALL_LINKS_LEFT_V1 && QUAD == 131) begin : g_all_links_q131
      all_links_v1_q131_gt_eye_v1_topology u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else if (ALL_LINKS_LEFT_V1 && QUAD == 132) begin : g_all_links_q132
      all_links_v1_q132_gt_eye_v1_topology u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else if (ALL_LINKS_LEFT_V1 && QUAD == 133) begin : g_all_links_q133
      all_links_v1_q133_gt_eye_v1_topology u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else if (ALL_LINKS_LEFT_V1 && QUAD == 134) begin : g_all_links_q134
      all_links_v1_q134_gt_eye_v1_topology u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else if (ALL_DIRECT_V7 && QUAD == 221) begin : g_v7_q221
      direct_all_v7_q221_gt_eye_v1_topology u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else if (ALL_DIRECT_V7 && QUAD == 222) begin : g_v7_q222
      direct_all_v7_q222_gt_eye_v1_topology u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else if (ALL_DIRECT_V7 && QUAD == 223) begin : g_v7_q223
      direct_all_v7_q223_gt_eye_v1_topology u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else if (ALL_DIRECT_V7 && QUAD == 224) begin : g_v7_q224
      direct_all_v7_q224_gt_eye_v1_topology u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else if (ALL_DIRECT_V7 && QUAD == 225) begin : g_v7_q225
      direct_all_v7_q225_gt_eye_v1_topology u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else if (ALL_DIRECT_V7 && QUAD == 226) begin : g_v7_q226
      direct_all_v7_q226_gt_eye_v1_topology u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else if (ALL_DIRECT_V7 && QUAD == 227) begin : g_v7_q227
      direct_all_v7_q227_gt_eye_v1_topology u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else if (ALL_DIRECT_V7 && QUAD == 228) begin : g_v7_q228
      direct_all_v7_q228_gt_eye_v1_topology u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else if (ALL_DIRECT_V7 && QUAD == 229) begin : g_v7_q229
      direct_all_v7_q229_gt_eye_v1_topology u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else if (ALL_DIRECT_V7 && QUAD == 230) begin : g_v7_q230
      direct_all_v7_q230_gt_eye_v1_topology u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else if (ALL_DIRECT_V7 && QUAD == 231) begin : g_v7_q231
      direct_all_v7_q231_gt_eye_v1_topology u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else if (ALL_DIRECT_V7 && QUAD == 232) begin : g_v7_q232
      direct_all_v7_q232_gt_eye_v1_topology u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else if (ALL_DIRECT_V7 && QUAD == 233) begin : g_v7_q233
      direct_all_v7_q233_gt_eye_v1_topology u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else if (ALL_DIRECT_V7 && QUAD == 234) begin : g_v7_q234
      direct_all_v7_q234_gt_eye_v1_topology u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else if (!ALL_DIRECT_V7 && QUAD == 222) begin : g_q222
      direct_v6_q222_gt u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else if (!ALL_DIRECT_V7 && QUAD == 233) begin : g_q233
      direct_v6_q233_gt u_gt (`DIRECT_V6_FUNCTIONAL_PORTS);
    end else begin : g_invalid_quad
      initial $error("Unsupported direct v6 quad %0d", QUAD);
    end
  endgenerate
`undef DIRECT_V6_FUNCTIONAL_PORTS
endmodule
