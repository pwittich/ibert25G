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
  wire [5:0] left_refclk_odiv2, right_refclk_odiv2;
  wire [5:0] left_refclk_mon, right_refclk_mon;
  wire left_ibert_sysclk, right_ibert_sysclk;
  wire [5:0] fabric_clocks;
  wire [15:0] extra_gty_odiv2;
  wire [36:0] monitored_clocks;
  logic [31:0] frequency_khz [0:36];
  logic frequencies_valid;
  logic [31:0] debug_register = 0;
  logic [7:0] i2c_register_address, i2c_read_data, i2c_read_data_next;
  logic i2c_write_enable;
  logic [7:0] i2c_write_data;
  IBUFDS #(.DIFF_TERM("TRUE"), .IBUF_LOW_PWR("FALSE"))
    u_clk_200_ibuf (.I(p_clk_200), .IB(n_clk_200), .O(clk_200_raw));
  BUFG u_clk_200_bufg (.I(clk_200_raw), .O(clk_200));

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

  assign monitored_clocks[0] = clk_200;
  assign monitored_clocks[6:1] = fabric_clocks;
  assign monitored_clocks[10:7] = extra_gty_odiv2[3:0];
  assign monitored_clocks[16:11] = left_refclk_mon;
  assign monitored_clocks[22:17] = extra_gty_odiv2[9:4];
  assign monitored_clocks[28:23] = right_refclk_mon;
  assign monitored_clocks[34:29] = extra_gty_odiv2[15:10];
  assign monitored_clocks[35] = left_ibert_sysclk;
  assign monitored_clocks[36] = right_ibert_sysclk;

  clock_frequency_monitor #(
    .N_CLOCKS(37), .REF_HZ(200_000_000),
    .SCALE_X2({2'b00, 28'hfffffff, 7'b0000000})
  ) u_clock_monitor (
    .ref_clk(clk_200), .monitored_clk(monitored_clocks),
    .frequency_khz(frequency_khz), .measurement_valid(frequencies_valid)
  );

  function automatic logic [7:0] register_read(input logic [7:0] address);
    int clock_index;
    logic [31:0] value;
    begin
      if (address < 8'h04) value = debug_register;
      else if (address < 8'h08) value = {16'h434d, frequencies_valid, 7'd37, 8'h01};
      else begin
        clock_index = (address - 8'h08) >> 2;
        value = (clock_index < 37) ? frequency_khz[clock_index] : 32'h0;
      end
      register_read = value[8*(address[1:0]) +: 8];
    end
  endfunction
  always_comb begin
    i2c_read_data = register_read(i2c_register_address);
    i2c_read_data_next = register_read(i2c_register_address + 1'b1);
  end
  always_ff @(posedge clk_200) begin
    if (i2c_write_enable && i2c_register_address < 8'h04)
      debug_register[8*i2c_register_address[1:0] +: 8] <= i2c_write_data;
  end

  i2c_register_slave #(.I2C_ADDRESS(7'h42)) u_generic_i2c (
    .clk(clk_200), .scl(i2c_scl_f_generic), .sda(i2c_sda_f_generic),
    .register_address(i2c_register_address), .read_data(i2c_read_data),
    .read_data_next(i2c_read_data_next), .write_enable(i2c_write_enable),
    .write_data(i2c_write_data)
  );

  sysmon_i2c_ssi #(
    // Change the four 7-bit addresses here if the board convention changes.
    .SLR0_I2C_ADDR(7'h30),
    .SLR1_I2C_ADDR(7'h31), // Master SLR on VU13P
    .SLR2_I2C_ADDR(7'h32),
    .SLR3_I2C_ADDR(7'h33)
  ) u_sysmon_i2c (
    .dclk(clk_200),
    .i2c_scl(i2c_scl_f_sysmon),
    .i2c_sda(i2c_sda_f_sysmon)
  );
endmodule
