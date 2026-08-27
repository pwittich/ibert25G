`timescale 1ns/1ps

// Milestone-3 structural wrapper for the build-local left IBERT core after
// physical quad 124 is disabled.  Active quads remain ordered 121-123,
// 125-134.  Refclk input 1 belongs exclusively to the managed quad wrapper.
module ibert_left_milestone3_wrapper (
  input  wire [5:0]  refclk_p,
  input  wire [5:0]  refclk_n,
  input  wire         managed_refclk_odiv2,
  input  wire [51:0] rx_p,
  input  wire [51:0] rx_n,
  output wire [51:0] tx_p,
  output wire [51:0] tx_n,
  output wire [5:0]  refclk_odiv2,
  output wire         ibert_sysclk
);
  wire [5:0] refclk;
  wire [5:0] local_odiv2;
  logic [12:0] qrefclk0, qnorthrefclk0, qsouthrefclk0;
  logic [12:0] qrefclk00, qnorthrefclk00, qsouthrefclk00;
  wire [12:0] zeros = 13'd0;

  IBUFDS_GTE4 u_refclk_0 (.I(refclk_p[0]), .IB(refclk_n[0]),
    .CEB(1'b0), .O(refclk[0]), .ODIV2(local_odiv2[0]));
  IBUFDS_GTE4 u_refclk_2 (.I(refclk_p[2]), .IB(refclk_n[2]),
    .CEB(1'b0), .O(refclk[2]), .ODIV2(local_odiv2[2]));
  IBUFDS_GTE4 u_refclk_3 (.I(refclk_p[3]), .IB(refclk_n[3]),
    .CEB(1'b0), .O(refclk[3]), .ODIV2(local_odiv2[3]));
  IBUFDS_GTE4 u_refclk_4 (.I(refclk_p[4]), .IB(refclk_n[4]),
    .CEB(1'b0), .O(refclk[4]), .ODIV2(local_odiv2[4]));
  IBUFDS_GTE4 u_refclk_5 (.I(refclk_p[5]), .IB(refclk_n[5]),
    .CEB(1'b0), .O(refclk[5]), .ODIV2(local_odiv2[5]));

  assign refclk_odiv2 = {
    local_odiv2[5:2], managed_refclk_odiv2, local_odiv2[0]
  };
  BUFG_GT u_sysclk_bufg (
    .I(local_odiv2[0]), .O(ibert_sysclk), .CE(1'b1), .CEMASK(1'b0),
    .CLR(1'b0), .CLRMASK(1'b0), .DIV(3'b000)
  );

  always_comb begin
    qrefclk0 = 0;
    qnorthrefclk0 = 0;
    qsouthrefclk0 = 0;
    qrefclk00 = 0;
    qnorthrefclk00 = 0;
    qsouthrefclk00 = 0;

    // Quads 121-123 use MGTREFCLK0_122.
    qsouthrefclk0[0] = refclk[0];
    qsouthrefclk00[0] = refclk[0];
    qrefclk0[1] = refclk[0];
    qrefclk00[1] = refclk[0];
    qnorthrefclk0[2] = refclk[0];
    qnorthrefclk00[2] = refclk[0];

    // Quad 124 is intentionally absent. Quads 125-127 use refclk 126.
    qsouthrefclk0[3] = refclk[2];
    qsouthrefclk00[3] = refclk[2];
    qrefclk0[4] = refclk[2];
    qrefclk00[4] = refclk[2];
    qnorthrefclk0[5] = refclk[2];
    qnorthrefclk00[5] = refclk[2];

    // Quads 128-130 use refclk 129.
    qsouthrefclk0[6] = refclk[3];
    qsouthrefclk00[6] = refclk[3];
    qrefclk0[7] = refclk[3];
    qrefclk00[7] = refclk[3];
    qnorthrefclk0[8] = refclk[3];
    qnorthrefclk00[8] = refclk[3];

    // Quad 131 uses its local refclk; quads 132-134 use refclk 133.
    qrefclk0[9] = refclk[4];
    qrefclk00[9] = refclk[4];
    qsouthrefclk0[10] = refclk[5];
    qsouthrefclk00[10] = refclk[5];
    qrefclk0[11] = refclk[5];
    qrefclk00[11] = refclk[5];
    qnorthrefclk0[12] = refclk[5];
    qnorthrefclk00[12] = refclk[5];
  end

  ibert_ultrascale_gty_core_l u_ibert_gty_core (
    .txn_o(tx_n), .txp_o(tx_p), .rxn_i(rx_n), .rxp_i(rx_p),
    .clk(ibert_sysclk),
    .gtrefclk0_i(qrefclk0), .gtrefclk1_i(zeros),
    .gtnorthrefclk0_i(qnorthrefclk0), .gtnorthrefclk1_i(zeros),
    .gtsouthrefclk0_i(qsouthrefclk0), .gtsouthrefclk1_i(zeros),
    .gtrefclk00_i(qrefclk00), .gtrefclk10_i(zeros),
    .gtrefclk01_i(zeros), .gtrefclk11_i(zeros),
    .gtnorthrefclk00_i(qnorthrefclk00), .gtnorthrefclk10_i(zeros),
    .gtnorthrefclk01_i(zeros), .gtnorthrefclk11_i(zeros),
    .gtsouthrefclk00_i(qsouthrefclk00), .gtsouthrefclk10_i(zeros),
    .gtsouthrefclk01_i(zeros), .gtsouthrefclk11_i(zeros)
  );
endmodule
