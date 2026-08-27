`timescale 1ns/1ps

// Reusable processor/mailbox shell.  Lane clocks and status are explicit so
// synthetic and native-GT targets share the same AXI/I2C control plane.
module gt_test_engine_shell #(
  parameter int unsigned LANES = 112,
  parameter logic [31:0] HARDWARE_VERSION = 32'h0001_0002,
  parameter logic [LANES-1:0] MANAGED_LANE_MASK = {LANES{1'b1}},
  parameter logic [LANES-1:0] ASYNC_SNAPSHOT_MASK = MANAGED_LANE_MASK
) (
  input  wire                  clk_200,
  input  wire                  resetn,
  input  wire [11:0]           s_axi_awaddr,
  input  wire                  s_axi_awvalid,
  output wire                  s_axi_awready,
  input  wire [31:0]           s_axi_wdata,
  input  wire [3:0]            s_axi_wstrb,
  input  wire                  s_axi_wvalid,
  output wire                  s_axi_wready,
  output wire [1:0]            s_axi_bresp,
  output wire                  s_axi_bvalid,
  input  wire                  s_axi_bready,
  input  wire [11:0]           s_axi_araddr,
  input  wire                  s_axi_arvalid,
  output wire                  s_axi_arready,
  output wire [31:0]           s_axi_rdata,
  output wire [1:0]            s_axi_rresp,
  output wire                  s_axi_rvalid,
  input  wire                  s_axi_rready,
  output wire                  interrupt,
  output wire                  status_firmware_alive,
  output wire                  status_engine_busy,
  output wire                  status_fault,
  input  wire                  platform_ready,
  input  wire                  platform_fault,
  input  wire [31:0]           platform_status,
  inout  wire                  i2c_scl,
  inout  wire                  i2c_sda,

  input  wire [LANES-1:0]      rx_clk,
  input  wire [LANES-1:0]      rx_reset,
  input  wire [LANES-1:0]      rx_prbs_locked,
  input  wire [LANES*16-1:0]   rx_prbs_errors,
  output wire [LANES*3-1:0]    tx_prbs_select,
  output wire [LANES*3-1:0]    rx_prbs_select,
  output wire [LANES-1:0]      prbs_counter_reset,
  output wire [LANES-1:0]      lane_running,
  output wire [2:0]            loopback_mode,
  output wire [LANES-1:0]      tx_error_inject_toggle
);
  wire [7:0] mailbox_address, mailbox_write_data;
  wire [7:0] mailbox_read_data, mailbox_read_data_next;
  wire mailbox_write;
  wire unused_measurement_enable, unused_controls_enable;
  wire unused_result_capture_request;

  // This reusable shell is the synthetic/Milestone-2 binding.  It has no
  // quad-local DRP capture stage, so acquisition/capture handshakes are tied
  // ready and the generic lane snapshots provide the result counts.
  axi_lite_gt_test_engine #(
    .LANES(LANES),
    .HARDWARE_VERSION(HARDWARE_VERSION),
    .MANAGED_LANE_MASK(MANAGED_LANE_MASK),
    .ASYNC_SNAPSHOT_MASK(ASYNC_SNAPSHOT_MASK)
  ) u_engine (
    .s_axi_aclk(clk_200),
    .s_axi_aresetn(resetn),
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bready(s_axi_bready),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready),
    .interrupt(interrupt),
    .status_firmware_alive(status_firmware_alive),
    .status_engine_busy(status_engine_busy),
    .status_fault(status_fault),
    .platform_ready(platform_ready),
    .platform_fault(platform_fault),
    .platform_status(platform_status),
    .acquisition_ready(1'b1),
    .result_capture_done(1'b1),
    .exact_error_counts({LANES*32{1'b0}}),
    .exact_error_valid({LANES{1'b0}}),
    .exact_error_saturated({LANES{1'b0}}),
    .mailbox_i2c_address(mailbox_address),
    .mailbox_i2c_write(mailbox_write),
    .mailbox_i2c_write_data(mailbox_write_data),
    .mailbox_i2c_read_data(mailbox_read_data),
    .mailbox_i2c_read_data_next(mailbox_read_data_next),
    .rx_clk(rx_clk),
    .rx_reset(rx_reset),
    .rx_prbs_locked(rx_prbs_locked),
    .rx_prbs_errors(rx_prbs_errors),
    .tx_prbs_select(tx_prbs_select),
    .rx_prbs_select(rx_prbs_select),
    .prbs_counter_reset(prbs_counter_reset),
    .lane_running(lane_running),
    .loopback_mode(loopback_mode),
    .measurement_enable(unused_measurement_enable),
    .controls_enable(unused_controls_enable),
    .result_capture_request(unused_result_capture_request),
    .tx_error_inject_toggle(tx_error_inject_toggle)
  );

  i2c_register_slave #(.I2C_ADDRESS(7'h2b)) u_mailbox_i2c (
    // Keep the deployed generic-register slave address visible here.  Board
    // firmware reaches it only after taking I2C5 and selecting the FPGA mux.
    .clk(clk_200),
    .scl(i2c_scl),
    .sda(i2c_sda),
    .register_address(mailbox_address),
    .read_data(mailbox_read_data),
    .read_data_next(mailbox_read_data_next),
    .write_enable(mailbox_write),
    .write_data(mailbox_write_data)
  );
endmodule
