`timescale 1ns/1ps

// V3-specific implementation; historical modules remain unchanged at 34c73bb.

// Minimal AXI4-Lite transport adapter around gt_test_engine_core.  AXI write
// address and data channels are independent, so each is captured until both
// halves of one transaction are present.  The core therefore sees exactly one
// reg_write pulse regardless of which AXI channel arrives first.
//
// This block deliberately returns OKAY for every completed bus transaction.
// Command validity is part of the engine ABI: invalid descriptors set the
// engine's bad-command/interrupt status instead of generating an AXI error.
module axi_lite_all_links_v3_engine #(
  parameter bit ENABLE_TX_SESSION = 1'b0,
  parameter int unsigned LANES = 112,
  parameter int unsigned AXI_ADDRESS_WIDTH = 12,
  parameter int unsigned USER_BITS_PER_CYCLE = 80,
  parameter bit LOCALIZE_DESCRIPTOR_CONTROLS = 1'b0,
  parameter logic [31:0] HARDWARE_VERSION = 32'h0001_0002,
  parameter bit ALL_LINKS_V2_TIMING_HARDENING =
    1'b1,
  parameter logic [LANES-1:0] MANAGED_LANE_MASK = {LANES{1'b1}},
  parameter logic [LANES-1:0] ASYNC_SNAPSHOT_MASK = MANAGED_LANE_MASK
) (
  input  wire                         s_axi_aclk,
  input  wire                         s_axi_aresetn,
  input  wire [AXI_ADDRESS_WIDTH-1:0] s_axi_awaddr,
  input  wire                         s_axi_awvalid,
  output wire                         s_axi_awready,
  input  wire [31:0]                  s_axi_wdata,
  input  wire [3:0]                   s_axi_wstrb,
  input  wire                         s_axi_wvalid,
  output wire                         s_axi_wready,
  output logic [1:0]                  s_axi_bresp,
  output logic                        s_axi_bvalid,
  input  wire                         s_axi_bready,
  input  wire [AXI_ADDRESS_WIDTH-1:0] s_axi_araddr,
  input  wire                         s_axi_arvalid,
  output wire                         s_axi_arready,
  output logic [31:0]                 s_axi_rdata,
  output logic [1:0]                  s_axi_rresp,
  output logic                        s_axi_rvalid,
  input  wire                         s_axi_rready,
  output wire                         interrupt,
  output wire                         status_firmware_alive,
  output wire                         status_engine_busy,
  output wire                         status_fault,
  input  wire                         platform_ready,
  input wire config_controllers_idle,
  input  wire                         platform_fault,
  input  wire [31:0]                  platform_status,
  input  wire [223:0]                 platform_diagnostics,
  input  wire [255:0]                 recovery_diagnostics,
  input  wire [255:0]                 diagnostic_record,
  output wire [7:0]                   diagnostic_selector,
  output wire [1:0]                   diagnostic_bank,
  output wire [31:0]                  engine_protocol_debug,
  input  wire                         acquisition_ready,
  input  wire                         result_capture_done,
  input  wire [LANES*32-1:0]          exact_error_counts,
  input  wire [LANES-1:0]             exact_error_valid,
  input  wire [LANES-1:0]             exact_error_saturated,

  input  wire [7:0]                   mailbox_i2c_address,
  input  wire                         mailbox_i2c_write,
  input  wire [7:0]                   mailbox_i2c_write_data,
  output wire [7:0]                   mailbox_i2c_read_data,
  output wire [7:0]                   mailbox_i2c_read_data_next,

  input  wire [LANES-1:0]             rx_clk,
  input  wire [LANES-1:0]             rx_reset,
  input  wire [LANES-1:0]             rx_prbs_locked,
  input  wire [LANES-1:0]             rx_cdr_locked,
  input  wire [LANES*16-1:0]          rx_prbs_errors,
  output wire [LANES*3-1:0]           tx_prbs_select,
  output wire [LANES*3-1:0]           rx_prbs_select,
  output wire [LANES-1:0]             prbs_counter_reset,
  output wire [LANES-1:0]             lane_running,
  output wire [2:0]                   loopback_mode,
  output wire                         measurement_enable,
  output wire                         measurement_run_toggle,
  output wire                         controls_enable,
  output wire                         tx_session_active,
  output wire [1:0] session_tag,
  input  wire                         tx_session_ready,
  output wire [27:0] config_tx_mask, config_rx_mask,
  output wire config_epoch,
  input wire [27:0] config_tx_observed, config_bank_epoch_ack,
  output wire                         acquisition_active,
  output wire                         result_capture_request,
  output wire [LANES-1:0]             accepted_lane_mask,
  output wire [LANES-1:0]             tx_error_inject_toggle
);
  logic aw_pending = 0, w_pending = 0;
  logic [AXI_ADDRESS_WIDTH-1:0] awaddr_hold = 0;
  logic [31:0] wdata_hold = 0;
  logic [3:0] wstrb_hold = 0;
  // A response remains outstanding until BREADY/RREADY.  Blocking acceptance
  // of a second request during that interval keeps this adapter single-entry
  // and avoids needing transaction IDs or response queues.
  wire core_write = aw_pending && w_pending && !s_axi_bvalid;
  wire [31:0] core_read_data;

  assign s_axi_awready = !aw_pending && !s_axi_bvalid;
  assign s_axi_wready = !w_pending && !s_axi_bvalid;
  assign s_axi_arready = !s_axi_rvalid;

  all_links_v3_engine_core #(
    .ENABLE_TX_SESSION(ENABLE_TX_SESSION),
    .LANES(LANES),
    .USER_BITS_PER_CYCLE(USER_BITS_PER_CYCLE),
    .LOCALIZE_DESCRIPTOR_CONTROLS(LOCALIZE_DESCRIPTOR_CONTROLS),
    .HARDWARE_VERSION(HARDWARE_VERSION),
    .ALL_LINKS_V2_TIMING_HARDENING(ALL_LINKS_V2_TIMING_HARDENING),
    .MANAGED_LANE_MASK(MANAGED_LANE_MASK),
    .ASYNC_SNAPSHOT_MASK(ASYNC_SNAPSHOT_MASK)
  ) u_core (
    .mgmt_clk(s_axi_aclk),
    .mgmt_resetn(s_axi_aresetn),
    .reg_write(core_write),
    .reg_write_address(awaddr_hold[11:0]),
    .reg_write_data(wdata_hold),
    .reg_write_strobe(wstrb_hold),
    .reg_read_address(s_axi_araddr[11:0]),
    .reg_read_data(core_read_data),
    .interrupt(interrupt),
    .status_firmware_alive(status_firmware_alive),
    .status_engine_busy(status_engine_busy),
    .status_fault(status_fault),
    .platform_ready(platform_ready), .config_controllers_idle(config_controllers_idle),
    .platform_fault(platform_fault),
    .platform_status(platform_status),
    .platform_diagnostics(platform_diagnostics),
    .recovery_diagnostics(recovery_diagnostics),
    .diagnostic_record(diagnostic_record), .diagnostic_selector(diagnostic_selector),
    .diagnostic_bank(diagnostic_bank),
    .engine_protocol_debug(engine_protocol_debug),
    .acquisition_ready(acquisition_ready),
    .result_capture_done(result_capture_done),
    .exact_error_counts(exact_error_counts),
    .exact_error_valid(exact_error_valid),
    .exact_error_saturated(exact_error_saturated),
    .mailbox_i2c_address(mailbox_i2c_address),
    .mailbox_i2c_write(mailbox_i2c_write),
    .mailbox_i2c_write_data(mailbox_i2c_write_data),
    .mailbox_i2c_read_data(mailbox_i2c_read_data),
    .mailbox_i2c_read_data_next(mailbox_i2c_read_data_next),
    .rx_clk(rx_clk),
    .rx_reset(rx_reset),
    .rx_prbs_locked(rx_prbs_locked),
    .rx_cdr_locked(rx_cdr_locked),
    .rx_prbs_errors(rx_prbs_errors),
    .tx_prbs_select(tx_prbs_select),
    .rx_prbs_select(rx_prbs_select),
    .prbs_counter_reset(prbs_counter_reset),
    .lane_running(lane_running),
    .loopback_mode(loopback_mode),
    .measurement_enable(measurement_enable),
    .measurement_run_toggle(measurement_run_toggle),
    .controls_enable(controls_enable),
    .tx_session_active(tx_session_active), .session_tag(session_tag),
    .tx_session_ready(tx_session_ready),
    .config_tx_mask(config_tx_mask), .config_rx_mask(config_rx_mask),
    .config_epoch(config_epoch), .config_tx_observed(config_tx_observed),
    .config_bank_epoch_ack(config_bank_epoch_ack),
    .acquisition_active(acquisition_active),
    .result_capture_request(result_capture_request),
    .accepted_lane_mask(accepted_lane_mask),
    .tx_error_inject_toggle(tx_error_inject_toggle)
  );

  always_ff @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
      aw_pending <= 0;
      w_pending <= 0;
      awaddr_hold <= 0;
      wdata_hold <= 0;
      wstrb_hold <= 0;
      s_axi_bresp <= 2'b00;
      s_axi_bvalid <= 0;
      s_axi_rdata <= 0;
      s_axi_rresp <= 2'b00;
      s_axi_rvalid <= 0;
    end else begin
      // Capture AW and W independently, as required by AXI4-Lite.  Neither
      // channel is assumed to lead the other.
      if (s_axi_awvalid && s_axi_awready) begin
        awaddr_hold <= s_axi_awaddr;
        aw_pending <= 1;
      end
      if (s_axi_wvalid && s_axi_wready) begin
        wdata_hold <= s_axi_wdata;
        wstrb_hold <= s_axi_wstrb;
        w_pending <= 1;
      end
      if (core_write) begin
        // core_write is a one-cycle commit pulse after both holding registers
        // are valid.  Byte strobes are passed through for partial-word writes.
        aw_pending <= 0;
        w_pending <= 0;
        s_axi_bresp <= 2'b00;
        s_axi_bvalid <= 1;
      end else if (s_axi_bvalid && s_axi_bready) begin
        s_axi_bvalid <= 0;
      end

      if (s_axi_arvalid && s_axi_arready) begin
        // The core read mux is combinational; capture it with the accepted
        // address and hold the result stable until the master acknowledges it.
        s_axi_rdata <= core_read_data;
        s_axi_rresp <= 2'b00;
        s_axi_rvalid <= 1;
      end else if (s_axi_rvalid && s_axi_rready) begin
        s_axi_rvalid <= 0;
      end
    end
  end
endmodule
