`timescale 1ns/1ps

// Synthetic milestone-2 hardware target.  This top is deliberately separate
// from src/top.sv, which remains the golden standalone-IBERT target.
module gt_test_milestone2_top (
  input  wire p_clk_200,
  input  wire n_clk_200,
  inout  wire i2c_scl_f_generic,
  inout  wire i2c_sda_f_generic,
  output wire led_f1_blue,
  output wire led_f1_green,
  output wire led_f1_red,
  output wire led_f2_blue,
  output wire led_f2_green,
  output wire led_f2_red
);
  wire clk_200_raw, clk_200;
  wire i2c_scl_internal;
  logic [7:0] power_on_reset = 8'hff;
  wire reset = |power_on_reset;
  wire resetn = !reset;
  wire engine_interrupt;
  wire status_firmware_alive;
  wire status_engine_busy;
  wire status_fault;
  logic [26:0] heartbeat_counter = 0;

  wire [31:0] m_axi_awaddr;
  wire [2:0]  m_axi_awprot;
  wire        m_axi_awvalid, m_axi_awready;
  wire [31:0] m_axi_wdata;
  wire [3:0]  m_axi_wstrb;
  wire        m_axi_wvalid, m_axi_wready;
  wire [1:0]  m_axi_bresp;
  wire        m_axi_bvalid, m_axi_bready;
  wire [31:0] m_axi_araddr;
  wire [2:0]  m_axi_arprot;
  wire        m_axi_arvalid, m_axi_arready;
  wire [31:0] m_axi_rdata;
  wire [1:0]  m_axi_rresp;
  wire        m_axi_rvalid, m_axi_rready;

  IBUFDS #(.DIFF_TERM("TRUE"), .IBUF_LOW_PWR("FALSE"))
    u_clk_200_ibuf (.I(p_clk_200), .IB(n_clk_200), .O(clk_200_raw));
  BUFG u_clk_200_bufg (.I(clk_200_raw), .O(clk_200));

  // The slave does not clock-stretch.  Keep the bidirectional board pin for
  // ABI/pinout consistency, but make the permanently released output path
  // explicit so implementation sees a complete pad buffer.
  IOBUF u_i2c_scl_iobuf (
    .I(1'b0), .T(1'b1), .O(i2c_scl_internal),
    .IO(i2c_scl_f_generic)
  );

  always_ff @(posedge clk_200) begin
    power_on_reset <= {power_on_reset[6:0], 1'b0};
    if (reset)
      heartbeat_counter <= 0;
    else
      heartbeat_counter <= heartbeat_counter + 1'b1;
  end

  // Both board sites use active-high RGB LEDs on different pins.  Green is a
  // deliberate CPU proof-of-life: it cannot light until firmware writes its
  // version through AXI.  A previous fault is suppressed while a retry runs.
  wire led_blue_status = status_engine_busy ||
                         (!status_firmware_alive && heartbeat_counter[26]);
  wire led_green_status = status_firmware_alive &&
                          !status_engine_busy && !status_fault;
  wire led_red_status = !status_engine_busy && status_fault;
  assign led_f1_blue = led_blue_status;
  assign led_f1_green = led_green_status;
  assign led_f1_red = led_red_status;
  assign led_f2_blue = led_blue_status;
  assign led_f2_green = led_green_status;
  assign led_f2_red = led_red_status;

  gt_test_milestone2_bd_wrapper u_subsystem (
    .clk_200(clk_200),
    .reset(reset),
    .engine_interrupt(engine_interrupt),
    .M_AXI_ENGINE_awaddr(m_axi_awaddr),
    .M_AXI_ENGINE_awprot(m_axi_awprot),
    .M_AXI_ENGINE_awvalid(m_axi_awvalid),
    .M_AXI_ENGINE_awready(m_axi_awready),
    .M_AXI_ENGINE_wdata(m_axi_wdata),
    .M_AXI_ENGINE_wstrb(m_axi_wstrb),
    .M_AXI_ENGINE_wvalid(m_axi_wvalid),
    .M_AXI_ENGINE_wready(m_axi_wready),
    .M_AXI_ENGINE_bresp(m_axi_bresp),
    .M_AXI_ENGINE_bvalid(m_axi_bvalid),
    .M_AXI_ENGINE_bready(m_axi_bready),
    .M_AXI_ENGINE_araddr(m_axi_araddr),
    .M_AXI_ENGINE_arprot(m_axi_arprot),
    .M_AXI_ENGINE_arvalid(m_axi_arvalid),
    .M_AXI_ENGINE_arready(m_axi_arready),
    .M_AXI_ENGINE_rdata(m_axi_rdata),
    .M_AXI_ENGINE_rresp(m_axi_rresp),
    .M_AXI_ENGINE_rvalid(m_axi_rvalid),
    .M_AXI_ENGINE_rready(m_axi_rready)
  );

  gt_test_hardware_shell u_engine (
    .clk_200(clk_200),
    .resetn(resetn),
    .s_axi_awaddr(m_axi_awaddr[11:0]),
    .s_axi_awvalid(m_axi_awvalid),
    .s_axi_awready(m_axi_awready),
    .s_axi_wdata(m_axi_wdata),
    .s_axi_wstrb(m_axi_wstrb),
    .s_axi_wvalid(m_axi_wvalid),
    .s_axi_wready(m_axi_wready),
    .s_axi_bresp(m_axi_bresp),
    .s_axi_bvalid(m_axi_bvalid),
    .s_axi_bready(m_axi_bready),
    .s_axi_araddr(m_axi_araddr[11:0]),
    .s_axi_arvalid(m_axi_arvalid),
    .s_axi_arready(m_axi_arready),
    .s_axi_rdata(m_axi_rdata),
    .s_axi_rresp(m_axi_rresp),
    .s_axi_rvalid(m_axi_rvalid),
    .s_axi_rready(m_axi_rready),
    .interrupt(engine_interrupt),
    .status_firmware_alive(status_firmware_alive),
    .status_engine_busy(status_engine_busy),
    .status_fault(status_fault),
    .platform_ready(1'b1), .platform_fault(1'b0),
    .platform_status(32'd0),
    .platform_diagnostics(224'd0),
    .i2c_scl(i2c_scl_internal),
    .i2c_sda(i2c_sda_f_generic),
    .synthetic_lock({112{1'b1}}),
    .synthetic_cdr_lock({112{1'b1}}),
    .synthetic_errors({112*16{1'b0}})
  );

  wire unused_awprot = &m_axi_awprot;
  wire unused_arprot = &m_axi_arprot;
endmodule
