`timescale 1ns/1ps

// Site-specific direct-link endpoint; only the owned GT quad is exposed.
module gt_test_direct_quad_v6_f2_top (

  input wire p_clk_200, n_clk_200,
  inout wire i2c_scl_f_sysmon, i2c_sda_f_sysmon, i2c_scl_f_generic, i2c_sda_f_generic,
  output wire led_f1_blue, led_f1_green, led_f1_red, led_f2_blue, led_f2_green, led_f2_red,
  input wire p_lf_x12_r0_clk, n_lf_x12_r0_clk, p_lf_x4_r0_clk, n_lf_x4_r0_clk,
  input wire p_rt_x12_r0_clk, n_rt_x12_r0_clk, p_rt_x4_r0_clk, n_rt_x4_r0_clk,
  input wire p_tcds40_clk, n_tcds40_clk, p_lhc_clk, n_lhc_clk,
  input wire p_lf_r0_ab, n_lf_r0_ab, p_lf_r1_ab, n_lf_r1_ab,
  input wire p_rt_r0_l, n_rt_r0_l, p_rt_r1_l, n_rt_r1_l,
  input wire p_lf_r1_ad, n_lf_r1_ad, p_lf_r1_af, n_lf_r1_af,
  input wire p_lf_r1_r, n_lf_r1_r, p_lf_r1_u, n_lf_r1_u, p_lf_r1_w, n_lf_r1_w, p_lf_r1_y, n_lf_r1_y,
  input wire p_rt_r1_n, n_rt_r1_n, p_rt_r1_p, n_rt_r1_p, p_rt_r1_b, n_rt_r1_b,
  input wire p_rt_r1_e, n_rt_r1_e, p_rt_r1_g, n_rt_r1_g, p_rt_r1_i, n_rt_r1_i,
  input wire p_lf_r0_ad, n_lf_r0_ad, p_lf_r0_af, n_lf_r0_af, p_lf_r0_r, n_lf_r0_r,
  input wire p_lf_r0_u, n_lf_r0_u, p_lf_r0_w, n_lf_r0_w, p_lf_r0_y, n_lf_r0_y,
  input wire p_rt_r0_n, n_rt_r0_n, p_rt_r0_p, n_rt_r0_p, p_rt_r0_b, n_rt_r0_b,
  input wire p_rt_r0_e, n_rt_r0_e, p_rt_r0_g, n_rt_r0_g, p_rt_r0_i, n_rt_r0_i,
  input wire [3:0] p_i_recv, n_i_recv,
  output wire [3:0] p_i_xmit, n_i_xmit
);
  // 0x00020403: complete q233 golden-IBERT RX primitive settings.
  gt_test_direct_quad_v6_core #(.ENDPOINT(2), .HARDWARE_VERSION(32'h0002_0403)) u_isolated (
    .p_clk_200(p_clk_200), .n_clk_200(n_clk_200),
    .i2c_scl_f_sysmon(i2c_scl_f_sysmon), .i2c_sda_f_sysmon(i2c_sda_f_sysmon),
    .i2c_scl_f_generic(i2c_scl_f_generic), .i2c_sda_f_generic(i2c_sda_f_generic),
    .led_f1_blue(led_f1_blue), .led_f1_green(led_f1_green), .led_f1_red(led_f1_red),
    .led_f2_blue(led_f2_blue), .led_f2_green(led_f2_green), .led_f2_red(led_f2_red),
    .p_lf_x12_r0_clk(p_lf_x12_r0_clk), .n_lf_x12_r0_clk(n_lf_x12_r0_clk),
    .p_lf_x4_r0_clk(p_lf_x4_r0_clk), .n_lf_x4_r0_clk(n_lf_x4_r0_clk),
    .p_rt_x12_r0_clk(p_rt_x12_r0_clk), .n_rt_x12_r0_clk(n_rt_x12_r0_clk),
    .p_rt_x4_r0_clk(p_rt_x4_r0_clk), .n_rt_x4_r0_clk(n_rt_x4_r0_clk),
    .p_tcds40_clk(p_tcds40_clk), .n_tcds40_clk(n_tcds40_clk), .p_lhc_clk(p_lhc_clk), .n_lhc_clk(n_lhc_clk),
    .p_lf_r0_ab(p_lf_r0_ab), .n_lf_r0_ab(n_lf_r0_ab), .p_lf_r1_ab(p_lf_r1_ab), .n_lf_r1_ab(n_lf_r1_ab),
    .p_rt_r0_l(p_rt_r0_l), .n_rt_r0_l(n_rt_r0_l), .p_rt_r1_l(p_rt_r1_l), .n_rt_r1_l(n_rt_r1_l),
    .p_lf_r1_ad(p_lf_r1_ad), .n_lf_r1_ad(n_lf_r1_ad), .p_lf_r1_af(p_lf_r1_af), .n_lf_r1_af(n_lf_r1_af),
    .p_lf_r1_r(p_lf_r1_r), .n_lf_r1_r(n_lf_r1_r), .p_lf_r1_u(p_lf_r1_u), .n_lf_r1_u(n_lf_r1_u),
    .p_lf_r1_w(p_lf_r1_w), .n_lf_r1_w(n_lf_r1_w), .p_lf_r1_y(p_lf_r1_y), .n_lf_r1_y(n_lf_r1_y),
    .p_rt_r1_n(p_rt_r1_n), .n_rt_r1_n(n_rt_r1_n), .p_rt_r1_p(p_rt_r1_p), .n_rt_r1_p(n_rt_r1_p),
    .p_rt_r1_b(p_rt_r1_b), .n_rt_r1_b(n_rt_r1_b), .p_rt_r1_e(p_rt_r1_e), .n_rt_r1_e(n_rt_r1_e),
    .p_rt_r1_g(p_rt_r1_g), .n_rt_r1_g(n_rt_r1_g), .p_rt_r1_i(p_rt_r1_i), .n_rt_r1_i(n_rt_r1_i),
    .p_lf_r0_ad(p_lf_r0_ad), .n_lf_r0_ad(n_lf_r0_ad), .p_lf_r0_af(p_lf_r0_af), .n_lf_r0_af(n_lf_r0_af),
    .p_lf_r0_r(p_lf_r0_r), .n_lf_r0_r(n_lf_r0_r), .p_lf_r0_u(p_lf_r0_u), .n_lf_r0_u(n_lf_r0_u),
    .p_lf_r0_w(p_lf_r0_w), .n_lf_r0_w(n_lf_r0_w), .p_lf_r0_y(p_lf_r0_y), .n_lf_r0_y(n_lf_r0_y),
    .p_rt_r0_n(p_rt_r0_n), .n_rt_r0_n(n_rt_r0_n), .p_rt_r0_p(p_rt_r0_p), .n_rt_r0_p(n_rt_r0_p),
    .p_rt_r0_b(p_rt_r0_b), .n_rt_r0_b(n_rt_r0_b), .p_rt_r0_e(p_rt_r0_e), .n_rt_r0_e(n_rt_r0_e),
    .p_rt_r0_g(p_rt_r0_g), .n_rt_r0_g(n_rt_r0_g), .p_rt_r0_i(p_rt_r0_i), .n_rt_r0_i(n_rt_r0_i),
    .p_i_recv(p_i_recv), .n_i_recv(n_i_recv), .p_i_xmit(p_i_xmit), .n_i_xmit(n_i_xmit)
  );
endmodule
