`timescale 1ns/1ps

// Refclock-only replacement for the large IBERT wrappers in the isolated
// quad-124 smoke target.  It preserves the existing clock-monitor ordering
// without enabling any additional GTY channels.
module isolated_refclk_buffers (
  input  wire [5:0] left_refclk_p,
  input  wire [5:0] left_refclk_n,
  input  wire [5:0] right_refclk_p,
  input  wire [5:0] right_refclk_n,
  input  wire       managed_refclk_odiv2,
  output wire [5:0] left_refclk_odiv2,
  output wire [5:0] right_refclk_odiv2
);
  wire [5:0] unused_left_refclk, unused_right_refclk;
  wire [5:0] local_left_odiv2;

  for (genvar n = 0; n < 6; n++) begin : g_refclk
    if (n != 1) begin : g_left
      IBUFDS_GTE4 u_left (
        .I(left_refclk_p[n]), .IB(left_refclk_n[n]), .CEB(1'b0),
        .O(unused_left_refclk[n]), .ODIV2(local_left_odiv2[n])
      );
    end
    IBUFDS_GTE4 u_right (
      .I(right_refclk_p[n]), .IB(right_refclk_n[n]), .CEB(1'b0),
      .O(unused_right_refclk[n]), .ODIV2(right_refclk_odiv2[n])
    );
  end

  assign left_refclk_odiv2 = {
    local_left_odiv2[5:2], managed_refclk_odiv2, local_left_odiv2[0]
  };
endmodule
