`timescale 1ns/1ps
// Each board reference has exactly one input buffer. Only the selected
// endpoint's local REFCLK0 O output drives the managed GT common.
module direct_quad_v6_refclk_buffers #(
  parameter integer ENDPOINT = 1
) (
  input wire [5:0] left_refclk_p, left_refclk_n,
  input wire [5:0] right_refclk_p, right_refclk_n,
  output wire [5:0] left_refclk_odiv2, right_refclk_odiv2,
  output wire [5:0] left_refclk, right_refclk,
  output wire managed_refclk
);
  assign managed_refclk = right_refclk[ENDPOINT == 1 ? 0 : 5];
  for (genvar n = 0; n < 6; n++) begin : g_refclk
    IBUFDS_GTE4 #(.REFCLK_EN_TX_PATH(1'b0), .REFCLK_HROW_CK_SEL(2'b00),
                 .REFCLK_ICNTL_RX(2'b00)) u_left (
      .I(left_refclk_p[n]), .IB(left_refclk_n[n]), .CEB(1'b0),
      .O(left_refclk[n]), .ODIV2(left_refclk_odiv2[n]));
    IBUFDS_GTE4 #(.REFCLK_EN_TX_PATH(1'b0), .REFCLK_HROW_CK_SEL(2'b00),
                 .REFCLK_ICNTL_RX(2'b00)) u_right (
      .I(right_refclk_p[n]), .IB(right_refclk_n[n]), .CEB(1'b0),
      .O(right_refclk[n]), .ODIV2(right_refclk_odiv2[n]));
  end
endmodule
