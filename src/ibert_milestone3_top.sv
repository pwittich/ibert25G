`timescale 1ns/1ps

// Standalone-IBERT portion of the full Milestone 3 image.  The left core is
// reduced to 13 quads (52 lanes) because quad 124 is exclusively owned by
// managed_quad124_wrapper; the right core remains 14 quads (56 lanes).
// This module preserves the golden board-lane ordering at those two cores.
module ibert_milestone3_top (
  input wire p_lf_r0_ad, n_lf_r0_ad,
  input wire p_lf_r0_r, n_lf_r0_r, p_lf_r0_u, n_lf_r0_u,
  input wire p_lf_r0_w, n_lf_r0_w, p_lf_r0_y, n_lf_r0_y,
  input wire p_rt_r0_n, n_rt_r0_n, p_rt_r0_p, n_rt_r0_p,
  input wire p_rt_r0_b, n_rt_r0_b, p_rt_r0_e, n_rt_r0_e,
  input wire p_rt_r0_g, n_rt_r0_g, p_rt_r0_i, n_rt_r0_i,
  input wire [11:0] p_ff1_recv, n_ff1_recv, p_ff2_recv, n_ff2_recv,
  input wire [11:0] p_ff3_recv, n_ff3_recv, p_ff4_recv, n_ff4_recv,
  output wire [11:0] p_ff1_xmit, n_ff1_xmit, p_ff2_xmit, n_ff2_xmit,
  output wire [11:0] p_ff3_xmit, n_ff3_xmit, p_ff4_xmit, n_ff4_xmit,
  input wire [3:0] p_ff6_recv, n_ff6_recv,
  output wire [3:0] p_ff6_xmit, n_ff6_xmit,
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
  output wire [3:0] p_o_xmit, n_o_xmit, p_p_xmit, n_p_xmit,
  input wire managed_refclk_odiv2,
  output wire [5:0] left_refclk_odiv2,
  output wire [5:0] right_refclk_odiv2,
  output wire left_ibert_sysclk,
  output wire right_ibert_sysclk
);
  function automatic [11:0] reverse12(input [11:0] value);
    // FireFly 3 is physically reversed relative to the generated IBERT vector.
    for (int bit_index = 0; bit_index < 12; bit_index++)
      reverse12[bit_index] = value[11-bit_index];
  endfunction

  wire [5:0] left_refclk_p =
    // Refclock vector index 1 is intentionally absent here: it belongs to
    // managed quad 124.  Its ODIV2 is reinserted by the reduced wrapper so the
    // externally visible clock-monitor ABI does not change.
    {p_lf_r0_y, p_lf_r0_w, p_lf_r0_u, p_lf_r0_r, 1'b0, p_lf_r0_ad};
  wire [5:0] left_refclk_n =
    {n_lf_r0_y, n_lf_r0_w, n_lf_r0_u, n_lf_r0_r, 1'b0, n_lf_r0_ad};
  wire [5:0] right_refclk_p =
    {p_rt_r0_i, p_rt_r0_g, p_rt_r0_e, p_rt_r0_b, p_rt_r0_p, p_rt_r0_n};
  wire [5:0] right_refclk_n =
    {n_rt_r0_i, n_rt_r0_g, n_rt_r0_e, n_rt_r0_b, n_rt_r0_p, n_rt_r0_n};
  wire [51:0] left_rx_p =
    // Concatenation order matches active physical quads 121-123 and 125-134.
    {p_ff4_recv, p_ff6_recv, reverse12(p_ff3_recv), p_ff2_recv, p_ff1_recv};
  wire [51:0] left_rx_n =
    {n_ff4_recv, n_ff6_recv, reverse12(n_ff3_recv), n_ff2_recv, n_ff1_recv};
  wire [51:0] left_tx_p, left_tx_n;
  wire [55:0] right_rx_p =
    // Right-side ordering is identical to the golden 56-lane IBERT image.
    {p_j_recv, p_i_recv, p_h_recv, p_g_recv, p_f_recv, p_e_recv,
     p_d_recv, p_c_recv, p_b_recv, p_a_recv, p_p_recv, p_o_recv,
     p_n_recv, p_m_recv};
  wire [55:0] right_rx_n =
    {n_j_recv, n_i_recv, n_h_recv, n_g_recv, n_f_recv, n_e_recv,
     n_d_recv, n_c_recv, n_b_recv, n_a_recv, n_p_recv, n_o_recv,
     n_n_recv, n_m_recv};
  wire [55:0] right_tx_p, right_tx_n;

  assign p_ff1_xmit = left_tx_p[11:0];
  assign n_ff1_xmit = left_tx_n[11:0];
  assign p_ff2_xmit = left_tx_p[23:12];
  assign n_ff2_xmit = left_tx_n[23:12];
  assign p_ff3_xmit = reverse12(left_tx_p[35:24]);
  assign n_ff3_xmit = reverse12(left_tx_n[35:24]);
  assign p_ff6_xmit = left_tx_p[39:36];
  assign n_ff6_xmit = left_tx_n[39:36];
  assign p_ff4_xmit = left_tx_p[51:40];
  assign n_ff4_xmit = left_tx_n[51:40];

  assign p_m_xmit = right_tx_p[3:0];    assign n_m_xmit = right_tx_n[3:0];
  assign p_n_xmit = right_tx_p[7:4];    assign n_n_xmit = right_tx_n[7:4];
  assign p_o_xmit = right_tx_p[11:8];   assign n_o_xmit = right_tx_n[11:8];
  assign p_p_xmit = right_tx_p[15:12];  assign n_p_xmit = right_tx_n[15:12];
  assign p_a_xmit = right_tx_p[19:16];  assign n_a_xmit = right_tx_n[19:16];
  assign p_b_xmit = right_tx_p[23:20];  assign n_b_xmit = right_tx_n[23:20];
  assign p_c_xmit = right_tx_p[27:24];  assign n_c_xmit = right_tx_n[27:24];
  assign p_d_xmit = right_tx_p[31:28];  assign n_d_xmit = right_tx_n[31:28];
  assign p_e_xmit = right_tx_p[35:32];  assign n_e_xmit = right_tx_n[35:32];
  assign p_f_xmit = right_tx_p[39:36];  assign n_f_xmit = right_tx_n[39:36];
  assign p_g_xmit = right_tx_p[43:40];  assign n_g_xmit = right_tx_n[43:40];
  assign p_h_xmit = right_tx_p[47:44];  assign n_h_xmit = right_tx_n[47:44];
  assign p_i_xmit = right_tx_p[51:48];  assign n_i_xmit = right_tx_n[51:48];
  assign p_j_xmit = right_tx_p[55:52];  assign n_j_xmit = right_tx_n[55:52];

  ibert_left_milestone3_wrapper u_ibert_left (
    // Handwritten structural adapter around the Vivado-owned reduced core.
    .refclk_p(left_refclk_p), .refclk_n(left_refclk_n),
    .managed_refclk_odiv2(managed_refclk_odiv2),
    .rx_p(left_rx_p), .rx_n(left_rx_n), .tx_p(left_tx_p), .tx_n(left_tx_n),
    .refclk_odiv2(left_refclk_odiv2), .ibert_sysclk(left_ibert_sysclk)
  );

  ibert_ultrascale_gty_r u_ibert_right (
    // Unmodified full right-side IBERT core.
    .gty_refclk0p_i(right_refclk_p), .gty_refclk0n_i(right_refclk_n),
    .gty_refclk0_odiv2_o(right_refclk_odiv2),
    .gty_sysclk_o(right_ibert_sysclk),
    .gty_rxp_i(right_rx_p), .gty_rxn_i(right_rx_n),
    .gty_txp_o(right_tx_p), .gty_txn_o(right_tx_n)
  );
endmodule
