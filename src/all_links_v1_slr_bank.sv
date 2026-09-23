`timescale 1ns/1ps

// Target-only physical boundary for one all-links SLR.  LEFT_FIRST and COUNT
// identify matching left/right quad ranges; local aggregate order is left-low,
// right-high so the established lowest-global-quad diagnostic priority is kept.
module all_links_v1_slr_bank #(
  parameter integer LEFT_FIRST = 0,
  parameter integer COUNT = 3,
  parameter bit LOCALIZE_QUAD_RESET = 1'b0
) (
  input wire clk_200, resetn,
  input wire [6:0] controls_in,
  input wire [COUNT-1:0] left_quad_selected_in, right_quad_selected_in,
  input wire [COUNT-1:0] left_refclk, left_refclk_odiv2,
  input wire [COUNT-1:0] right_refclk, right_refclk_odiv2,
  input wire [COUNT*4-1:0] left_rx_p, left_rx_n, right_rx_p, right_rx_n,
  output wire [COUNT*4-1:0] left_tx_p, left_tx_n, right_tx_p, right_tx_n,
  input wire [COUNT*12-1:0] left_tx_prbs_select, left_rx_prbs_select,
  input wire [COUNT*12-1:0] right_tx_prbs_select, right_rx_prbs_select,
  input wire [COUNT*4-1:0] left_prbs_counter_reset, left_lane_running,
  input wire [COUNT*4-1:0] right_prbs_counter_reset, right_lane_running,
  input wire [COUNT*4-1:0] left_tx_error_inject_toggle,
  input wire [COUNT*4-1:0] right_tx_error_inject_toggle,
  output wire [COUNT-1:0] left_rx_usrclk2, right_rx_usrclk2,
  output wire [COUNT*4-1:0] left_prbs_locked, left_cdr_locked, left_prbs_error,
  output wire [COUNT*4-1:0] right_prbs_locked, right_cdr_locked, right_prbs_error,
  output wire [COUNT*4-1:0] left_lane_rx_reset, right_lane_rx_reset,
  output wire [COUNT-1:0] left_quad_ready, left_quad_fault,
  output wire [COUNT-1:0] right_quad_ready, right_quad_fault,
  output wire [COUNT-1:0] left_controller_idle, left_acquisition_ready,
  output wire [COUNT-1:0] left_capture_done, left_tx_session_applied,
  output wire [COUNT-1:0] right_controller_idle, right_acquisition_ready,
  output wire [COUNT-1:0] right_capture_done, right_tx_session_applied,
  output wire [COUNT*8-1:0] left_fault_reason, right_fault_reason,
  output wire [COUNT*224-1:0] left_diagnostics, right_diagnostics,
  output wire [COUNT*128-1:0] left_exact_error_counts, right_exact_error_counts,
  output wire [COUNT*4-1:0] left_exact_error_valid, left_exact_error_saturated,
  output wire [COUNT*4-1:0] right_exact_error_valid, right_exact_error_saturated,
  output wire group_ready, group_fault, group_idle, group_acquire,
  output wire group_capture, group_session_applied,
  output wire [7:0] group_fault_reason,
  output wire [223:0] group_diagnostics
);
  localparam integer QUADS = 2*COUNT;
  (* KEEP = "TRUE" *) wire [6:0] local_controls;
  logic local_resetn = 1'b0;
  logic [COUNT-1:0] left_quad_selected = '0;
  logic [COUNT-1:0] right_quad_selected = '0;
  wire [QUADS-1:0] acquisition_participating =
    {right_acquisition_ready | ~right_quad_selected,
     left_acquisition_ready | ~left_quad_selected};
  wire [QUADS-1:0] capture_participating =
    {right_capture_done | ~right_quad_selected,
     left_capture_done | ~left_quad_selected};

  // The board POR is a synchronous one-shot in clk_200.  This is deliberately
  // one local release register, not an asynchronous-reset synchronizer.
  always_ff @(posedge clk_200) begin
    local_resetn <= resetn;
    // Same one-cycle bank boundary as controls and per-lane descriptor launch.
    // Only acquisition/capture use participation neutralization; global
    // ready/fault/idle/session barriers intentionally retain every quad.
    left_quad_selected <= left_quad_selected_in;
    right_quad_selected <= right_quad_selected_in;
  end

  wire [COUNT-1:0] left_wrapper_resetn, right_wrapper_resetn;
  if (LOCALIZE_QUAD_RESET) begin : g_localize_quad_reset
    // Keep these as distinct physical endpoints.  Their purpose is to replace
    // one high-fanout bank reset release with cycle-matched per-quad releases;
    // merging equivalent bits would recreate the timing topology this branch
    // is intended to remove.
    (* KEEP = "TRUE" *) logic [COUNT-1:0] left_quad_resetn = '0;
    (* KEEP = "TRUE" *) logic [COUNT-1:0] right_quad_resetn = '0;
    always_ff @(posedge clk_200) begin
      // All per-quad releases have identical latency.  The extra local stage
      // removes the wrapper/controller reset fanout from local_resetn while
      // retaining synchronous, initialized-low release semantics.
      left_quad_resetn <= {COUNT{local_resetn}};
      right_quad_resetn <= {COUNT{local_resetn}};
    end
    assign left_wrapper_resetn = left_quad_resetn;
    assign right_wrapper_resetn = right_quad_resetn;
  end else begin : g_legacy_bank_reset
    assign left_wrapper_resetn = {COUNT{local_resetn}};
    assign right_wrapper_resetn = {COUNT{local_resetn}};
  end

  direct_all_v7_control_pipeline u_control_pipeline (
    .clk(clk_200), .controls_in(controls_in), .controls_out(local_controls));

  for (genvar q = 0; q < COUNT; q++) begin : g_left_quad
    localparam integer QUAD = 121 + LEFT_FIRST + q;
    wire lane_reset;
    managed_all_links_left_quad_wrapper #(.QUAD(QUAD)) u_managed_left (
      .mgmt_clk(clk_200), .resetn(left_wrapper_resetn[q]),
      .tx_session_active(local_controls[6]),
      .tx_session_applied(left_tx_session_applied[q]),
      .refclk(left_refclk[q]), .refclk_odiv2(left_refclk_odiv2[q]),
      .rx_p(left_rx_p[q*4 +: 4]), .rx_n(left_rx_n[q*4 +: 4]),
      .tx_p(left_tx_p[q*4 +: 4]), .tx_n(left_tx_n[q*4 +: 4]),
      .tx_prbs_select(left_tx_prbs_select[q*12 +: 12]),
      .rx_prbs_select(left_rx_prbs_select[q*12 +: 12]),
      .prbs_counter_reset(left_prbs_counter_reset[q*4 +: 4]),
      .lane_running(left_lane_running[q*4 +: 4]),
      .loopback_mode(local_controls[5:3]),
      .acquisition_active(local_controls[2]),
      .measurement_enable(local_controls[1]),
      .result_capture_request(local_controls[0]),
      .tx_error_inject_toggle(left_tx_error_inject_toggle[q*4 +: 4]),
      .rx_usrclk2(left_rx_usrclk2[q]),
      .rx_prbs_locked(left_prbs_locked[q*4 +: 4]),
      .rx_cdr_locked(left_cdr_locked[q*4 +: 4]),
      .rx_prbs_error(left_prbs_error[q*4 +: 4]), .lane_rx_reset(lane_reset),
      .quad_ready(left_quad_ready[q]), .quad_fault(left_quad_fault[q]),
      .quad_fault_reason(left_fault_reason[q*8 +: 8]),
      .test_controller_idle(left_controller_idle[q]),
      .acquisition_ready(left_acquisition_ready[q]),
      .result_capture_done(left_capture_done[q]),
      .exact_error_counts(left_exact_error_counts[q*128 +: 128]),
      .exact_error_valid(left_exact_error_valid[q*4 +: 4]),
      .exact_error_saturated(left_exact_error_saturated[q*4 +: 4]),
      .platform_diagnostics(left_diagnostics[q*224 +: 224]));
    assign left_lane_rx_reset[q*4 +: 4] = {4{lane_reset}};
  end

  for (genvar q = 0; q < COUNT; q++) begin : g_right_quad
    localparam integer QUAD = 221 + LEFT_FIRST + q;
    wire lane_reset;
    managed_direct_quad_v6_wrapper #(
      .QUAD(QUAD), .ALL_DIRECT_V7(1'b1), .ENABLE_TX_SESSION(1'b1)
    ) u_managed_right (
      .mgmt_clk(clk_200), .resetn(right_wrapper_resetn[q]),
      .tx_session_active(local_controls[6]),
      .tx_session_applied(right_tx_session_applied[q]),
      .refclk(right_refclk[q]), .refclk_odiv2(right_refclk_odiv2[q]),
      .rx_p(right_rx_p[q*4 +: 4]), .rx_n(right_rx_n[q*4 +: 4]),
      .tx_p(right_tx_p[q*4 +: 4]), .tx_n(right_tx_n[q*4 +: 4]),
      .tx_prbs_select(right_tx_prbs_select[q*12 +: 12]),
      .rx_prbs_select(right_rx_prbs_select[q*12 +: 12]),
      .prbs_counter_reset(right_prbs_counter_reset[q*4 +: 4]),
      .lane_running(right_lane_running[q*4 +: 4]),
      .loopback_mode(local_controls[5:3]),
      .acquisition_active(local_controls[2]),
      .measurement_enable(local_controls[1]),
      .result_capture_request(local_controls[0]),
      .tx_error_inject_toggle(right_tx_error_inject_toggle[q*4 +: 4]),
      .rx_usrclk2(right_rx_usrclk2[q]),
      .rx_prbs_locked(right_prbs_locked[q*4 +: 4]),
      .rx_cdr_locked(right_cdr_locked[q*4 +: 4]),
      .rx_prbs_error(right_prbs_error[q*4 +: 4]), .lane_rx_reset(lane_reset),
      .quad_ready(right_quad_ready[q]), .quad_fault(right_quad_fault[q]),
      .quad_fault_reason(right_fault_reason[q*8 +: 8]),
      .test_controller_idle(right_controller_idle[q]),
      .acquisition_ready(right_acquisition_ready[q]),
      .result_capture_done(right_capture_done[q]),
      .exact_error_counts(right_exact_error_counts[q*128 +: 128]),
      .exact_error_valid(right_exact_error_valid[q*4 +: 4]),
      .exact_error_saturated(right_exact_error_saturated[q*4 +: 4]),
      .platform_diagnostics(right_diagnostics[q*224 +: 224]));
    assign right_lane_rx_reset[q*4 +: 4] = {4{lane_reset}};
  end

  direct_all_v7_quad_group_aggregate #(.QUADS(QUADS)) u_local_aggregate (
    .clk(clk_200), .resetn(local_resetn),
    .quad_ready_in({right_quad_ready,left_quad_ready}),
    .quad_fault_in({right_quad_fault,left_quad_fault}),
    .controller_idle_in({right_controller_idle,left_controller_idle}),
    .acquisition_ready_in(acquisition_participating),
    .capture_done_in(capture_participating),
    .tx_session_applied_in({right_tx_session_applied,left_tx_session_applied}),
    .fault_reason_in({right_fault_reason,left_fault_reason}),
    .diagnostics_in({right_diagnostics,left_diagnostics}),
    .quad_ready(group_ready), .quad_fault(group_fault),
    .controller_idle(group_idle), .acquisition_ready(group_acquire),
    .capture_done(group_capture), .tx_session_applied(group_session_applied),
    .fault_reason(group_fault_reason), .diagnostics(group_diagnostics));
endmodule
