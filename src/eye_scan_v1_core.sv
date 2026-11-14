`timescale 1ns/1ps

// Separate eye-scan v1 implementation, based on preserved v3 commit a82d50b.

// Site-specific direct-quad test: F1 N/q222 or F2 I/q233.
module eye_scan_v1_core #(
  parameter integer ENDPOINT = 1,
  parameter bit ALL_DIRECT_V7 = 1'b0,
  parameter bit ALL_LINKS_V1 = 1'b1,
  parameter bit ENABLE_TX_SESSION = 1'b1,
  parameter logic [31:0] HARDWARE_VERSION = 32'h0002_0503
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
  localparam integer FIRST_LANE = ENDPOINT == 1 ? 60 : 104;
  localparam logic [111:0] MANAGED_MASK = ALL_LINKS_V1 ?
    112'hffffffffffffffffffffffffffff : ALL_DIRECT_V7 ?
    112'hffffffffffffff00000000000000 : (112'hf << FIRST_LANE);
  wire clk_200_raw, clk_200;
  wire clk_100_raw, clk_100, clk_325_raw, clk_325;
  wire clock_mmcm_feedback_raw, clock_mmcm_feedback, clock_mmcm_locked;
  (* KEEP = "TRUE" *) wire ibert_debug_clk_50;
  logic [7:0] power_on_reset = 8'hff;
  wire reset = |power_on_reset;
  wire resetn = !reset;
  wire [5:0] left_refclk_odiv2, right_refclk_odiv2;
  wire [5:0] left_refclk_mon, right_refclk_mon;
  wire left_ibert_sysclk, right_ibert_sysclk;
  wire managed_refclk;
  wire [5:0] firefly_refclk, direct_refclk;
  wire [3:0] managed_tx_p, managed_tx_n;
  wire managed_lane_reset;
  wire [5:0] fabric_clocks;
  wire [15:0] extra_gty_odiv2;
  wire [36:0] monitored_clocks;
  logic [31:0] frequency_khz [0:36];
  logic frequencies_valid;
  logic [31:0] debug_register [0:1] = '{default:32'h0};
  logic [26:0] heartbeat_counter = 0;

  wire engine_interrupt, status_firmware_alive, status_engine_busy;
  wire engine_status_fault;
  wire [68:0] eye_controls;
  wire eye_fatal;
  wire [1023:0] eye_bank_packets,eye_return_packets;
  wire [3:0] eye_bank_fatal,eye_return_fatal;
  logic [255:0] eye_selected_packet=0;
  wire [4:0] eye_relative_quad = eye_controls[6:2] < 14 ? eye_controls[6:2] : eye_controls[6:2]-14;
  wire [1:0] eye_return_bank = eye_relative_quad < 3 ? 0 : eye_relative_quad < 7 ? 1 :
    eye_relative_quad < 11 ? 2 : 3;
  for (genvar e=0;e<4;e++) begin : g_eye_return
    (* KEEP_HIERARCHY = "yes" *) all_links_v3_return_pipeline #(.WIDTH(257)) u_return (
      .clk(clk_200),.data({eye_bank_fatal[e],eye_bank_packets[e*256 +: 256]}),
      .stage_two({eye_return_fatal[e],eye_return_packets[e*256 +: 256]}));
  end
  always_ff @(posedge clk_200) eye_selected_packet<=eye_return_packets[eye_return_bank*256 +: 256];
  wire quad_ready, quad_fault, managed_rx_clk;
  wire [3:0] managed_lane_rx_reset;
  wire [55:0] firefly_rx_p, firefly_rx_n, firefly_tx_p, firefly_tx_n;
  wire [55:0] direct_rx_p, direct_rx_n, direct_tx_p, direct_tx_n;
  wire [111:0] all_lane_rx_reset, all_prbs_locked, all_cdr_locked, all_prbs_error;
  wire [111:0] all_rx_clk;
  wire [28*128-1:0] all_exact_error_counts;
  wire [111:0] all_exact_error_valid, all_exact_error_saturated;
  wire [27:0] all_quad_ready, all_quad_fault, all_controller_idle;
  wire [27:0] all_acquisition_ready, all_capture_done;
  wire [27:0] all_tx_session_applied;
  wire [27:0] config_tx_mask, config_rx_mask, config_tx_observed, config_bank_epoch_ack;
  wire config_epoch;
  wire [28*8-1:0] all_fault_reason;
  wire [28*224-1:0] all_platform_diagnostics;
  wire [7:0] quad_fault_reason;
  wire [15:0] quad_diagnostic;
  wire [223:0] platform_diagnostics;
  wire [255:0] recovery_diagnostics;
  wire [255:0] diagnostic_record;
  wire [1023:0] quad_diagnostic_records;
  logic [255:0] diagnostic_stage = 0;
  logic [1:0] diagnostic_bank_stage = 0;
  wire [7:0] diagnostic_selector;
  wire [3:0] diagnostic_within = diagnostic_selector < 8'h8e
    ? diagnostic_selector - 8'h80 : diagnostic_selector - 8'h8e;
  always_ff @(posedge clk_200) begin
    diagnostic_bank_stage <= diagnostic_within < 3 ? 0 :
      diagnostic_within < 7 ? 1 : diagnostic_within < 11 ? 2 : 3;
    diagnostic_stage <= quad_diagnostic_records[diagnostic_bank_stage*256 +: 256];
  end
  wire [1:0] diagnostic_bank;
  wire [31:0] engine_protocol_debug;
  wire test_controller_idle, acquisition_ready, result_capture_done;
  wire [2:0] quad_state;
  wire [3:0] managed_prbs_locked, managed_cdr_locked, managed_prbs_error;
  wire [127:0] managed_exact_error_counts;
  wire [3:0] managed_exact_error_valid, managed_exact_error_saturated;

  wire [111:0] rx_clocks, rx_resets, rx_prbs_locked, rx_cdr_locked;
  wire [112*16-1:0] rx_prbs_errors;
  wire [112*3-1:0] tx_prbs_select, rx_prbs_select;
  wire [111:0] prbs_counter_reset, lane_running;
  wire measurement_enable, measurement_run_toggle;
  wire controls_enable, acquisition_active;
  wire tx_session_active;
  wire [1:0] session_tag;
  wire [7:0] group_session_ack_tag;
  wire [3:0] group_session_on_ack, group_session_off_ack;
  wire [3:0] group_config_idle;
  wire config_controllers_idle;
  wire tx_session_ready_to_engine;
  wire managed_tx_session_applied;
  wire result_capture_request;
  wire [112*32-1:0] exact_error_counts;
  wire [111:0] exact_error_valid, exact_error_saturated;
  wire [2:0] loopback_mode;
  wire [111:0] tx_error_inject_toggle;
  wire [111:0] accepted_lane_mask;
  wire [27:0] accepted_quad_selected;

  for (genvar accepted_q = 0; accepted_q < 14; accepted_q++) begin : g_accepted_quad_mask
    assign accepted_quad_selected[accepted_q] =
      |accepted_lane_mask[accepted_q*4 +: 4];
    assign accepted_quad_selected[14+accepted_q] =
      |accepted_lane_mask[56+accepted_q*4 +: 4];
  end

  wire [31:0] m_axi_awaddr, m_axi_wdata, m_axi_araddr, m_axi_rdata;
  wire [2:0] m_axi_awprot, m_axi_arprot;
  wire [3:0] m_axi_wstrb;
  wire [1:0] m_axi_bresp, m_axi_rresp;
  wire m_axi_awvalid, m_axi_awready, m_axi_wvalid, m_axi_wready;
  wire m_axi_bvalid, m_axi_bready, m_axi_arvalid, m_axi_arready;
  wire m_axi_rvalid, m_axi_rready;

  wire [7:0] i2c_address, i2c_write_data;
  wire i2c_write_enable;
  logic [7:0] i2c_read_data, i2c_read_data_next;
  wire [7:0] mailbox_read_data, mailbox_read_data_next;

  IBUFDS #(.DIFF_TERM("TRUE"), .IBUF_LOW_PWR("FALSE")) u_clk_200_ibuf
    (.I(p_clk_200), .IB(n_clk_200), .O(clk_200_raw));
  BUFG u_clk_200_bufg (.I(clk_200_raw), .O(clk_200));

  MMCME4_BASE #(
    // 200 MHz * 6.5 = 1300-MHz VCO; divide by 13 and 4 for the required
    // 100-MHz management-monitor and 325-MHz fabric clocks.
    .BANDWIDTH("OPTIMIZED"), .CLKFBOUT_MULT_F(6.500),
    .CLKIN1_PERIOD(5.000), .CLKOUT0_DIVIDE_F(13.000),
    .CLKOUT1_DIVIDE(4), .DIVCLK_DIVIDE(1), .STARTUP_WAIT("FALSE")
  ) u_clock_mmcm (
    .CLKIN1(clk_200), .CLKFBIN(clock_mmcm_feedback), .RST(1'b0),
    .PWRDWN(1'b0), .CLKFBOUT(clock_mmcm_feedback_raw), .CLKFBOUTB(),
    .CLKOUT0(clk_100_raw), .CLKOUT0B(), .CLKOUT1(clk_325_raw),
    .CLKOUT1B(), .CLKOUT2(), .CLKOUT2B(), .CLKOUT3(), .CLKOUT3B(),
    .CLKOUT4(), .CLKOUT5(), .CLKOUT6(), .LOCKED(clock_mmcm_locked)
  );
  BUFG u_clock_mmcm_feedback_bufg
    (.I(clock_mmcm_feedback_raw), .O(clock_mmcm_feedback));
  BUFG u_clk_100_bufg (.I(clk_100_raw), .O(clk_100));
  BUFG u_clk_325_bufg (.I(clk_325_raw), .O(clk_325));
  BUFGCE_DIV #(.BUFGCE_DIVIDE(4)) u_ibert_debug_clk_bufg (
    // Vendor IBERT debug/XSDB timing assumes 50 MHz.  Do not reconnect this
    // network directly to the 200-MHz board clock.
    .I(clk_200_raw), .CE(1'b1), .CLR(1'b0), .O(ibert_debug_clk_50)
  );

  always_ff @(posedge clk_200) begin
    power_on_reset <= {power_on_reset[6:0], 1'b0};
    if (reset)
      heartbeat_counter <= 0;
    else
      heartbeat_counter <= heartbeat_counter + 1'b1;
  end

  direct_quad_v6_refclk_buffers #(.ENDPOINT(ENDPOINT)) u_refclk_buffers (
    .left_refclk_p({p_lf_r0_y, p_lf_r0_w, p_lf_r0_u, p_lf_r0_r, p_lf_r0_af, p_lf_r0_ad}),
    .left_refclk_n({n_lf_r0_y, n_lf_r0_w, n_lf_r0_u, n_lf_r0_r, n_lf_r0_af, n_lf_r0_ad}),
    .right_refclk_p({p_rt_r0_i, p_rt_r0_g, p_rt_r0_e, p_rt_r0_b, p_rt_r0_p, p_rt_r0_n}),
    .right_refclk_n({n_rt_r0_i, n_rt_r0_g, n_rt_r0_e, n_rt_r0_b, n_rt_r0_p, n_rt_r0_n}),
    .managed_refclk(managed_refclk), .left_refclk(firefly_refclk),
    .right_refclk(direct_refclk),
    .left_refclk_odiv2(left_refclk_odiv2), .right_refclk_odiv2(right_refclk_odiv2));
  assign left_ibert_sysclk = 1'b0;
  assign right_ibert_sysclk = 1'b0;
  function automatic [11:0] reverse12(input [11:0] value);
    for (int bit_index = 0; bit_index < 12; bit_index++)
      reverse12[bit_index] = value[11-bit_index];
  endfunction
  assign firefly_rx_p = {p_ff4_recv, p_ff6_recv, reverse12(p_ff3_recv),
                         p_ff2_recv, p_ff5_recv, p_ff1_recv};
  assign firefly_rx_n = {n_ff4_recv, n_ff6_recv, reverse12(n_ff3_recv),
                         n_ff2_recv, n_ff5_recv, n_ff1_recv};
  assign direct_rx_p = {p_j_recv, p_i_recv, p_h_recv, p_g_recv, p_f_recv,
    p_e_recv, p_d_recv, p_c_recv, p_b_recv, p_a_recv, p_p_recv, p_o_recv,
    p_n_recv, p_m_recv};
  assign direct_rx_n = {n_j_recv, n_i_recv, n_h_recv, n_g_recv, n_f_recv,
    n_e_recv, n_d_recv, n_c_recv, n_b_recv, n_a_recv, n_p_recv, n_o_recv,
    n_n_recv, n_m_recv};

  generate if (ALL_LINKS_V1) begin : g_all_links
    // The ABI/global-lane order is FF1, FF5, FF2, FF3, FF6, FF4, then
    // direct q221-q234. FireFly 3 alone is reversed at this boundary.
    assign p_ff1_xmit = firefly_tx_p[11:0];
    assign n_ff1_xmit = firefly_tx_n[11:0];
    assign p_ff5_xmit = firefly_tx_p[15:12];
    assign n_ff5_xmit = firefly_tx_n[15:12];
    assign p_ff2_xmit = firefly_tx_p[27:16];
    assign n_ff2_xmit = firefly_tx_n[27:16];
    assign p_ff3_xmit = reverse12(firefly_tx_p[39:28]);
    assign n_ff3_xmit = reverse12(firefly_tx_n[39:28]);
    assign p_ff6_xmit = firefly_tx_p[43:40];
    assign n_ff6_xmit = firefly_tx_n[43:40];
    assign p_ff4_xmit = firefly_tx_p[55:44];
    assign n_ff4_xmit = firefly_tx_n[55:44];
    assign {p_j_xmit, p_i_xmit, p_h_xmit, p_g_xmit, p_f_xmit, p_e_xmit,
      p_d_xmit, p_c_xmit, p_b_xmit, p_a_xmit, p_p_xmit, p_o_xmit,
      p_n_xmit, p_m_xmit} = direct_tx_p;
    assign {n_j_xmit, n_i_xmit, n_h_xmit, n_g_xmit, n_f_xmit, n_e_xmit,
      n_d_xmit, n_c_xmit, n_b_xmit, n_a_xmit, n_p_xmit, n_o_xmit,
      n_n_xmit, n_m_xmit} = direct_tx_n;

    wire [3:0] group_ready, group_fault, group_idle, group_acquire;
    wire [3:0] group_capture, group_session_applied;
    wire [31:0] group_reason;
    wire [895:0] group_diagnostics;
    wire [13:0] left_quad_rxclk, right_quad_rxclk;
    wire [13:0] left_quad_refclk = {{3{firefly_refclk[5]}}, firefly_refclk[4],
      {3{firefly_refclk[3]}}, {3{firefly_refclk[2]}}, firefly_refclk[1],
      {3{firefly_refclk[0]}}};
    wire [13:0] left_quad_refclk_odiv2 = {{3{left_refclk_odiv2[5]}},
      left_refclk_odiv2[4], {3{left_refclk_odiv2[3]}},
      {3{left_refclk_odiv2[2]}}, left_refclk_odiv2[1],
      {3{left_refclk_odiv2[0]}}};
    wire [13:0] right_quad_refclk = {{3{direct_refclk[5]}}, direct_refclk[4],
      {3{direct_refclk[3]}}, {3{direct_refclk[2]}}, direct_refclk[1],
      {3{direct_refclk[0]}}};
    wire [13:0] right_quad_refclk_odiv2 = {{3{right_refclk_odiv2[5]}},
      right_refclk_odiv2[4], {3{right_refclk_odiv2[3]}},
      {3{right_refclk_odiv2[2]}}, right_refclk_odiv2[1],
      {3{right_refclk_odiv2[0]}}};

`define ALL_LINKS_BANK(NAME, SLR, OFFSET, NQUADS) \
    (* KEEP_HIERARCHY = "yes" *) \
    eye_scan_v1_slr_bank #(.LEFT_FIRST(OFFSET), .COUNT(NQUADS), \
      .LOCALIZE_QUAD_RESET(1'b1)) NAME ( \
      .clk_200(clk_200), .resetn(resetn), \
      .diagnostic_selector_in(diagnostic_selector), \
      .quad_diagnostic_record(quad_diagnostic_records[SLR*256 +: 256]), \
      .eye_controls_in(eye_controls), .eye_bank_packet(eye_bank_packets[SLR*256 +: 256]), \
      .eye_bank_fatal(eye_bank_fatal[SLR]), \
      .left_tx_enable_in(config_tx_mask[OFFSET +: NQUADS]), \
      .right_tx_enable_in(config_tx_mask[14+OFFSET +: NQUADS]), \
      .left_rx_enable_in(config_rx_mask[OFFSET +: NQUADS]), \
      .right_rx_enable_in(config_rx_mask[14+OFFSET +: NQUADS]), \
      .config_epoch_in(config_epoch), \
      .session_tag_in(session_tag), \
      .group_session_ack_tag(group_session_ack_tag[SLR*2 +: 2]), \
      .group_session_on_ack(group_session_on_ack[SLR]), \
      .group_session_off_ack(group_session_off_ack[SLR]), \
      .group_config_idle(group_config_idle[SLR]), \
      .left_tx_observed(config_tx_observed[OFFSET +: NQUADS]), \
      .right_tx_observed(config_tx_observed[14+OFFSET +: NQUADS]), \
      .left_epoch_ack(config_bank_epoch_ack[OFFSET +: NQUADS]), \
      .right_epoch_ack(config_bank_epoch_ack[14+OFFSET +: NQUADS]), \
      .controls_in({tx_session_active,loopback_mode,acquisition_active,measurement_enable,result_capture_request}), \
      .left_quad_selected_in(accepted_quad_selected[OFFSET +: NQUADS]), \
      .right_quad_selected_in(accepted_quad_selected[14+OFFSET +: NQUADS]), \
      .left_refclk(left_quad_refclk[OFFSET +: NQUADS]), \
      .left_refclk_odiv2(left_quad_refclk_odiv2[OFFSET +: NQUADS]), \
      .right_refclk(right_quad_refclk[OFFSET +: NQUADS]), \
      .right_refclk_odiv2(right_quad_refclk_odiv2[OFFSET +: NQUADS]), \
      .left_rx_p(firefly_rx_p[OFFSET*4 +: NQUADS*4]), .left_rx_n(firefly_rx_n[OFFSET*4 +: NQUADS*4]), \
      .right_rx_p(direct_rx_p[OFFSET*4 +: NQUADS*4]), .right_rx_n(direct_rx_n[OFFSET*4 +: NQUADS*4]), \
      .left_tx_p(firefly_tx_p[OFFSET*4 +: NQUADS*4]), .left_tx_n(firefly_tx_n[OFFSET*4 +: NQUADS*4]), \
      .right_tx_p(direct_tx_p[OFFSET*4 +: NQUADS*4]), .right_tx_n(direct_tx_n[OFFSET*4 +: NQUADS*4]), \
      .left_tx_prbs_select(tx_prbs_select[OFFSET*12 +: NQUADS*12]), \
      .left_rx_prbs_select(rx_prbs_select[OFFSET*12 +: NQUADS*12]), \
      .right_tx_prbs_select(tx_prbs_select[(56+OFFSET*4)*3 +: NQUADS*12]), \
      .right_rx_prbs_select(rx_prbs_select[(56+OFFSET*4)*3 +: NQUADS*12]), \
      .left_prbs_counter_reset(prbs_counter_reset[OFFSET*4 +: NQUADS*4]), \
      .left_lane_running(lane_running[OFFSET*4 +: NQUADS*4]), \
      .right_prbs_counter_reset(prbs_counter_reset[56+OFFSET*4 +: NQUADS*4]), \
      .right_lane_running(lane_running[56+OFFSET*4 +: NQUADS*4]), \
      .left_tx_error_inject_toggle(tx_error_inject_toggle[OFFSET*4 +: NQUADS*4]), \
      .right_tx_error_inject_toggle(tx_error_inject_toggle[56+OFFSET*4 +: NQUADS*4]), \
      .left_rx_usrclk2(left_quad_rxclk[OFFSET +: NQUADS]), \
      .right_rx_usrclk2(right_quad_rxclk[OFFSET +: NQUADS]), \
      .left_prbs_locked(all_prbs_locked[OFFSET*4 +: NQUADS*4]), \
      .left_cdr_locked(all_cdr_locked[OFFSET*4 +: NQUADS*4]), \
      .left_prbs_error(all_prbs_error[OFFSET*4 +: NQUADS*4]), \
      .right_prbs_locked(all_prbs_locked[56+OFFSET*4 +: NQUADS*4]), \
      .right_cdr_locked(all_cdr_locked[56+OFFSET*4 +: NQUADS*4]), \
      .right_prbs_error(all_prbs_error[56+OFFSET*4 +: NQUADS*4]), \
      .left_lane_rx_reset(all_lane_rx_reset[OFFSET*4 +: NQUADS*4]), \
      .right_lane_rx_reset(all_lane_rx_reset[56+OFFSET*4 +: NQUADS*4]), \
      .left_quad_ready(all_quad_ready[OFFSET +: NQUADS]), .left_quad_fault(all_quad_fault[OFFSET +: NQUADS]), \
      .right_quad_ready(all_quad_ready[14+OFFSET +: NQUADS]), .right_quad_fault(all_quad_fault[14+OFFSET +: NQUADS]), \
      .left_controller_idle(all_controller_idle[OFFSET +: NQUADS]), \
      .left_acquisition_ready(all_acquisition_ready[OFFSET +: NQUADS]), \
      .left_capture_done(all_capture_done[OFFSET +: NQUADS]), \
      .left_tx_session_applied(all_tx_session_applied[OFFSET +: NQUADS]), \
      .right_controller_idle(all_controller_idle[14+OFFSET +: NQUADS]), \
      .right_acquisition_ready(all_acquisition_ready[14+OFFSET +: NQUADS]), \
      .right_capture_done(all_capture_done[14+OFFSET +: NQUADS]), \
      .right_tx_session_applied(all_tx_session_applied[14+OFFSET +: NQUADS]), \
      .left_fault_reason(all_fault_reason[OFFSET*8 +: NQUADS*8]), \
      .right_fault_reason(all_fault_reason[(14+OFFSET)*8 +: NQUADS*8]), \
      .left_diagnostics(all_platform_diagnostics[OFFSET*224 +: NQUADS*224]), \
      .right_diagnostics(all_platform_diagnostics[(14+OFFSET)*224 +: NQUADS*224]), \
      .left_exact_error_counts(all_exact_error_counts[OFFSET*128 +: NQUADS*128]), \
      .right_exact_error_counts(all_exact_error_counts[(14+OFFSET)*128 +: NQUADS*128]), \
      .left_exact_error_valid(all_exact_error_valid[OFFSET*4 +: NQUADS*4]), \
      .left_exact_error_saturated(all_exact_error_saturated[OFFSET*4 +: NQUADS*4]), \
      .right_exact_error_valid(all_exact_error_valid[56+OFFSET*4 +: NQUADS*4]), \
      .right_exact_error_saturated(all_exact_error_saturated[56+OFFSET*4 +: NQUADS*4]), \
      .group_ready(group_ready[SLR]), .group_fault(group_fault[SLR]), \
      .group_idle(group_idle[SLR]), .group_acquire(group_acquire[SLR]), \
      .group_capture(group_capture[SLR]), .group_session_applied(group_session_applied[SLR]), \
      .group_fault_reason(group_reason[SLR*8 +: 8]), \
      .group_diagnostics(group_diagnostics[SLR*224 +: 224]));

    `ALL_LINKS_BANK(g_bank_slr0, 0, 0, 3)
    `ALL_LINKS_BANK(g_bank_slr1, 1, 3, 4)
    `ALL_LINKS_BANK(g_bank_slr2, 2, 7, 4)
    `ALL_LINKS_BANK(g_bank_slr3, 3, 11, 3)
`undef ALL_LINKS_BANK

    for (genvar q = 0; q < 14; q++) begin : g_bank_rxclk_fanout
      assign all_rx_clk[q*4 +: 4] = {4{left_quad_rxclk[q]}};
      assign all_rx_clk[56+q*4 +: 4] = {4{right_quad_rxclk[q]}};
    end
    eye_scan_v1_quad_aggregate u_quad_aggregate (
      .session_requested(tx_session_active), .session_tag(session_tag),
      .group_session_ack_tag(group_session_ack_tag),
      .group_session_on_ack(group_session_on_ack), .group_session_off_ack(group_session_off_ack),
      .group_config_idle(group_config_idle), .config_idle(config_controllers_idle),
      .clk(clk_200), .resetn(resetn), .group_ready(group_ready),
      .group_fault(group_fault), .group_idle(group_idle),
      .group_acquire(group_acquire), .group_capture(group_capture),
      .group_session_applied(group_session_applied),
      .group_reason(group_reason), .group_diagnostics(group_diagnostics),
      .quad_ready(quad_ready), .quad_fault(quad_fault),
      .controller_idle(test_controller_idle), .acquisition_ready(acquisition_ready),
      .capture_done(result_capture_done), .tx_session_applied(tx_session_ready_to_engine),
      .fault_reason(quad_fault_reason), .diagnostics(platform_diagnostics));
    assign managed_prbs_locked = all_prbs_locked[3:0];
    assign managed_cdr_locked = all_cdr_locked[3:0];
    assign managed_prbs_error = all_prbs_error[3:0];
    assign managed_exact_error_counts = all_exact_error_counts[127:0];
    assign managed_exact_error_valid = all_exact_error_valid[3:0];
    assign managed_exact_error_saturated = all_exact_error_saturated[3:0];
    assign managed_lane_rx_reset = all_lane_rx_reset[3:0];
    assign managed_rx_clk = all_rx_clk[0];
  end else if (ALL_DIRECT_V7) begin : g_all_direct
    assign {p_ff1_xmit, n_ff1_xmit, p_ff2_xmit, n_ff2_xmit,
            p_ff3_xmit, n_ff3_xmit, p_ff4_xmit, n_ff4_xmit,
            p_ff5_xmit, n_ff5_xmit, p_ff6_xmit, n_ff6_xmit} = '0;
    assign {p_j_xmit, p_i_xmit, p_h_xmit, p_g_xmit, p_f_xmit, p_e_xmit,
      p_d_xmit, p_c_xmit, p_b_xmit, p_a_xmit, p_p_xmit, p_o_xmit,
      p_n_xmit, p_m_xmit} = direct_tx_p;
    assign {n_j_xmit, n_i_xmit, n_h_xmit, n_g_xmit, n_f_xmit, n_e_xmit,
      n_d_xmit, n_c_xmit, n_b_xmit, n_a_xmit, n_p_xmit, n_o_xmit,
      n_n_xmit, n_m_xmit} = direct_tx_n;
    wire [6:0] local_controls [0:3];
    for (genvar slr = 0; slr < 4; slr++) begin : g_control_slr
      // The four banks intentionally carry identical values, but they are
      // separate physical launch points in the four SLRs.  DONT_TOUCH keeps
      // synthesis from merging them back into one cross-die fanout tree.
      (* KEEP_HIERARCHY = "yes", DONT_TOUCH = "yes" *)
      direct_all_v7_control_pipeline
        u_control_pipeline (
          .clk(clk_200),
          .controls_in({tx_session_active, loopback_mode,
                        acquisition_active, measurement_enable,
                        result_capture_request}),
          .controls_out(local_controls[slr]));
    end
    for (genvar q = 0; q < 14; q++) begin : g_quad
      localparam integer QUAD = 221 + q;
      localparam integer SLR = q < 3 ? 0 : q < 7 ? 1 : q < 11 ? 2 : 3;
      localparam integer REF = q < 3 ? 0 : q == 3 ? 1 : q < 7 ? 2 :
        q < 10 ? 3 : q == 10 ? 4 : 5;
      wire lane_reset;
      managed_direct_quad_v6_wrapper #(
        .QUAD(QUAD), .ALL_DIRECT_V7(1'b1),
        .ENABLE_TX_SESSION(ENABLE_TX_SESSION)
      ) u_managed_direct (
        .mgmt_clk(clk_200), .resetn(resetn),
        .tx_session_active(local_controls[SLR][6]),
        .tx_session_applied(all_tx_session_applied[q]),
        .refclk(direct_refclk[REF]), .refclk_odiv2(right_refclk_odiv2[REF]),
        .rx_p(direct_rx_p[q*4 +: 4]), .rx_n(direct_rx_n[q*4 +: 4]),
        .tx_p(direct_tx_p[q*4 +: 4]), .tx_n(direct_tx_n[q*4 +: 4]),
        .tx_prbs_select(tx_prbs_select[(56+q*4)*3 +: 12]),
        .rx_prbs_select(rx_prbs_select[(56+q*4)*3 +: 12]),
        .prbs_counter_reset(prbs_counter_reset[56+q*4 +: 4]),
        .lane_running(lane_running[56+q*4 +: 4]),
        .loopback_mode(local_controls[SLR][5:3]),
        .acquisition_active(local_controls[SLR][2]),
        .measurement_enable(local_controls[SLR][1]),
        .result_capture_request(local_controls[SLR][0]),
        .tx_error_inject_toggle(tx_error_inject_toggle[56+q*4 +: 4]),
        .rx_usrclk2(all_rx_clk[q*4]),
        .rx_prbs_locked(all_prbs_locked[q*4 +: 4]),
        .rx_cdr_locked(all_cdr_locked[q*4 +: 4]),
        .rx_prbs_error(all_prbs_error[q*4 +: 4]), .lane_rx_reset(lane_reset),
        .quad_ready(all_quad_ready[q]), .quad_fault(all_quad_fault[q]),
        .quad_fault_reason(all_fault_reason[q*8 +: 8]),
        .test_controller_idle(all_controller_idle[q]),
        .acquisition_ready(all_acquisition_ready[q]),
        .result_capture_done(all_capture_done[q]),
        .exact_error_counts(all_exact_error_counts[q*128 +: 128]),
        .exact_error_valid(all_exact_error_valid[q*4 +: 4]),
        .exact_error_saturated(all_exact_error_saturated[q*4 +: 4]),
        .platform_diagnostics(all_platform_diagnostics[q*224 +: 224]));
      assign all_lane_rx_reset[q*4 +: 4] = {4{lane_reset}};
      assign all_rx_clk[q*4 + 1 +: 3] = {3{all_rx_clk[q*4]}};
    end
    direct_all_v7_quad_aggregate u_quad_aggregate (
      .clk(clk_200), .resetn(resetn),
      .quad_ready_in(all_quad_ready[13:0]), .quad_fault_in(all_quad_fault[13:0]),
      .controller_idle_in(all_controller_idle[13:0]),
      .acquisition_ready_in(all_acquisition_ready[13:0]), .capture_done_in(all_capture_done[13:0]),
      .tx_session_applied_in(all_tx_session_applied[13:0]),
      .fault_reason_in(all_fault_reason[111:0]), .diagnostics_in(all_platform_diagnostics[3135:0]),
      .quad_ready(quad_ready), .quad_fault(quad_fault),
      .controller_idle(test_controller_idle), .acquisition_ready(acquisition_ready),
      .capture_done(result_capture_done), .fault_reason(quad_fault_reason),
      .tx_session_applied(tx_session_ready_to_engine),
      .diagnostics(platform_diagnostics));
    assign managed_prbs_locked = all_prbs_locked[3:0];
    assign managed_cdr_locked = all_cdr_locked[3:0];
    assign managed_prbs_error = all_prbs_error[3:0];
    assign managed_exact_error_counts = all_exact_error_counts[127:0];
    assign managed_exact_error_valid = all_exact_error_valid[3:0];
    assign managed_exact_error_saturated = all_exact_error_saturated[3:0];
    assign managed_lane_rx_reset = all_lane_rx_reset[3:0];
    assign managed_rx_clk = all_rx_clk[0];
  end else begin : g_one_direct
    assign {p_ff1_xmit, n_ff1_xmit, p_ff2_xmit, n_ff2_xmit,
            p_ff3_xmit, n_ff3_xmit, p_ff4_xmit, n_ff4_xmit,
            p_ff5_xmit, n_ff5_xmit, p_ff6_xmit, n_ff6_xmit} = '0;
    assign {p_a_xmit, n_a_xmit, p_b_xmit, n_b_xmit,
            p_c_xmit, n_c_xmit, p_d_xmit, n_d_xmit,
            p_e_xmit, n_e_xmit, p_f_xmit, n_f_xmit,
            p_g_xmit, n_g_xmit, p_h_xmit, n_h_xmit,
            p_j_xmit, n_j_xmit, p_m_xmit, n_m_xmit,
            p_o_xmit, n_o_xmit, p_p_xmit, n_p_xmit} = '0;
    assign p_n_xmit = ENDPOINT == 1 ? managed_tx_p : 4'd0;
    assign n_n_xmit = ENDPOINT == 1 ? managed_tx_n : 4'd0;
    assign p_i_xmit = ENDPOINT == 2 ? managed_tx_p : 4'd0;
    assign n_i_xmit = ENDPOINT == 2 ? managed_tx_n : 4'd0;

  managed_direct_quad_v6_wrapper #(
    .QUAD(ENDPOINT == 1 ? 222 : 233), .ENABLE_TX_SESSION(ENABLE_TX_SESSION)
  ) u_managed_direct (
    .mgmt_clk(clk_200), .resetn(resetn), .tx_session_active(tx_session_active),
    .tx_session_applied(managed_tx_session_applied),
    .refclk(managed_refclk), .refclk_odiv2(right_refclk_odiv2[ENDPOINT == 1 ? 0 : 5]),
    .rx_p(ENDPOINT == 1 ? p_n_recv : p_i_recv),
    .rx_n(ENDPOINT == 1 ? n_n_recv : n_i_recv),
    .tx_p(managed_tx_p), .tx_n(managed_tx_n),
    .tx_prbs_select(tx_prbs_select[FIRST_LANE*3 +: 12]),
    .rx_prbs_select(rx_prbs_select[FIRST_LANE*3 +: 12]),
    .prbs_counter_reset(prbs_counter_reset[FIRST_LANE +: 4]),
    .lane_running(lane_running[FIRST_LANE +: 4]),
    .loopback_mode(loopback_mode), .acquisition_active(acquisition_active),
    .measurement_enable(measurement_enable), .result_capture_request(result_capture_request),
    .tx_error_inject_toggle(tx_error_inject_toggle[FIRST_LANE +: 4]),
    .rx_usrclk2(managed_rx_clk), .rx_prbs_locked(managed_prbs_locked),
    .rx_cdr_locked(managed_cdr_locked), .rx_prbs_error(managed_prbs_error),
    .lane_rx_reset(managed_lane_reset), .quad_ready(quad_ready), .quad_fault(quad_fault),
    .quad_fault_reason(quad_fault_reason), .test_controller_idle(test_controller_idle),
    .acquisition_ready(acquisition_ready), .result_capture_done(result_capture_done),
    .exact_error_counts(managed_exact_error_counts), .exact_error_valid(managed_exact_error_valid),
    .exact_error_saturated(managed_exact_error_saturated), .platform_diagnostics(platform_diagnostics));
  assign tx_session_ready_to_engine = managed_tx_session_applied;
  // One reset source must reach every selected lane, not just the first lane.
  assign managed_lane_rx_reset = {4{managed_lane_reset}};
  end endgenerate
  assign quad_diagnostic = 16'd0;
  assign recovery_diagnostics = 256'd0;
  assign diagnostic_record = diagnostic_stage;
  assign quad_state = 3'd0;

  for (genvar lane = 0; lane < 112; lane++) begin : g_lane_inputs
    if (ALL_LINKS_V1 || (ALL_DIRECT_V7 && lane >= 56) ||
        (!ALL_DIRECT_V7 && lane >= FIRST_LANE && lane < FIRST_LANE + 4)) begin
      // Only managed lanes use asynchronous RXUSRCLK2 snapshots and native
      // DRP error counts.  The other lane engines exist for ABI width but are
      // unselectable and cannot drive the IBERT-owned GTs.
      localparam integer MANAGED_INDEX = ALL_LINKS_V1 ? lane :
        (ALL_DIRECT_V7 ? lane - 56 : lane - FIRST_LANE);
      assign rx_clocks[lane] = (ALL_LINKS_V1 || ALL_DIRECT_V7) ? all_rx_clk[MANAGED_INDEX] : managed_rx_clk;
      assign rx_resets[lane] = (ALL_LINKS_V1 || ALL_DIRECT_V7) ? all_lane_rx_reset[MANAGED_INDEX] : managed_lane_rx_reset[MANAGED_INDEX];
      assign rx_prbs_locked[lane] = (ALL_LINKS_V1 || ALL_DIRECT_V7) ? all_prbs_locked[MANAGED_INDEX] : managed_prbs_locked[MANAGED_INDEX];
      assign rx_cdr_locked[lane] = (ALL_LINKS_V1 || ALL_DIRECT_V7) ? all_cdr_locked[MANAGED_INDEX] : managed_cdr_locked[MANAGED_INDEX];
      assign rx_prbs_errors[lane*16 +: 16] =
        {15'd0, (ALL_LINKS_V1 || ALL_DIRECT_V7) ? all_prbs_error[MANAGED_INDEX] : managed_prbs_error[MANAGED_INDEX]};
      assign exact_error_counts[lane*32 +: 32] =
        (ALL_LINKS_V1 || ALL_DIRECT_V7) ? all_exact_error_counts[MANAGED_INDEX*32 +: 32] :
          managed_exact_error_counts[MANAGED_INDEX*32 +: 32];
      // Publish native DRP error counts after the post-lock reset.
      assign exact_error_valid[lane] = (ALL_LINKS_V1 || ALL_DIRECT_V7) ? all_exact_error_valid[MANAGED_INDEX] : managed_exact_error_valid[MANAGED_INDEX];
      assign exact_error_saturated[lane] = (ALL_LINKS_V1 || ALL_DIRECT_V7) ? all_exact_error_saturated[MANAGED_INDEX] : managed_exact_error_saturated[MANAGED_INDEX];
    end else begin
      assign rx_clocks[lane] = clk_200;
      assign rx_resets[lane] = !resetn;
      assign rx_prbs_locked[lane] = 1'b0;
      assign rx_cdr_locked[lane] = 1'b0;
      assign rx_prbs_errors[lane*16 +: 16] = 16'd0;
      assign exact_error_counts[lane*32 +: 32] = 32'd0;
      assign exact_error_valid[lane] = 1'b0;
      assign exact_error_saturated[lane] = 1'b0;
    end
  end

  gt_test_milestone3_bd_wrapper u_subsystem (
    // The MicroBlaze subsystem is a validating/interrupt supervisor.  It does
    // not own BER timing or poll counters during acquisition.
    .clk_200(clk_200), .reset(reset), .engine_interrupt(engine_interrupt),
    .M_AXI_ENGINE_awaddr(m_axi_awaddr), .M_AXI_ENGINE_awprot(m_axi_awprot),
    .M_AXI_ENGINE_awvalid(m_axi_awvalid), .M_AXI_ENGINE_awready(m_axi_awready),
    .M_AXI_ENGINE_wdata(m_axi_wdata), .M_AXI_ENGINE_wstrb(m_axi_wstrb),
    .M_AXI_ENGINE_wvalid(m_axi_wvalid), .M_AXI_ENGINE_wready(m_axi_wready),
    .M_AXI_ENGINE_bresp(m_axi_bresp), .M_AXI_ENGINE_bvalid(m_axi_bvalid),
    .M_AXI_ENGINE_bready(m_axi_bready), .M_AXI_ENGINE_araddr(m_axi_araddr),
    .M_AXI_ENGINE_arprot(m_axi_arprot), .M_AXI_ENGINE_arvalid(m_axi_arvalid),
    .M_AXI_ENGINE_arready(m_axi_arready), .M_AXI_ENGINE_rdata(m_axi_rdata),
    .M_AXI_ENGINE_rresp(m_axi_rresp), .M_AXI_ENGINE_rvalid(m_axi_rvalid),
    .M_AXI_ENGINE_rready(m_axi_rready)
  );

  axi_lite_eye_scan_v1_engine #(
    .ENABLE_TX_SESSION(ENABLE_TX_SESSION),
    .LOCALIZE_DESCRIPTOR_CONTROLS(ALL_DIRECT_V7 || ALL_LINKS_V1),
    .LANES(112), .HARDWARE_VERSION(HARDWARE_VERSION),
    .MANAGED_LANE_MASK(MANAGED_MASK),
    .ASYNC_SNAPSHOT_MASK(MANAGED_MASK)
  ) u_engine (
    .s_axi_aclk(clk_200), .s_axi_aresetn(resetn),
    .s_axi_awaddr(m_axi_awaddr[11:0]), .s_axi_awvalid(m_axi_awvalid),
    .s_axi_awready(m_axi_awready), .s_axi_wdata(m_axi_wdata),
    .s_axi_wstrb(m_axi_wstrb), .s_axi_wvalid(m_axi_wvalid),
    .s_axi_wready(m_axi_wready), .s_axi_bresp(m_axi_bresp),
    .s_axi_bvalid(m_axi_bvalid), .s_axi_bready(m_axi_bready),
    .s_axi_araddr(m_axi_araddr[11:0]), .s_axi_arvalid(m_axi_arvalid),
    .s_axi_arready(m_axi_arready), .s_axi_rdata(m_axi_rdata),
    .s_axi_rresp(m_axi_rresp), .s_axi_rvalid(m_axi_rvalid),
    .s_axi_rready(m_axi_rready), .interrupt(engine_interrupt),
    .status_firmware_alive(status_firmware_alive),
    .status_engine_busy(status_engine_busy), .status_fault(engine_status_fault),
    .platform_ready(quad_ready && test_controller_idle),
    .config_controllers_idle(config_controllers_idle),
    .eye_controls(eye_controls),.eye_fatal(eye_fatal),
    .eye_point_packet(eye_selected_packet),.eye_link_fatal(|eye_return_fatal),
    .eye_progress_record(),.eye_page_record(),
    .platform_fault(quad_fault),
    .platform_status({quad_diagnostic, quad_fault_reason,
                      quad_fault, quad_ready, 3'd0, quad_state}),
    .platform_diagnostics(platform_diagnostics),
    .recovery_diagnostics(recovery_diagnostics),
    .engine_protocol_debug(engine_protocol_debug),
    .diagnostic_selector(diagnostic_selector), .diagnostic_record(diagnostic_record),
    .diagnostic_bank(diagnostic_bank),
    .acquisition_ready(acquisition_ready),
    .result_capture_done(result_capture_done),
    .exact_error_counts(exact_error_counts),
    .exact_error_valid(exact_error_valid),
    .exact_error_saturated(exact_error_saturated),
    .mailbox_i2c_address(i2c_address),
    .mailbox_i2c_write(i2c_write_enable),
    .mailbox_i2c_write_data(i2c_write_data),
    .mailbox_i2c_read_data(mailbox_read_data),
    .mailbox_i2c_read_data_next(mailbox_read_data_next),
    .rx_clk(rx_clocks), .rx_reset(rx_resets),
    .rx_prbs_locked(rx_prbs_locked), .rx_cdr_locked(rx_cdr_locked),
    .rx_prbs_errors(rx_prbs_errors),
    .tx_prbs_select(tx_prbs_select), .rx_prbs_select(rx_prbs_select),
    .prbs_counter_reset(prbs_counter_reset), .lane_running(lane_running),
    .loopback_mode(loopback_mode),
    .measurement_enable(measurement_enable),
    .measurement_run_toggle(measurement_run_toggle),
    .controls_enable(controls_enable),
    .tx_session_active(tx_session_active), .session_tag(session_tag),
    .tx_session_ready(tx_session_ready_to_engine),
    .config_tx_mask(config_tx_mask), .config_rx_mask(config_rx_mask),
    .config_epoch(config_epoch), .config_tx_observed(config_tx_observed),
    .config_bank_epoch_ack(config_bank_epoch_ack),
    .acquisition_active(acquisition_active),
    .result_capture_request(result_capture_request),
    .accepted_lane_mask(accepted_lane_mask),
    .tx_error_inject_toggle(tx_error_inject_toggle)
  );

  for (genvar n = 0; n < 6; n++) begin : g_selected_refclk_monitor
    // ODIV2 clocks are promoted through BUFG_GT before entering the frequency
    // monitor.  Vector order below is the deployed MCU register ABI.
    BUFG_GT u_left_bufg_gt (
      .I(left_refclk_odiv2[n]), .O(left_refclk_mon[n]), .CE(1'b1),
      .CEMASK(1'b0), .CLR(1'b0), .CLRMASK(1'b0), .DIV(3'b000));
    BUFG_GT u_right_bufg_gt (
      .I(right_refclk_odiv2[n]), .O(right_refclk_mon[n]), .CE(1'b1),
      .CEMASK(1'b0), .CLR(1'b0), .CLRMASK(1'b0), .DIV(3'b000));
  end

  clock_input_buffers u_clock_inputs (
    .fabric_clk_p({p_lhc_clk, p_tcds40_clk, p_rt_x4_r0_clk,
                   p_rt_x12_r0_clk, p_lf_x4_r0_clk, p_lf_x12_r0_clk}),
    .fabric_clk_n({n_lhc_clk, n_tcds40_clk, n_rt_x4_r0_clk,
                   n_rt_x12_r0_clk, n_lf_x4_r0_clk, n_lf_x12_r0_clk}),
    .gty_refclk_p({p_rt_r1_i, p_rt_r1_g, p_rt_r1_e, p_rt_r1_b,
                   p_rt_r1_p, p_rt_r1_n, p_lf_r1_y, p_lf_r1_w,
                   p_lf_r1_u, p_lf_r1_r, p_lf_r1_af, p_lf_r1_ad,
                   p_rt_r1_l, p_rt_r0_l, p_lf_r1_ab, p_lf_r0_ab}),
    .gty_refclk_n({n_rt_r1_i, n_rt_r1_g, n_rt_r1_e, n_rt_r1_b,
                   n_rt_r1_p, n_rt_r1_n, n_lf_r1_y, n_lf_r1_w,
                   n_lf_r1_u, n_lf_r1_r, n_lf_r1_af, n_lf_r1_ad,
                   n_rt_r1_l, n_rt_r0_l, n_lf_r1_ab, n_lf_r0_ab}),
    .fabric_clk(fabric_clocks), .gty_refclk_odiv2(extra_gty_odiv2)
  );

  assign monitored_clocks[0] = clk_200;
  // r02-r38 (I2C 0x08-0x98) must remain in this exact documented order.  The
  // monitor reports direct kHz values; GT clocks are not multiplied by two.
  assign monitored_clocks[1] = fabric_clocks[5];
  assign monitored_clocks[2] = fabric_clocks[4];
  assign monitored_clocks[3] = fabric_clocks[3];
  assign monitored_clocks[4] = fabric_clocks[2];
  assign monitored_clocks[5] = fabric_clocks[1];
  assign monitored_clocks[6] = fabric_clocks[0];
  assign monitored_clocks[7] = clk_100;
  assign monitored_clocks[8] = clk_325;
  assign monitored_clocks[9] = right_refclk_mon[1];
  assign monitored_clocks[10] = right_refclk_mon[0];
  assign monitored_clocks[11] = extra_gty_odiv2[2];
  assign monitored_clocks[12] = right_refclk_mon[5];
  assign monitored_clocks[13] = right_refclk_mon[4];
  assign monitored_clocks[14] = right_refclk_mon[3];
  assign monitored_clocks[15] = right_refclk_mon[2];
  assign monitored_clocks[16] = left_refclk_mon[5];
  assign monitored_clocks[17] = left_refclk_mon[4];
  assign monitored_clocks[18] = left_refclk_mon[3];
  assign monitored_clocks[19] = left_refclk_mon[2];
  assign monitored_clocks[20] = left_refclk_mon[1];
  assign monitored_clocks[21] = left_refclk_mon[0];
  assign monitored_clocks[22] = extra_gty_odiv2[0];
  assign monitored_clocks[23] = extra_gty_odiv2[11];
  assign monitored_clocks[24] = extra_gty_odiv2[10];
  assign monitored_clocks[25] = extra_gty_odiv2[3];
  assign monitored_clocks[26] = extra_gty_odiv2[15];
  assign monitored_clocks[27] = extra_gty_odiv2[14];
  assign monitored_clocks[28] = extra_gty_odiv2[13];
  assign monitored_clocks[29] = extra_gty_odiv2[12];
  assign monitored_clocks[30] = extra_gty_odiv2[9];
  assign monitored_clocks[31] = extra_gty_odiv2[8];
  assign monitored_clocks[32] = extra_gty_odiv2[7];
  assign monitored_clocks[33] = extra_gty_odiv2[6];
  assign monitored_clocks[34] = extra_gty_odiv2[5];
  assign monitored_clocks[35] = extra_gty_odiv2[4];
  assign monitored_clocks[36] = extra_gty_odiv2[1];

  clock_frequency_monitor #(
    .N_CLOCKS(37), .REF_HZ(200_000_000), .SCALE_X2('0)
  ) u_clock_monitor (
    .ref_clk(clk_200), .monitored_clk(monitored_clocks),
    .frequency_khz(frequency_khz), .measurement_valid(frequencies_valid)
  );

  function automatic logic [7:0] monitor_register_read(input logic [7:0] address);
    // Generic I2C 0x00-0x9F is the legacy clock-monitor window.  Addresses
    // 0xA0-0xFF are delegated to the GT test mailbox without translation.
    int clock_index;
    logic [31:0] value;
    begin
      if (address < 8'h08)
        value = debug_register[address[2]];
      else if (address < 8'h9c) begin
        clock_index = (address - 8'h08) >> 2;
        value = frequency_khz[clock_index];
      end else if (address < 8'ha0)
        value = {16'h434d, frequencies_valid, 7'd37, 8'h01};
      else
        value = 0;
      monitor_register_read = value[8*address[1:0] +: 8];
    end
  endfunction

  always_comb begin
    i2c_read_data = (i2c_address < 8'ha0)
      ? monitor_register_read(i2c_address) : mailbox_read_data;
    i2c_read_data_next = (i2c_address + 1'b1 < 8'ha0)
      ? monitor_register_read(i2c_address + 1'b1) : mailbox_read_data_next;
  end
  always_ff @(posedge clk_200) begin
    if (i2c_write_enable && i2c_address < 8'h08)
      debug_register[i2c_address[2]][8*i2c_address[1:0] +: 8]
        <= i2c_write_data;
  end

  i2c_register_slave #(.I2C_ADDRESS(7'h2b)) u_generic_i2c (
    // Deployed generic register-slave address; the board MCU reaches this
    // device behind the external I2C mux and software semaphore.
    .clk(clk_200), .scl(i2c_scl_f_generic), .sda(i2c_sda_f_generic),
    .register_address(i2c_address), .read_data(i2c_read_data),
    .read_data_next(i2c_read_data_next), .write_enable(i2c_write_enable),
    .write_data(i2c_write_data)
  );

  sysmon_i2c_ssi #(
    // Preserve the four independently deployed SLR addresses visibly here.
    .SLR0_I2C_ADDR(7'h36), .SLR1_I2C_ADDR(7'h34),
    .SLR2_I2C_ADDR(7'h47), .SLR3_I2C_ADDR(7'h45)
  ) u_sysmon_i2c (
    .dclk(clk_200), .i2c_scl(i2c_scl_f_sysmon), .i2c_sda(i2c_sda_f_sysmon)
  );

  wire led_blue_status = status_engine_busy ||
                         // Before firmware writes its version, blue heartbeat
                         // distinguishes configured fabric from CPU proof-life.
                         (!status_firmware_alive && heartbeat_counter[26]);
  wire led_green_status = status_firmware_alive && quad_ready &&
                          !status_engine_busy && !engine_status_fault;
  wire led_red_status = !status_engine_busy &&
                        (engine_status_fault || quad_fault);
  assign led_f1_blue = led_blue_status;
  assign led_f1_green = led_green_status;
  assign led_f1_red = led_red_status;
  assign led_f2_blue = led_blue_status;
  assign led_f2_green = led_green_status;
  assign led_f2_red = led_red_status;

  wire unused_clock_mmcm_locked = clock_mmcm_locked;
  wire unused_lane_running = &lane_running;
  wire unused_awprot = &m_axi_awprot;
  wire unused_arprot = &m_axi_arprot;
endmodule
