module top (
  input wire p_clk_200, n_clk_200,
  inout wire i2c_scl_f_sysmon, i2c_sda_f_sysmon,
  inout wire i2c_scl_f_generic, i2c_sda_f_generic,
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
  wire clk_200_raw, clk_200;
  wire clk_100_raw, clk_100, clk_325_raw, clk_325;
  wire clock_mmcm_feedback_raw, clock_mmcm_feedback, clock_mmcm_locked;
  (* KEEP = "TRUE" *) wire ibert_debug_clk_50;
  wire [5:0] left_refclk_odiv2, right_refclk_odiv2;
  wire [5:0] left_refclk_mon, right_refclk_mon;
  wire left_ibert_sysclk, right_ibert_sysclk;
  wire [5:0] fabric_clocks;
  wire [15:0] extra_gty_odiv2;
  wire [36:0] monitored_clocks;
  logic [31:0] frequency_khz [0:36];
  logic frequencies_valid;
  logic [31:0] debug_register [0:1] = '{default:32'h0};
  logic [7:0] i2c_register_address, i2c_read_data, i2c_read_data_next;
  logic i2c_write_enable;
  logic [7:0] i2c_write_data;
  IBUFDS #(.DIFF_TERM("TRUE"), .IBUF_LOW_PWR("FALSE"))
    u_clk_200_ibuf (.I(p_clk_200), .IB(n_clk_200), .O(clk_200_raw));
  BUFG u_clk_200_bufg (.I(clk_200_raw), .O(clk_200));
  // Equivalent to a Clocking Wizard configured for 200 MHz in and
  // 100/325 MHz out: VCO = 200 * 6.5 = 1300 MHz.
  MMCME4_BASE #(
    .BANDWIDTH("OPTIMIZED"),
    .CLKFBOUT_MULT_F(6.500),
    .CLKIN1_PERIOD(5.000),
    .CLKOUT0_DIVIDE_F(13.000),
    .CLKOUT1_DIVIDE(4),
    .DIVCLK_DIVIDE(1),
    .STARTUP_WAIT("FALSE")
  ) u_clock_mmcm (
    .CLKIN1(clk_200),
    .CLKFBIN(clock_mmcm_feedback),
    .RST(1'b0),
    .PWRDWN(1'b0),
    .CLKFBOUT(clock_mmcm_feedback_raw),
    .CLKFBOUTB(),
    .CLKOUT0(clk_100_raw),
    .CLKOUT0B(),
    .CLKOUT1(clk_325_raw),
    .CLKOUT1B(),
    .CLKOUT2(),
    .CLKOUT2B(),
    .CLKOUT3(),
    .CLKOUT3B(),
    .CLKOUT4(),
    .CLKOUT5(),
    .CLKOUT6(),
    .LOCKED(clock_mmcm_locked)
  );
  BUFG u_clock_mmcm_feedback_bufg
    (.I(clock_mmcm_feedback_raw), .O(clock_mmcm_feedback));
  BUFG u_clk_100_bufg (.I(clk_100_raw), .O(clk_100));
  BUFG u_clk_325_bufg (.I(clk_325_raw), .O(clk_325));
  BUFGCE_DIV #(.BUFGCE_DIVIDE(4)) u_ibert_debug_clk_bufg (
    .I(clk_200_raw), .CE(1'b1), .CLR(1'b0), .O(ibert_debug_clk_50)
  );

  ibert_top u_ibert (.*);

  for (genvar n = 0; n < 6; n++) begin : g_selected_refclk_monitor
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

  // Keep this order aligned with the MCU's r02-r38 clock table.
  assign monitored_clocks[0]  = clk_200;
  assign monitored_clocks[1]  = fabric_clocks[5];  // lhc_clk
  assign monitored_clocks[2]  = fabric_clocks[4];  // tcds40_clk
  assign monitored_clocks[3]  = fabric_clocks[3];  // rt_x4_r0_clk
  assign monitored_clocks[4]  = fabric_clocks[2];  // rt_x12_r0_clk
  assign monitored_clocks[5]  = fabric_clocks[1];  // lf_x4_r0_clk
  assign monitored_clocks[6]  = fabric_clocks[0];  // lf_x12_r0_clk
  assign monitored_clocks[7]  = clk_100;
  assign monitored_clocks[8]  = clk_325;
  assign monitored_clocks[9]  = right_refclk_mon[1]; // rt_r0_p
  assign monitored_clocks[10] = right_refclk_mon[0]; // rt_r0_n
  assign monitored_clocks[11] = extra_gty_odiv2[2];  // rt_r0_l
  assign monitored_clocks[12] = right_refclk_mon[5]; // rt_r0_i
  assign monitored_clocks[13] = right_refclk_mon[4]; // rt_r0_g
  assign monitored_clocks[14] = right_refclk_mon[3]; // rt_r0_e
  assign monitored_clocks[15] = right_refclk_mon[2]; // rt_r0_b
  assign monitored_clocks[16] = left_refclk_mon[5];  // lf_r0_y
  assign monitored_clocks[17] = left_refclk_mon[4];  // lf_r0_w
  assign monitored_clocks[18] = left_refclk_mon[3];  // lf_r0_u
  assign monitored_clocks[19] = left_refclk_mon[2];  // lf_r0_r
  assign monitored_clocks[20] = left_refclk_mon[1];  // lf_r0_af
  assign monitored_clocks[21] = left_refclk_mon[0];  // lf_r0_ad
  assign monitored_clocks[22] = extra_gty_odiv2[0];  // lf_r0_ab
  assign monitored_clocks[23] = extra_gty_odiv2[11]; // rt_r1_p
  assign monitored_clocks[24] = extra_gty_odiv2[10]; // rt_r1_n
  assign monitored_clocks[25] = extra_gty_odiv2[3];  // rt_r1_l
  assign monitored_clocks[26] = extra_gty_odiv2[15]; // rt_r1_i
  assign monitored_clocks[27] = extra_gty_odiv2[14]; // rt_r1_g
  assign monitored_clocks[28] = extra_gty_odiv2[13]; // rt_r1_e
  assign monitored_clocks[29] = extra_gty_odiv2[12]; // rt_r1_b
  assign monitored_clocks[30] = extra_gty_odiv2[9];  // lf_r1_y
  assign monitored_clocks[31] = extra_gty_odiv2[8];  // lf_r1_w
  assign monitored_clocks[32] = extra_gty_odiv2[7];  // lf_r1_u
  assign monitored_clocks[33] = extra_gty_odiv2[6];  // lf_r1_r
  assign monitored_clocks[34] = extra_gty_odiv2[5];  // lf_r1_af
  assign monitored_clocks[35] = extra_gty_odiv2[4];  // lf_r1_ad
  assign monitored_clocks[36] = extra_gty_odiv2[1];  // lf_r1_ab

  clock_frequency_monitor #(
    .N_CLOCKS(37), .REF_HZ(200_000_000), .SCALE_X2('0)
  ) u_clock_monitor (
    .ref_clk(clk_200), .monitored_clk(monitored_clocks),
    .frequency_khz(frequency_khz), .measurement_valid(frequencies_valid)
  );

  function automatic logic [7:0] register_read(input logic [7:0] address);
    int clock_index;
    logic [31:0] value;
    begin
      if (address < 8'h08) value = debug_register[address[2]];
      else if (address < 8'h9c) begin
        clock_index = (address - 8'h08) >> 2;
        value = frequency_khz[clock_index];
      end else if (address < 8'ha0)
        value = {16'h434d, frequencies_valid, 7'd37, 8'h01};
      else value = 32'h0;
      register_read = value[8*(address[1:0]) +: 8];
    end
  endfunction
  always_comb begin
    i2c_read_data = register_read(i2c_register_address);
    i2c_read_data_next = register_read(i2c_register_address + 1'b1);
  end
  always_ff @(posedge clk_200) begin
    if (i2c_write_enable && i2c_register_address < 8'h08)
      debug_register[i2c_register_address[2]]
                    [8*i2c_register_address[1:0] +: 8] <= i2c_write_data;
  end

  i2c_register_slave #(.I2C_ADDRESS(7'h2b)) u_generic_i2c (
    .clk(clk_200), .scl(i2c_scl_f_generic), .sda(i2c_sda_f_generic),
    .register_address(i2c_register_address), .read_data(i2c_read_data),
    .read_data_next(i2c_read_data_next), .write_enable(i2c_write_enable),
    .write_data(i2c_write_data)
  );

  sysmon_i2c_ssi #(
    // PMBus addresses expected by the board-management software.
    .SLR0_I2C_ADDR(7'h36),
    .SLR1_I2C_ADDR(7'h34), // Master SLR on VU13P
    .SLR2_I2C_ADDR(7'h47),
    .SLR3_I2C_ADDR(7'h45)
  ) u_sysmon_i2c (
    .dclk(clk_200),
    .i2c_scl(i2c_scl_f_sysmon),
    .i2c_sda(i2c_sda_f_sysmon)
  );
endmodule
