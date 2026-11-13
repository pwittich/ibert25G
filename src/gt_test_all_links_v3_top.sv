`timescale 1ns/1ps

// V3-specific implementation; historical modules remain unchanged at 34c73bb.

// Symmetric source milestone owning all 112 board 25G lanes. This image has
// no IBERT and no 10G AXI C2C ownership. An external TX session intentionally
// drives PRBS31 on every lane, including every outward-facing FireFly TX.
module gt_test_all_links_v3_top #(
  parameter logic [31:0] HARDWARE_VERSION = 32'h0002_0502
) (
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
  input wire [11:0] p_ff1_recv, n_ff1_recv, p_ff2_recv, n_ff2_recv,
  input wire [11:0] p_ff3_recv, n_ff3_recv, p_ff4_recv, n_ff4_recv,
  output wire [11:0] p_ff1_xmit, n_ff1_xmit, p_ff2_xmit, n_ff2_xmit,
  output wire [11:0] p_ff3_xmit, n_ff3_xmit, p_ff4_xmit, n_ff4_xmit,
  input wire [3:0] p_ff5_recv, n_ff5_recv, p_ff6_recv, n_ff6_recv,
  output wire [3:0] p_ff5_xmit, n_ff5_xmit, p_ff6_xmit, n_ff6_xmit,
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
  all_links_v3_core #(
    .ENDPOINT(1), .ALL_LINKS_V1(1'b1), .ENABLE_TX_SESSION(1'b1),
    .HARDWARE_VERSION(HARDWARE_VERSION)
  ) u_all_links (.*);
endmodule
