`timescale 1ns/1ps

// Target-specific left-side wrapper for the symmetric all-links image.
// The underlying proven v12 datapath applies the management session request
// in TXUSRCLK2 and returns a two-flop acknowledgement in the management
// domain.  Keeping this alias separate prevents any FireFly-v5 semantic change.
module managed_all_links_left_quad_wrapper #(
  parameter integer QUAD = 121
) (
  input wire mgmt_clk, resetn, tx_session_active,
  output wire tx_session_applied,
  input wire refclk, refclk_odiv2,
  input wire [3:0] rx_p, rx_n,
  output wire [3:0] tx_p, tx_n,
  input wire [11:0] tx_prbs_select, rx_prbs_select,
  input wire [3:0] prbs_counter_reset, lane_running,
  input wire [2:0] loopback_mode,
  input wire acquisition_active, measurement_enable, result_capture_request,
  input wire [3:0] tx_error_inject_toggle,
  output wire rx_usrclk2,
  output wire [3:0] rx_prbs_locked, rx_cdr_locked, rx_prbs_error,
  output wire lane_rx_reset, quad_ready, quad_fault,
  output wire [7:0] quad_fault_reason,
  output wire test_controller_idle, acquisition_ready, result_capture_done,
  output wire [127:0] exact_error_counts,
  output wire [3:0] exact_error_valid, exact_error_saturated,
  output wire [223:0] platform_diagnostics
);
  managed_direct_quad_v6_wrapper #(
    .QUAD(QUAD), .ALL_LINKS_LEFT_V1(1'b1), .ENABLE_TX_SESSION(1'b1)
  ) u_managed_left (.*);
endmodule
