`timescale 1ns/1ps

module all_links_v1_wrapper_stub #(
  parameter integer QUAD = 0
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
  assign tx_session_applied = resetn && tx_session_active;
  assign acquisition_ready = resetn && acquisition_active;
  assign result_capture_done = resetn && result_capture_request;
  assign test_controller_idle = resetn && !acquisition_active && !measurement_enable;
  assign quad_ready = resetn;
  assign quad_fault = 1'b0;
  assign quad_fault_reason = 8'd0;
  assign platform_diagnostics = QUAD;
  assign tx_p = 4'd0; assign tx_n = 4'd0; assign rx_usrclk2 = 1'b0;
  assign rx_prbs_locked = 4'd0; assign rx_cdr_locked = 4'd0;
  assign rx_prbs_error = 4'd0; assign lane_rx_reset = !resetn;
  assign exact_error_counts = 128'd0; assign exact_error_valid = 4'd0;
  assign exact_error_saturated = 4'd0;
endmodule

module managed_all_links_left_quad_wrapper #(parameter integer QUAD=121) (
  input wire mgmt_clk, resetn, tx_session_active, output wire tx_session_applied,
  input wire refclk, refclk_odiv2, input wire [3:0] rx_p, rx_n,
  output wire [3:0] tx_p, tx_n, input wire [11:0] tx_prbs_select, rx_prbs_select,
  input wire [3:0] prbs_counter_reset, lane_running, input wire [2:0] loopback_mode,
  input wire acquisition_active, measurement_enable, result_capture_request,
  input wire [3:0] tx_error_inject_toggle, output wire rx_usrclk2,
  output wire [3:0] rx_prbs_locked, rx_cdr_locked, rx_prbs_error,
  output wire lane_rx_reset, quad_ready, quad_fault, output wire [7:0] quad_fault_reason,
  output wire test_controller_idle, acquisition_ready, result_capture_done,
  output wire [127:0] exact_error_counts,
  output wire [3:0] exact_error_valid, exact_error_saturated,
  output wire [223:0] platform_diagnostics);
  all_links_v1_wrapper_stub #(.QUAD(QUAD)) u (.*);
endmodule

module managed_direct_quad_v6_wrapper #(
  parameter bit ENABLE_TX_SESSION=1'b1, parameter integer QUAD=222,
  parameter bit ALL_DIRECT_V7=1'b0, parameter bit ALL_LINKS_LEFT_V1=1'b0,
  parameter bit STAGED_RX_ACQUISITION=1'b1,
  parameter bit REQUIRE_ERROR_FREE_QUALIFICATION=1'b0
) (
  input wire mgmt_clk, resetn, tx_session_active, output wire tx_session_applied,
  input wire refclk, refclk_odiv2, input wire [3:0] rx_p, rx_n,
  output wire [3:0] tx_p, tx_n, input wire [11:0] tx_prbs_select, rx_prbs_select,
  input wire [3:0] prbs_counter_reset, lane_running, input wire [2:0] loopback_mode,
  input wire acquisition_active, measurement_enable, result_capture_request,
  input wire [3:0] tx_error_inject_toggle, output wire rx_usrclk2,
  output wire [3:0] rx_prbs_locked, rx_cdr_locked, rx_prbs_error,
  output wire lane_rx_reset, quad_ready, quad_fault, output wire [7:0] quad_fault_reason,
  output wire test_controller_idle, acquisition_ready, result_capture_done,
  output wire [127:0] exact_error_counts,
  output wire [3:0] exact_error_valid, exact_error_saturated,
  output wire [223:0] platform_diagnostics);
  all_links_v1_wrapper_stub #(.QUAD(QUAD)) u (.*);
endmodule
