`timescale 1ns/1ps

// Synthetic physical shell used to validate the HDL/MicroBlaze protocol before
// migrating any GTY channel out of IBERT.  All lanes share clk_200, report the
// supplied synthetic lock/error vectors, and intentionally drive no GT pins.
module gt_test_hardware_shell #(
  parameter int unsigned LANES = 112,
  parameter bit LOCALIZE_DESCRIPTOR_CONTROLS = 1'b0,
  parameter logic [LANES-1:0] MANAGED_LANE_MASK = {LANES{1'b1}},
  parameter logic [LANES-1:0] ASYNC_SNAPSHOT_MASK = {LANES{1'b0}}
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
  input  wire [223:0]          platform_diagnostics,
  inout  wire                  i2c_scl,
  inout  wire                  i2c_sda,

  // Synthetic lane stimuli are present only in this migration shell.  A
  // managed-GT target replaces them with native GT status/error signals.
  input  wire [LANES-1:0]      synthetic_lock,
  input  wire [LANES-1:0]      synthetic_cdr_lock,
  input  wire [LANES*16-1:0]   synthetic_errors
);
  wire [LANES-1:0] rx_clocks = {LANES{clk_200}};
  // ASYNC_SNAPSHOT_MASK is normally zero here because the synthetic lane and
  // management domains are identical.  Native-GT targets override the mask
  // for only the lanes whose RXUSRCLK2 is asynchronous.
  wire [LANES-1:0] rx_resets = {LANES{!resetn}};
  wire [LANES*3-1:0] unused_tx_prbs_select;
  wire [LANES*3-1:0] unused_rx_prbs_select;
  wire [LANES-1:0] unused_prbs_counter_reset;
  wire [LANES-1:0] unused_lane_running;
  wire [2:0] unused_loopback_mode;
  wire [LANES-1:0] unused_tx_error_inject_toggle;
  gt_test_engine_shell #(
    .LANES(LANES), .LOCALIZE_DESCRIPTOR_CONTROLS(LOCALIZE_DESCRIPTOR_CONTROLS),
    .MANAGED_LANE_MASK(MANAGED_LANE_MASK),
    .ASYNC_SNAPSHOT_MASK(ASYNC_SNAPSHOT_MASK)
  ) u_engine_shell (
    .clk_200(clk_200),
    .resetn(resetn),
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
    .platform_diagnostics(platform_diagnostics),
    .i2c_scl(i2c_scl),
    .i2c_sda(i2c_sda),
    .rx_clk(rx_clocks),
    .rx_reset(rx_resets),
    .rx_prbs_locked(synthetic_lock),
    .rx_cdr_locked(synthetic_cdr_lock),
    .rx_prbs_errors(synthetic_errors),
    .tx_prbs_select(unused_tx_prbs_select),
    .rx_prbs_select(unused_rx_prbs_select),
    .prbs_counter_reset(unused_prbs_counter_reset),
    .lane_running(unused_lane_running),
    .loopback_mode(unused_loopback_mode),
    .tx_error_inject_toggle(unused_tx_error_inject_toggle)
  );
endmodule
