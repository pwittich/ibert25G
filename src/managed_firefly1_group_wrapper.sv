`timescale 1ns/1ps

// Twelve-lane FireFly-1 owner: q121/q122/q123 are independent native reset
// domains but present one selection-aware platform to the existing engine.
module managed_firefly1_group_wrapper #(
  parameter bit ENABLE_TX_SESSION = 1'b0,
  parameter bit STAGED_RX_ACQUISITION = 1'b0,
  parameter bit REQUIRE_ERROR_FREE_QUALIFICATION = 1'b1
) (
  input wire mgmt_clk, input wire resetn, input wire refclk_p, input wire refclk_n,
  input wire tx_session_active,
  input wire [11:0] rx_p, input wire [11:0] rx_n, output wire [11:0] tx_p, output wire [11:0] tx_n,
  input wire [35:0] tx_prbs_select, input wire [35:0] rx_prbs_select,
  input wire [11:0] prbs_counter_reset, input wire [11:0] lane_running,
  input wire [2:0] loopback_mode, input wire acquisition_active, input wire measurement_enable,
  input wire result_capture_request, input wire [11:0] tx_error_inject_toggle,
  output wire [11:0] rx_usrclk2, output wire [11:0] rx_prbs_locked,
  output wire [11:0] rx_cdr_locked, output wire [11:0] rx_prbs_error,
  output wire [11:0] lane_rx_reset, output wire refclk_odiv2,
  output wire platform_ready, output wire platform_fault, output wire [7:0] platform_fault_reason,
  output wire platform_idle, output wire acquisition_ready, output wire result_capture_done,
  output wire [383:0] exact_error_counts, output wire [11:0] exact_error_valid,
  output wire [11:0] exact_error_saturated,
  output wire [223:0] platform_diagnostics
);
  wire [2:0] ready, fault, idle, acquire_ready, capture_done;
  wire [2:0] quad_lane_reset;
  wire [23:0] fault_reason;
  wire [223:0] diagnostics [0:2];
  // The first faulted quad (lowest index for simultaneous faults) owns FE.
  logic diagnostic_quad_latched = 0;
  logic [1:0] diagnostic_quad = 0;
  always_ff @(posedge mgmt_clk) begin
    if (!resetn) begin
      diagnostic_quad_latched <= 0; diagnostic_quad <= 0;
    end else if (!diagnostic_quad_latched && |fault) begin
      diagnostic_quad_latched <= 1;
      diagnostic_quad <= fault[0] ? 0 : fault[1] ? 1 : 2;
    end
  end
  assign platform_diagnostics = diagnostics[diagnostic_quad];
  wire [2:0] refclk_odiv2_by_quad, rx_usrclk2_by_quad;
  wire refclk; IBUFDS_GTE4 u_refclk (.I(refclk_p),.IB(refclk_n),.CEB(1'b0),.O(refclk),.ODIV2(refclk_odiv2));
  generate
  for (genvar q = 0; q < 3; q++) begin : g_quad
    managed_native_left_quad_wrapper #(.QUAD(121+q),
      .ENABLE_TX_SESSION(ENABLE_TX_SESSION),
      .STAGED_RX_ACQUISITION(STAGED_RX_ACQUISITION),
      .REQUIRE_ERROR_FREE_QUALIFICATION(REQUIRE_ERROR_FREE_QUALIFICATION)) u_quad (
      .mgmt_clk(mgmt_clk), .resetn(resetn), .refclk(refclk), .refclk_odiv2(refclk_odiv2),
      .tx_session_active(tx_session_active),
      .rx_p(rx_p[q*4 +: 4]), .rx_n(rx_n[q*4 +: 4]),
      .tx_p(tx_p[q*4 +: 4]), .tx_n(tx_n[q*4 +: 4]),
      .tx_prbs_select(tx_prbs_select[q*12 +: 12]), .rx_prbs_select(rx_prbs_select[q*12 +: 12]),
      .prbs_counter_reset(prbs_counter_reset[q*4 +: 4]), .lane_running(lane_running[q*4 +: 4]),
      .loopback_mode(loopback_mode), .acquisition_active(acquisition_active),
      .measurement_enable(measurement_enable), .result_capture_request(result_capture_request),
      .tx_error_inject_toggle(tx_error_inject_toggle[q*4 +: 4]),
      .rx_usrclk2(rx_usrclk2_by_quad[q]), .rx_prbs_locked(rx_prbs_locked[q*4 +: 4]),
      .rx_cdr_locked(rx_cdr_locked[q*4 +: 4]), .rx_prbs_error(rx_prbs_error[q*4 +: 4]),
      .lane_rx_reset(quad_lane_reset[q]),
      .quad_ready(ready[q]), .quad_fault(fault[q]), .quad_fault_reason(fault_reason[q*8 +: 8]),
      .test_controller_idle(idle[q]), .acquisition_ready(acquire_ready[q]),
      .result_capture_done(capture_done[q]), .exact_error_counts(exact_error_counts[q*128 +: 128]),
      .exact_error_valid(exact_error_valid[q*4 +: 4]), .exact_error_saturated(exact_error_saturated[q*4 +: 4]),
      .platform_diagnostics(diagnostics[q]));
    assign rx_usrclk2[q*4 +: 4] = {4{rx_usrclk2_by_quad[q]}};
    // v5 fixes the legacy scalar-to-vector zero extension without changing
    // historical target behavior: every v5 lane sees its quad's RX reset.
    assign lane_rx_reset[q*4 +: 4] = ENABLE_TX_SESSION ?
      {4{quad_lane_reset[q]}} : {3'b000, quad_lane_reset[q]};
  end
  endgenerate
  assign platform_ready = &ready;
  assign platform_fault = |fault;
  assign platform_fault_reason = fault_reason[7:0] | fault_reason[15:8] | fault_reason[23:16];
  assign platform_idle = &idle;
  assign acquisition_ready = &acquire_ready;
  assign result_capture_done = &capture_done;
endmodule
