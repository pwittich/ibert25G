module gt_native_left121_123_functional_elab_top (
  input wire p_clk_200, input wire n_clk_200, input wire p_refclk, input wire n_refclk
);
  wire clk_raw, clk;
  IBUFDS u_clk (.I(p_clk_200), .IB(n_clk_200), .O(clk_raw));
  BUFG u_clk_bufg (.I(clk_raw), .O(clk));
  reg [7:0] por = 0;
  always @(posedge clk) por <= {por[6:0], 1'b1};
  wire resetn = &por;
  managed_firefly1_group_wrapper u_group (
    .mgmt_clk(clk), .resetn(resetn), .refclk_p(p_refclk), .refclk_n(n_refclk),
    .rx_p(12'b0), .rx_n(12'b0), .tx_p(), .tx_n(), .tx_prbs_select(36'b0),
    .rx_prbs_select(36'b0), .prbs_counter_reset(12'b0), .lane_running(12'b0),
    .loopback_mode(3'b010), .acquisition_active(1'b0), .measurement_enable(1'b0),
    .result_capture_request(1'b0), .tx_error_inject_toggle(12'b0), .rx_usrclk2(),
    .rx_prbs_locked(), .rx_cdr_locked(), .rx_prbs_error(), .lane_rx_reset(),
    .refclk_odiv2(), .platform_ready(), .platform_fault(), .platform_fault_reason(),
    .platform_idle(), .acquisition_ready(), .result_capture_done(),
    .exact_error_counts(), .exact_error_valid(), .exact_error_saturated());
endmodule
