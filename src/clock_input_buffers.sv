module clock_input_buffers (
  input  wire [5:0] fabric_clk_p,
  input  wire [5:0] fabric_clk_n,
  input  wire [15:0] gty_refclk_p,
  input  wire [15:0] gty_refclk_n,
  output wire [5:0] fabric_clk,
  output wire [15:0] gty_refclk_odiv2
);
  wire [5:0] fabric_clk_raw;
  wire [15:0] gty_refclk_odiv2_raw;
  for (genvar n = 0; n < 6; n++) begin : g_fabric_clock
    IBUFDS #(.DIFF_TERM("TRUE"), .IBUF_LOW_PWR("FALSE")) u_ibufds (
      .I(fabric_clk_p[n]), .IB(fabric_clk_n[n]), .O(fabric_clk_raw[n])
    );
    BUFG u_bufg (.I(fabric_clk_raw[n]), .O(fabric_clk[n]));
  end
  for (genvar n = 0; n < 16; n++) begin : g_gty_reference
    wire unused_full_rate;
    IBUFDS_GTE4 u_ibufds_gte4 (
      .I(gty_refclk_p[n]), .IB(gty_refclk_n[n]), .CEB(1'b0),
      .O(unused_full_rate), .ODIV2(gty_refclk_odiv2_raw[n])
    );
    BUFG_GT u_bufg_gt (
      .I(gty_refclk_odiv2_raw[n]), .O(gty_refclk_odiv2[n]),
      .CE(1'b1), .CEMASK(1'b0), .CLR(1'b0), .CLRMASK(1'b0), .DIV(3'b000)
    );
  end
endmodule
