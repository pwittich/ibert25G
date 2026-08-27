`timescale 1ns/1ps

// Full managed-quad-124 integration target.  The golden src/top.sv remains
// unchanged.  Normal Milestone 3 combines 52 left-IBERT lanes, four managed
// quad-124 lanes, and 56 right-IBERT lanes.  ISOLATED_SMOKE removes both IBERT
// cores while retaining the board clock/I2C ABI for the Milestone 2.5 image.
module gt_test_milestone3_top #(
  parameter bit ISOLATED_SMOKE = 1'b0
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
  localparam logic [111:0] MANAGED_MASK =
    // Global lanes 12-15 are the only lanes that software may select.  Keeping
    // this mask at the top makes physical ownership and the register ABI agree.
    112'h000000000000000000000000f000;

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
  wire managed_refclk_odiv2;
  wire [5:0] fabric_clocks;
  wire [15:0] extra_gty_odiv2;
  wire [36:0] monitored_clocks;
  logic [31:0] frequency_khz [0:36];
  logic frequencies_valid;
  logic [31:0] debug_register [0:1] = '{default:32'h0};
  logic [26:0] heartbeat_counter = 0;

  wire engine_interrupt, status_firmware_alive, status_engine_busy;
  wire engine_status_fault;
  wire quad_ready, quad_fault, lane_rx_reset, managed_rx_clk;
  wire [7:0] quad_fault_reason;
  wire [15:0] quad_diagnostic;
  wire test_controller_idle, acquisition_ready, result_capture_done;
  wire [2:0] quad_state;
  wire [3:0] managed_prbs_locked, managed_prbs_error;
  wire [127:0] managed_exact_error_counts;
  wire [3:0] managed_exact_error_valid, managed_exact_error_saturated;

  wire [111:0] rx_clocks, rx_resets, rx_prbs_locked;
  wire [112*16-1:0] rx_prbs_errors;
  wire [112*3-1:0] tx_prbs_select, rx_prbs_select;
  wire [111:0] prbs_counter_reset, lane_running;
  wire measurement_enable, controls_enable, result_capture_request;
  wire [112*32-1:0] exact_error_counts;
  wire [111:0] exact_error_valid, exact_error_saturated;
  wire [2:0] loopback_mode;
  wire [111:0] tx_error_inject_toggle;

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

  generate
    if (ISOLATED_SMOKE) begin : g_isolated_smoke
      // Milestone 2.5 keeps only refclock buffers needed by the unchanged
      // 37-clock monitor map.  All non-managed transmit outputs are tied off.
      isolated_refclk_buffers u_refclk_buffers (
        .left_refclk_p({p_lf_r0_y, p_lf_r0_w, p_lf_r0_u, p_lf_r0_r,
                        1'b0, p_lf_r0_ad}),
        .left_refclk_n({n_lf_r0_y, n_lf_r0_w, n_lf_r0_u, n_lf_r0_r,
                        1'b0, n_lf_r0_ad}),
        .right_refclk_p({p_rt_r0_i, p_rt_r0_g, p_rt_r0_e, p_rt_r0_b,
                         p_rt_r0_p, p_rt_r0_n}),
        .right_refclk_n({n_rt_r0_i, n_rt_r0_g, n_rt_r0_e, n_rt_r0_b,
                         n_rt_r0_p, n_rt_r0_n}),
        .managed_refclk_odiv2(managed_refclk_odiv2),
        .left_refclk_odiv2(left_refclk_odiv2),
        .right_refclk_odiv2(right_refclk_odiv2)
      );
      assign left_ibert_sysclk = 1'b0;
      assign right_ibert_sysclk = 1'b0;
      assign {p_ff1_xmit, n_ff1_xmit, p_ff2_xmit, n_ff2_xmit,
              p_ff3_xmit, n_ff3_xmit, p_ff4_xmit, n_ff4_xmit,
              p_ff6_xmit, n_ff6_xmit} = '0;
      assign {p_a_xmit, n_a_xmit, p_b_xmit, n_b_xmit,
              p_c_xmit, n_c_xmit, p_d_xmit, n_d_xmit,
              p_e_xmit, n_e_xmit, p_f_xmit, n_f_xmit,
              p_g_xmit, n_g_xmit, p_h_xmit, n_h_xmit,
              p_i_xmit, n_i_xmit, p_j_xmit, n_j_xmit,
              p_m_xmit, n_m_xmit, p_n_xmit, n_n_xmit,
              p_o_xmit, n_o_xmit, p_p_xmit, n_p_xmit} = '0;
    end else begin : g_full_ibert
      // Milestone 3 restores IBERT visibility for every non-managed channel.
      ibert_milestone3_top u_ibert (.*);
    end
  endgenerate

  managed_quad124_wrapper u_managed_quad124 (
    // Physical lane order is global 12,13,14,15 == GTYE4_CHANNEL_X0Y16-19.
    .mgmt_clk(clk_200), .resetn(resetn),
    .refclk_p(p_lf_r0_af), .refclk_n(n_lf_r0_af),
    .rx_p(p_ff5_recv), .rx_n(n_ff5_recv),
    .tx_p(p_ff5_xmit), .tx_n(n_ff5_xmit),
    .tx_prbs_select(tx_prbs_select[12*3 +: 12]),
    .rx_prbs_select(rx_prbs_select[12*3 +: 12]),
    .prbs_counter_reset(prbs_counter_reset[12 +: 4]),
    .lane_running(lane_running[12 +: 4]),
    .loopback_mode(loopback_mode),
    .result_capture_request(result_capture_request),
    .tx_error_inject_toggle(tx_error_inject_toggle[12 +: 4]),
    .rx_usrclk2(managed_rx_clk), .rx_prbs_locked(managed_prbs_locked),
    .rx_prbs_error(managed_prbs_error), .lane_rx_reset(lane_rx_reset),
    .refclk_odiv2(managed_refclk_odiv2), .quad_ready(quad_ready),
    .quad_fault(quad_fault), .quad_fault_reason(quad_fault_reason),
    .quad_diagnostic(quad_diagnostic),
    .quad_state(quad_state),
    .test_controller_idle(test_controller_idle),
    .acquisition_ready(acquisition_ready),
    .result_capture_done(result_capture_done),
    .exact_error_counts(managed_exact_error_counts),
    .exact_error_valid(managed_exact_error_valid),
    .exact_error_saturated(managed_exact_error_saturated)
  );

  for (genvar lane = 0; lane < 112; lane++) begin : g_lane_inputs
    if (lane >= 12 && lane < 16) begin
      // Only managed lanes use asynchronous RXUSRCLK2 snapshots and native
      // DRP error counts.  The other lane engines exist for ABI width but are
      // unselectable and cannot drive the IBERT-owned GTs.
      assign rx_clocks[lane] = managed_rx_clk;
      assign rx_resets[lane] = lane_rx_reset;
      assign rx_prbs_locked[lane] = managed_prbs_locked[lane-12];
      assign rx_prbs_errors[lane*16 +: 16] =
        {15'd0, managed_prbs_error[lane-12]};
      assign exact_error_counts[lane*32 +: 32] =
        managed_exact_error_counts[(lane-12)*32 +: 32];
      assign exact_error_valid[lane] = managed_exact_error_valid[lane-12];
      assign exact_error_saturated[lane] =
        managed_exact_error_saturated[lane-12];
    end else begin
      assign rx_clocks[lane] = clk_200;
      assign rx_resets[lane] = !resetn;
      assign rx_prbs_locked[lane] = 1'b0;
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

  axi_lite_gt_test_engine #(
    .LANES(112), .HARDWARE_VERSION(32'h0002_0004),
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
    .platform_fault(quad_fault),
    .platform_status({quad_diagnostic, quad_fault_reason,
                      quad_fault, quad_ready, 3'd0, quad_state}),
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
    .rx_prbs_locked(rx_prbs_locked), .rx_prbs_errors(rx_prbs_errors),
    .tx_prbs_select(tx_prbs_select), .rx_prbs_select(rx_prbs_select),
    .prbs_counter_reset(prbs_counter_reset), .lane_running(lane_running),
    .loopback_mode(loopback_mode),
    .measurement_enable(measurement_enable),
    .controls_enable(controls_enable),
    .result_capture_request(result_capture_request),
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
