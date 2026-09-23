`timescale 1ns/1ps

// Symmetric F1/F2 endpoint owning all direct 25.78125-Gb/s GTs q221-q234.
// FireFly and 10-Gb/s AXI C2C lanes are not instantiated.
module gt_test_direct_all_v7_top (
  input wire p_clk_200, n_clk_200,
  inout wire i2c_scl_f_sysmon, i2c_sda_f_sysmon,
  inout wire i2c_scl_f_generic, i2c_sda_f_generic,
  output wire led_f1_blue, led_f1_green, led_f1_red,
  output wire led_f2_blue, led_f2_green, led_f2_red,
  input wire p_lf_x12_r0_clk, n_lf_x12_r0_clk,
  input wire p_lf_x4_r0_clk, n_lf_x4_r0_clk,
  input wire p_rt_x12_r0_clk, n_rt_x12_r0_clk,
  input wire p_rt_x4_r0_clk, n_rt_x4_r0_clk,
  input wire p_tcds40_clk, n_tcds40_clk, p_lhc_clk, n_lhc_clk,
  input wire p_lf_r0_ab, n_lf_r0_ab, p_lf_r1_ab, n_lf_r1_ab,
  input wire p_rt_r0_l, n_rt_r0_l, p_rt_r1_l, n_rt_r1_l,
  input wire p_lf_r1_ad, n_lf_r1_ad, p_lf_r1_af, n_lf_r1_af,
  input wire p_lf_r1_r, n_lf_r1_r, p_lf_r1_u, n_lf_r1_u,
  input wire p_lf_r1_w, n_lf_r1_w, p_lf_r1_y, n_lf_r1_y,
  input wire p_rt_r1_n, n_rt_r1_n, p_rt_r1_p, n_rt_r1_p,
  input wire p_rt_r1_b, n_rt_r1_b, p_rt_r1_e, n_rt_r1_e,
  input wire p_rt_r1_g, n_rt_r1_g, p_rt_r1_i, n_rt_r1_i,
  input wire p_lf_r0_ad, n_lf_r0_ad, p_lf_r0_af, n_lf_r0_af,
  input wire p_lf_r0_r, n_lf_r0_r, p_lf_r0_u, n_lf_r0_u,
  input wire p_lf_r0_w, n_lf_r0_w, p_lf_r0_y, n_lf_r0_y,
  input wire p_rt_r0_n, n_rt_r0_n, p_rt_r0_p, n_rt_r0_p,
  input wire p_rt_r0_b, n_rt_r0_b, p_rt_r0_e, n_rt_r0_e,
  input wire p_rt_r0_g, n_rt_r0_g, p_rt_r0_i, n_rt_r0_i,
  input wire [3:0] p_a_recv, n_a_recv, p_b_recv, n_b_recv,
  input wire [3:0] p_c_recv, n_c_recv, p_d_recv, n_d_recv,
  input wire [3:0] p_e_recv, n_e_recv, p_f_recv, n_f_recv,
  input wire [3:0] p_g_recv, n_g_recv, p_h_recv, n_h_recv,
  input wire [3:0] p_i_recv, n_i_recv, p_j_recv, n_j_recv,
  input wire [3:0] p_m_recv, n_m_recv, p_n_recv, n_n_recv,
  input wire [3:0] p_o_recv, n_o_recv, p_p_recv, n_p_recv,
  output wire [3:0] p_a_xmit, n_a_xmit, p_b_xmit, n_b_xmit,
  output wire [3:0] p_c_xmit, n_c_xmit, p_d_xmit, n_d_xmit,
  output wire [3:0] p_e_xmit, n_e_xmit, p_f_xmit, n_f_xmit,
  output wire [3:0] p_g_xmit, n_g_xmit, p_h_xmit, n_h_xmit,
  output wire [3:0] p_i_xmit, n_i_xmit, p_j_xmit, n_j_xmit,
  output wire [3:0] p_m_xmit, n_m_xmit, p_n_xmit, n_n_xmit,
  output wire [3:0] p_o_xmit, n_o_xmit, p_p_xmit, n_p_xmit
);
  // This target must not expose unused FireFly ports. A constant-driven
  // top-level differential output still becomes an I/O buffer and cannot be
  // left unconstrained. Internal stubs preserve shared-core source reuse and
  // are optimized away, leaving exactly the implemented all-direct pins.
  wire [11:0] p_ff1_recv = 12'd0, n_ff1_recv = 12'd0;
  wire [11:0] p_ff2_recv = 12'd0, n_ff2_recv = 12'd0;
  wire [11:0] p_ff3_recv = 12'd0, n_ff3_recv = 12'd0;
  wire [11:0] p_ff4_recv = 12'd0, n_ff4_recv = 12'd0;
  wire [3:0] p_ff5_recv = 4'd0, n_ff5_recv = 4'd0;
  wire [3:0] p_ff6_recv = 4'd0, n_ff6_recv = 4'd0;
  wire [11:0] p_ff1_xmit, n_ff1_xmit, p_ff2_xmit, n_ff2_xmit;
  wire [11:0] p_ff3_xmit, n_ff3_xmit, p_ff4_xmit, n_ff4_xmit;
  wire [3:0] p_ff5_xmit, n_ff5_xmit, p_ff6_xmit, n_ff6_xmit;

  gt_test_direct_quad_v6_core #(
    .ENDPOINT(1), .ALL_DIRECT_V7(1'b1), .ENABLE_TX_SESSION(1'b1),
    .HARDWARE_VERSION(32'h0002_0409)
  ) u_all_direct (.*);
endmodule
