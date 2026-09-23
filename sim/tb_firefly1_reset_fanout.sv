`timescale 1ns/1ps
// Wiring-only model: actual group wrapper, abstract quad boundary/GT buffer.
module IBUFDS_GTE4(input I, IB, CEB, output O, ODIV2);
  assign O=I; assign ODIV2=I;
endmodule
module managed_native_left_quad_wrapper #(
  parameter integer QUAD=121,
  parameter bit ENABLE_TX_SESSION=0, STAGED_RX_ACQUISITION=0,
  parameter bit REQUIRE_ERROR_FREE_QUALIFICATION=0
)(
  input mgmt_clk, resetn, refclk, refclk_odiv2, tx_session_active,
  input [3:0] rx_p, rx_n, output [3:0] tx_p, tx_n,
  input [11:0] tx_prbs_select, rx_prbs_select,
  input [3:0] prbs_counter_reset, lane_running,
  input [2:0] loopback_mode,
  input acquisition_active, measurement_enable, result_capture_request,
  input [3:0] tx_error_inject_toggle,
  output rx_usrclk2, output [3:0] rx_prbs_locked, rx_cdr_locked, rx_prbs_error,
  output lane_rx_reset, quad_ready, quad_fault,
  output [7:0] quad_fault_reason,
  output test_controller_idle, acquisition_ready, result_capture_done,
  output [127:0] exact_error_counts,
  output [3:0] exact_error_valid, exact_error_saturated,
  output [223:0] platform_diagnostics
);
  assign lane_rx_reset = QUAD==121 ? !resetn : QUAD==122 ? refclk : !refclk;
  assign rx_usrclk2=mgmt_clk;
  assign quad_ready=1; assign quad_fault=0; assign quad_fault_reason=0;
  assign test_controller_idle=1; assign acquisition_ready=1; assign result_capture_done=1;
  assign platform_diagnostics=0;
  assign tx_p=0; assign tx_n=0; assign rx_prbs_locked=0;
  assign rx_cdr_locked=0; assign rx_prbs_error=0;
  assign exact_error_counts=0; assign exact_error_valid=0; assign exact_error_saturated=0;
endmodule
module tb_firefly1_reset_fanout;
  logic resetn=0, refclk=0;
  wire [11:0] v4_reset, v5_reset;
  managed_firefly1_group_wrapper #(.ENABLE_TX_SESSION(0)) legacy (
    .mgmt_clk(1'b0), .resetn(resetn), .refclk_p(refclk), .refclk_n(!refclk),
    .tx_session_active(1'b0), .lane_rx_reset(v4_reset));
  managed_firefly1_group_wrapper #(.ENABLE_TX_SESSION(1)) current_v5 (
    .mgmt_clk(1'b0), .resetn(resetn), .refclk_p(refclk), .refclk_n(!refclk),
    .tx_session_active(1'b0), .lane_rx_reset(v5_reset));
  initial begin
    #10;
    if (v5_reset != 12'hf0f || v4_reset != 12'h101) $fatal(1,"quad 0/2 fanout mismatch");
    resetn=1; refclk=1;
    #10;
    if (v5_reset != 12'h0f0 || v4_reset != 12'h010) $fatal(1,"quad 1 fanout mismatch");
    $display("PASS: v5 broadcasts each quad reset to four lanes; legacy mapping unchanged");
    $finish;
  end
endmodule
