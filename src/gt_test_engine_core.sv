`timescale 1ns/1ps

// Management-domain control plane for the GT test engine.  Software supplies
// one immutable descriptor, then rings a doorbell.  Hardware owns timing,
// lane-domain handshakes, result collection, atomic publication, and the
// completion interrupt; MicroBlaze does not poll acquisition data.
//
// The AXI and I2C views intentionally expose the same mailbox/result ABI.
// Result records are double-buffered so readers always see one complete run,
// never a mixture of records from the old and new runs.
module gt_test_engine_core #(
  parameter int unsigned LANES = 112,
  parameter int unsigned USER_BITS_PER_CYCLE = 80,
  parameter logic [31:0] HARDWARE_VERSION = 32'h0001_0002,
  parameter logic [LANES-1:0] MANAGED_LANE_MASK = {LANES{1'b1}},
  parameter logic [LANES-1:0] ASYNC_SNAPSHOT_MASK = MANAGED_LANE_MASK
) (
  input  wire                    mgmt_clk,
  input  wire                    mgmt_resetn,

  input  wire                    reg_write,
  input  wire [11:0]             reg_write_address,
  input  wire [31:0]             reg_write_data,
  input  wire [3:0]              reg_write_strobe,
  input  wire [11:0]             reg_read_address,
  output logic [31:0]            reg_read_data,
  output logic                   interrupt,
  output wire                    status_firmware_alive,
  output wire                    status_engine_busy,
  output wire                    status_fault,
  input  wire                    platform_ready,
  input  wire                    platform_fault,
  input  wire [31:0]             platform_status,
  input  wire                    acquisition_ready,
  input  wire                    result_capture_done,
  input  wire [LANES*32-1:0]     exact_error_counts,
  input  wire [LANES-1:0]        exact_error_valid,
  input  wire [LANES-1:0]        exact_error_saturated,

  input  wire [7:0]              mailbox_i2c_address,
  input  wire                    mailbox_i2c_write,
  input  wire [7:0]              mailbox_i2c_write_data,
  output logic [7:0]             mailbox_i2c_read_data,
  output logic [7:0]             mailbox_i2c_read_data_next,

  input  wire [LANES-1:0]        rx_clk,
  input  wire [LANES-1:0]        rx_reset,
  input  wire [LANES-1:0]        rx_prbs_locked,
  input  wire [LANES*16-1:0]     rx_prbs_errors,
  output wire [LANES*3-1:0]      tx_prbs_select,
  output wire [LANES*3-1:0]      rx_prbs_select,
  output wire [LANES-1:0]        prbs_counter_reset,
  output wire [LANES-1:0]        lane_running,
  output wire [2:0]              loopback_mode,
  output wire                    measurement_enable,
  output wire                    controls_enable,
  output wire                    result_capture_request,
  output logic [LANES-1:0]       tx_error_inject_toggle
);
  localparam logic [31:0] HARDWARE_ID = 32'h4754_5354; // "GTST"

  typedef enum logic [3:0] {
    ST_IDLE       = 4'd0,
    ST_ARM_WAIT   = 4'd1,
    ST_RUN        = 4'd2,
    ST_STOP_WAIT  = 4'd3,
    ST_CAPTURE_WAIT = 4'd4,
    ST_COPY       = 4'd5,
    ST_PUBLISH    = 4'd6
  } state_t;

  state_t state = ST_IDLE;
  // Software may edit descriptor_* only while idle.  active_* is the frozen
  // execution copy and cannot be changed by later register/I2C traffic.
  logic [31:0] descriptor_control = 32'h0000_0501; // opcode 0x1, PRBS31
  logic [31:0] descriptor_duration = 32'd1000;
  logic [31:0] descriptor_timeout = 32'd0;
  logic [LANES-1:0] descriptor_lane_mask = {LANES{1'b1}};
  logic [7:0] selected_result_lane = 0;

  logic [LANES-1:0] active_lane_mask = 0;
  logic [2:0] active_prbs_mode = 0;
  logic [2:0] active_loopback_mode = 0;
  logic start_req_toggle = 0, stop_req_toggle = 0;
  logic [31:0] elapsed_cycles = 0;
  logic [17:0] millisecond_divider = 0;
  logic [31:0] run_id = 0;
  logic [7:0] stop_reason = 0;
  logic irq_pending = 0, bad_command = 0;
  logic platform_failed_run = 0;
  logic published_bank = 0;
  logic [6:0] copy_lane = 0;
  logic [7:0] selected_count = 0, passed_count = 0, failed_count = 0;
  logic [31:0] aggregate_summary = 0;
  logic [31:0] mailbox_request_sequence = 0;
  logic [31:0] mailbox_command = 0;
  logic [31:0] mailbox_duration = 0;
  logic [31:0] mailbox_timeout = 0;
  logic [111:0] mailbox_lane_mask = 0;
  logic [31:0] mailbox_firmware_version = 0;
  logic [31:0] mailbox_response_sequence = 0;
  logic [31:0] mailbox_response_code = 0;
  logic [31:0] mailbox_current_word, mailbox_next_word;
  logic [7:0] mailbox_next_address;

  (* ASYNC_REG = "TRUE" *) logic [LANES-1:0] start_ack_meta = 0;
  (* ASYNC_REG = "TRUE" *) logic [LANES-1:0] start_ack_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic [LANES-1:0] stop_ack_meta = 0;
  (* ASYNC_REG = "TRUE" *) logic [LANES-1:0] stop_ack_sync = 0;
  wire [LANES-1:0] start_ack_toggle;
  wire [LANES-1:0] stop_ack_toggle;
  wire [LANES-1:0] snapshot_send;
  wire [LANES-1:0] snapshot_rcv;

  wire [LANES*256-1:0] snapshot_payload_raw;
  wire [LANES*256-1:0] snapshot_payload;

  (* ram_style = "block" *) logic [255:0] result_bank_0 [0:LANES-1];
  (* ram_style = "block" *) logic [255:0] result_bank_1 [0:LANES-1];
  logic [255:0] bank_0_read_data, bank_1_read_data;
  wire [255:0] selected_record = published_bank
    ? bank_1_read_data : bank_0_read_data;

  function automatic logic [31:0] apply_strobe(
    input logic [31:0] previous,
    input logic [31:0] update,
    input logic [3:0] strobe
  );
    logic [31:0] merged;
    begin
      merged = previous;
      for (int byte_index = 0; byte_index < 4; byte_index++)
        if (strobe[byte_index])
          merged[byte_index*8 +: 8] = update[byte_index*8 +: 8];
      apply_strobe = merged;
    end
  endfunction

  function automatic logic [31:0] mailbox_word(input logic [5:0] index);
    // Byte addresses A0-FF map to little-endian 32-bit words.  The I2C slave
    // asks for both the current and following byte to support sequential reads
    // across a word boundary without duplicating this register map.
    case (index)
      6'h28: mailbox_word = mailbox_request_sequence;  // 0xa0
      6'h29: mailbox_word = mailbox_command;           // 0xa4
      6'h2a: mailbox_word = mailbox_duration;          // 0xa8
      6'h2b: mailbox_word = mailbox_timeout;           // 0xac
      6'h2c: mailbox_word = mailbox_lane_mask[31:0];   // 0xb0
      6'h2d: mailbox_word = mailbox_lane_mask[63:32];  // 0xb4
      6'h2e: mailbox_word = mailbox_lane_mask[95:64];  // 0xb8
      6'h2f: mailbox_word = {16'd0, mailbox_lane_mask[111:96]}; // 0xbc
      6'h30: mailbox_word = mailbox_firmware_version;  // 0xc0
      6'h31: mailbox_word = HARDWARE_VERSION;          // 0xc4
      6'h32: mailbox_word = {15'd0, platform_fault, bad_command, irq_pending,
                              10'd0, state};            // 0xc8
      6'h33: mailbox_word = {24'd0, selected_result_lane}; // 0xcc
      6'h34: mailbox_word = selected_record[31:0];      // 0xd0
      6'h35: mailbox_word = selected_record[63:32];
      6'h36: mailbox_word = selected_record[95:64];
      6'h37: mailbox_word = selected_record[127:96];
      6'h38: mailbox_word = selected_record[159:128];
      6'h39: mailbox_word = selected_record[191:160];
      6'h3a: mailbox_word = selected_record[223:192];
      6'h3b: mailbox_word = selected_record[255:224];   // 0xec
      6'h3c: mailbox_word = mailbox_response_sequence;  // 0xf0
      6'h3d: mailbox_word = mailbox_response_code;      // 0xf4
      6'h3e: mailbox_word = run_id;                     // 0xf8
      6'h3f: mailbox_word = aggregate_summary;          // 0xfc
      default: mailbox_word = 0;
    endcase
  endfunction

  for (genvar lane = 0; lane < LANES; lane++) begin : g_lane
    gt_lane_engine #(
      .LANE_ID(lane),
      .USER_BITS_PER_CYCLE(USER_BITS_PER_CYCLE)
    ) u_lane (
      .start_req_toggle(start_req_toggle),
      .stop_req_toggle(stop_req_toggle),
      .descriptor_selected(active_lane_mask[lane]),
      .descriptor_prbs_mode(active_prbs_mode),
      .measurement_enable(measurement_enable),
      .controls_enable(controls_enable),
      .start_ack_toggle(start_ack_toggle[lane]),
      .stop_ack_toggle(stop_ack_toggle[lane]),
      .snapshot_send(snapshot_send[lane]),
      .snapshot_rcv(snapshot_rcv[lane]),
      .rx_clk(rx_clk[lane]),
      .rx_reset(rx_reset[lane]),
      .rx_prbs_locked(rx_prbs_locked[lane]),
      .rx_prbs_errors(rx_prbs_errors[lane*16 +: 16]),
      .tx_prbs_select(tx_prbs_select[lane*3 +: 3]),
      .rx_prbs_select(rx_prbs_select[lane*3 +: 3]),
      .prbs_counter_reset(prbs_counter_reset[lane]),
      .running(lane_running[lane]),
      .snapshot_id_status(snapshot_payload_raw[lane*256 +: 32]),
      .snapshot_errors(snapshot_payload_raw[lane*256 + 32 +: 64]),
      .snapshot_tested_bits(snapshot_payload_raw[lane*256 + 96 +: 64]),
      .snapshot_lock_losses(snapshot_payload_raw[lane*256 + 160 +: 32]),
      .snapshot_valid_cycles(snapshot_payload_raw[lane*256 + 192 +: 64])
    );

    if (ASYNC_SNAPSHOT_MASK[lane]) begin : g_snapshot_cdc
      // The lane holds src_in and src_send until the internal destination
      // handshake has atomically captured the complete result record.
      xpm_cdc_handshake #(
        .DEST_EXT_HSK(0), .DEST_SYNC_FF(2), .INIT_SYNC_FF(0),
        .SIM_ASSERT_CHK(1), .SRC_SYNC_FF(2), .WIDTH(256)
      ) u_snapshot_handshake (
        .src_clk(rx_clk[lane]),
        .src_in(snapshot_payload_raw[lane*256 +: 256]),
        .src_send(snapshot_send[lane]),
        .src_rcv(snapshot_rcv[lane]),
        .dest_clk(mgmt_clk),
        .dest_out(snapshot_payload[lane*256 +: 256]),
        .dest_req(),
        .dest_ack(1'b0)
      );
    end else begin : g_snapshot_same_clock
      assign snapshot_payload[lane*256 +: 256] =
        snapshot_payload_raw[lane*256 +: 256];
      assign snapshot_rcv[lane] = snapshot_send[lane];
    end
  end

  wire [31:0] platform_failure_status =
    32'h0000_2800 | {24'd0, copy_lane};
  wire [255:0] platform_failure_record = {
    64'd0, 32'd1, 64'd0, 64'd0, platform_failure_status
  };
  wire copy_lane_exact_valid = exact_error_valid[copy_lane];
  wire [31:0] copy_lane_exact_errors =
    exact_error_counts[copy_lane*32 +: 32];
  wire [31:0] copy_lane_status = copy_lane_exact_valid
    ? ((snapshot_payload[copy_lane*256 +: 32] & 32'hffff_bfff) |
       {17'd0, exact_error_saturated[copy_lane], 14'd0})
    : snapshot_payload[copy_lane*256 +: 32];
  wire [63:0] copy_lane_errors = copy_lane_exact_valid
    ? {32'd0, copy_lane_exact_errors}
    : snapshot_payload[copy_lane*256 + 32 +: 64];
  wire [255:0] measured_lane_record = {
    snapshot_payload[copy_lane*256 + 96 +: 160],
    copy_lane_errors, copy_lane_status
  };
  wire [255:0] copy_lane_record =
    // A physical-platform failure can remove the RX clocks needed for normal
    // lane acknowledgements.  In that case publish deterministic failed
    // records from mgmt_clk so the job still completes atomically.
    (platform_failed_run && active_lane_mask[copy_lane])
      ? platform_failure_record
      : measured_lane_record;
  wire copy_lane_selected = copy_lane_record[11];
  wire copy_lane_passed = copy_lane_selected &&
                          copy_lane_record[12] &&
                          !copy_lane_record[13] &&
                          copy_lane_record[32 +: 64] == 0;

  always_comb begin
    // The native AXI register map includes debug controls and direct descriptor
    // access.  Addresses 0A0-0FC mirror the MCU-visible mailbox byte range.
    reg_read_data = 32'd0;
    case (reg_read_address)
      12'h000: reg_read_data = HARDWARE_ID;
      12'h004: reg_read_data = HARDWARE_VERSION;
      12'h008: reg_read_data = {LANES[7:0], 8'd28, 8'd12, 8'h3f};
      12'h00c: reg_read_data = 32'd0;
      12'h010: reg_read_data = {15'd0, platform_fault, bad_command,
                                irq_pending, 10'd0, state};
      12'h014: reg_read_data = {30'd0, bad_command, irq_pending};
      12'h018: reg_read_data = run_id;
      12'h01c: reg_read_data = aggregate_summary;
      12'h020: reg_read_data = descriptor_control;
      12'h024: reg_read_data = descriptor_duration;
      12'h028: reg_read_data = descriptor_timeout;
      12'h02c: reg_read_data = descriptor_lane_mask[31:0];
      12'h030: reg_read_data = descriptor_lane_mask[63:32];
      12'h034: reg_read_data = descriptor_lane_mask[95:64];
      12'h038: reg_read_data = {16'd0, descriptor_lane_mask[111:96]};
      12'h03c: reg_read_data = {24'd0, selected_result_lane};
      12'h040: reg_read_data = selected_record[31:0];
      12'h044: reg_read_data = selected_record[63:32];
      12'h048: reg_read_data = selected_record[95:64];
      12'h04c: reg_read_data = selected_record[127:96];
      12'h050: reg_read_data = selected_record[159:128];
      12'h054: reg_read_data = selected_record[191:160];
      12'h058: reg_read_data = selected_record[223:192];
      12'h05c: reg_read_data = selected_record[255:224];
      12'h060: reg_read_data = tx_error_inject_toggle[31:0];
      12'h064: reg_read_data = tx_error_inject_toggle[63:32];
      12'h068: reg_read_data = tx_error_inject_toggle[95:64];
      12'h06c: reg_read_data = {16'd0, tx_error_inject_toggle[111:96]};
      12'h070: reg_read_data = platform_status;
      12'h074: reg_read_data = MANAGED_LANE_MASK[31:0];
      12'h078: reg_read_data = MANAGED_LANE_MASK[63:32];
      12'h07c: reg_read_data = MANAGED_LANE_MASK[95:64];
      12'h080: reg_read_data = {16'd0, MANAGED_LANE_MASK[111:96]};
      12'h0a0: reg_read_data = mailbox_request_sequence;
      12'h0a4: reg_read_data = mailbox_command;
      12'h0a8: reg_read_data = mailbox_duration;
      12'h0ac: reg_read_data = mailbox_timeout;
      12'h0b0: reg_read_data = mailbox_lane_mask[31:0];
      12'h0b4: reg_read_data = mailbox_lane_mask[63:32];
      12'h0b8: reg_read_data = mailbox_lane_mask[95:64];
      12'h0bc: reg_read_data = {16'd0, mailbox_lane_mask[111:96]};
      12'h0c0: reg_read_data = mailbox_firmware_version;
      12'h0c4: reg_read_data = HARDWARE_VERSION;
      12'h0c8: reg_read_data = {15'd0, platform_fault, bad_command, irq_pending,
                                10'd0, state};
      12'h0cc: reg_read_data = {24'd0, selected_result_lane};
      12'h0d0: reg_read_data = selected_record[31:0];
      12'h0d4: reg_read_data = selected_record[63:32];
      12'h0d8: reg_read_data = selected_record[95:64];
      12'h0dc: reg_read_data = selected_record[127:96];
      12'h0e0: reg_read_data = selected_record[159:128];
      12'h0e4: reg_read_data = selected_record[191:160];
      12'h0e8: reg_read_data = selected_record[223:192];
      12'h0ec: reg_read_data = selected_record[255:224];
      12'h0f0: reg_read_data = mailbox_response_sequence;
      12'h0f4: reg_read_data = mailbox_response_code;
      12'h0f8: reg_read_data = run_id;
      12'h0fc: reg_read_data = aggregate_summary;
      default: reg_read_data = 32'd0;
    endcase
    mailbox_next_address = mailbox_i2c_address + 1'b1;
    mailbox_current_word = mailbox_word(mailbox_i2c_address[7:2]);
    mailbox_next_word = mailbox_word(mailbox_next_address[7:2]);
    mailbox_i2c_read_data = mailbox_current_word
      [mailbox_i2c_address[1:0]*8 +: 8];
    mailbox_i2c_read_data_next = mailbox_next_word
      [mailbox_next_address[1:0]*8 +: 8];
  end

  assign interrupt = irq_pending;
  assign loopback_mode = active_loopback_mode;
  assign measurement_enable = state == ST_RUN;
  assign controls_enable = state != ST_IDLE;
  assign result_capture_request = state == ST_CAPTURE_WAIT;
  // These coarse status outputs are intended for board-level indicators.
  // Firmware-alive cannot assert until MicroBlaze has executed its AXI write
  // to the version mailbox, making the indication distinct from configuration
  // and fabric clock activity.
  assign status_firmware_alive = mailbox_firmware_version != 0;
  assign status_engine_busy = state != ST_IDLE;
  assign status_fault = bad_command ||
                        platform_fault ||
                        (mailbox_response_sequence != 0 &&
                         mailbox_response_code == 32'd1) ||
                        (run_id != 0 &&
                         (aggregate_summary[31:24] != 0 ||
                          aggregate_summary[7:0] != 8'd1));

  always_ff @(posedge mgmt_clk) begin
    // Synchronous reads let each 112x256 result bank infer as block RAM.  The
    // selected lane is software-controlled and cached one clock later.
    bank_0_read_data <= result_bank_0[selected_result_lane];
    bank_1_read_data <= result_bank_1[selected_result_lane];
    if (!mgmt_resetn) begin
      state <= ST_IDLE;
      descriptor_control <= 32'h0000_0501;
      descriptor_duration <= 32'd1000;
      descriptor_timeout <= 0;
      descriptor_lane_mask <= MANAGED_LANE_MASK;
      selected_result_lane <= 0;
      active_lane_mask <= 0;
      active_prbs_mode <= 0;
      active_loopback_mode <= 0;
      start_req_toggle <= 0;
      stop_req_toggle <= 0;
      elapsed_cycles <= 0;
      millisecond_divider <= 0;
      run_id <= 0;
      stop_reason <= 0;
      irq_pending <= 0;
      bad_command <= 0;
      platform_failed_run <= 0;
      published_bank <= 0;
      copy_lane <= 0;
      selected_count <= 0;
      passed_count <= 0;
      failed_count <= 0;
      aggregate_summary <= 0;
      mailbox_request_sequence <= 0;
      mailbox_command <= 0;
      mailbox_duration <= 0;
      mailbox_timeout <= 0;
      mailbox_lane_mask <= 0;
      mailbox_firmware_version <= 0;
      mailbox_response_sequence <= 0;
      mailbox_response_code <= 0;
      start_ack_meta <= 0;
      start_ack_sync <= 0;
      stop_ack_meta <= 0;
      stop_ack_sync <= 0;
      tx_error_inject_toggle <= 0;
    end else begin
      start_ack_meta <= start_ack_toggle;
      start_ack_sync <= start_ack_meta;
      stop_ack_meta <= stop_ack_toggle;
      stop_ack_sync <= stop_ack_meta;

      if (reg_write) begin
        case (reg_write_address)
          12'h00c: begin
            // Control is write-one-action: bit 0 starts, bit 1 aborts an active
            // run, and bit 2 acknowledges/clears completion diagnostics.
            if (reg_write_data[2]) begin
              irq_pending <= 0;
              bad_command <= 0;
            end
            if (reg_write_data[1] && state != ST_IDLE &&
                state != ST_STOP_WAIT && state != ST_CAPTURE_WAIT &&
                state != ST_COPY &&
                state != ST_PUBLISH) begin
              stop_reason <= 8'd2;
              stop_req_toggle <= ~stop_req_toggle;
              state <= ST_STOP_WAIT;
            end
            if (reg_write_data[0]) begin
              // Validate the complete descriptor at the doorbell.  In
              // particular, hardware rejects every lane outside the target's
              // MANAGED_LANE_MASK even if software writes such a mask.
              if (state == ST_IDLE && platform_ready &&
                  descriptor_control[7:0] == 8'h1 &&
                  descriptor_control[10:8] != 0 &&
                  descriptor_control[10:8] <= 5 &&
                  descriptor_duration != 0 &&
                  descriptor_lane_mask != 0 &&
                  (descriptor_lane_mask & ~MANAGED_LANE_MASK) == 0) begin
                active_lane_mask <= descriptor_lane_mask;
                active_prbs_mode <= descriptor_control[10:8];
                active_loopback_mode <= descriptor_control[13:11];
                elapsed_cycles <= 0;
                millisecond_divider <= 0;
                stop_reason <= 0;
                selected_count <= 0;
                passed_count <= 0;
                failed_count <= 0;
                bad_command <= 0;
                platform_failed_run <= 0;
                start_req_toggle <= ~start_req_toggle;
                state <= ST_ARM_WAIT;
              end else begin
                bad_command <= 1;
                irq_pending <= 1;
              end
            end
          end
          12'h020: if (state == ST_IDLE)
            descriptor_control <= apply_strobe(descriptor_control,
                                                reg_write_data,
                                                reg_write_strobe);
          12'h024: if (state == ST_IDLE)
            descriptor_duration <= apply_strobe(descriptor_duration,
                                                 reg_write_data,
                                                 reg_write_strobe);
          12'h028: if (state == ST_IDLE)
            descriptor_timeout <= apply_strobe(descriptor_timeout,
                                                reg_write_data,
                                                reg_write_strobe);
          12'h02c: if (state == ST_IDLE)
            descriptor_lane_mask[31:0] <= apply_strobe(
              descriptor_lane_mask[31:0], reg_write_data, reg_write_strobe);
          12'h030: if (state == ST_IDLE)
            descriptor_lane_mask[63:32] <= apply_strobe(
              descriptor_lane_mask[63:32], reg_write_data, reg_write_strobe);
          12'h034: if (state == ST_IDLE)
            descriptor_lane_mask[95:64] <= apply_strobe(
              descriptor_lane_mask[95:64], reg_write_data, reg_write_strobe);
          12'h038: if (state == ST_IDLE) begin
            if (reg_write_strobe[0])
              descriptor_lane_mask[103:96] <= reg_write_data[7:0];
            if (reg_write_strobe[1])
              descriptor_lane_mask[111:104] <= reg_write_data[15:8];
          end
          12'h03c: if (reg_write_data[7:0] < LANES)
            selected_result_lane <= reg_write_data[7:0];
          12'h060: tx_error_inject_toggle[31:0] <=
            tx_error_inject_toggle[31:0] ^
            (reg_write_data & MANAGED_LANE_MASK[31:0]);
          12'h064: tx_error_inject_toggle[63:32] <=
            tx_error_inject_toggle[63:32] ^
            (reg_write_data & MANAGED_LANE_MASK[63:32]);
          12'h068: tx_error_inject_toggle[95:64] <=
            tx_error_inject_toggle[95:64] ^
            (reg_write_data & MANAGED_LANE_MASK[95:64]);
          12'h06c: tx_error_inject_toggle[111:96] <=
            tx_error_inject_toggle[111:96] ^
            (reg_write_data[15:0] & MANAGED_LANE_MASK[111:96]);
          12'h0c0: mailbox_firmware_version <= apply_strobe(
            mailbox_firmware_version, reg_write_data, reg_write_strobe);
          12'h0cc: if (reg_write_data[7:0] < LANES)
            selected_result_lane <= reg_write_data[7:0];
          12'h0f0: mailbox_response_sequence <= apply_strobe(
            mailbox_response_sequence, reg_write_data, reg_write_strobe);
          12'h0f4: mailbox_response_code <= apply_strobe(
            mailbox_response_code, reg_write_data, reg_write_strobe);
          default: ;
        endcase
      end

      if (mailbox_i2c_write && mailbox_i2c_address >= 8'ha0) begin
        // I2C writes update one byte at a time.  Firmware treats A0 as the
        // commit sequence and validates/readbacks the remaining fields before
        // translating the mailbox request into the AXI descriptor above.
        case (mailbox_i2c_address[7:2])
          6'h28: mailbox_request_sequence
            [mailbox_i2c_address[1:0]*8 +: 8] <= mailbox_i2c_write_data;
          6'h29: mailbox_command
            [mailbox_i2c_address[1:0]*8 +: 8] <= mailbox_i2c_write_data;
          6'h2a: mailbox_duration
            [mailbox_i2c_address[1:0]*8 +: 8] <= mailbox_i2c_write_data;
          6'h2b: mailbox_timeout
            [mailbox_i2c_address[1:0]*8 +: 8] <= mailbox_i2c_write_data;
          6'h2c: mailbox_lane_mask
            [mailbox_i2c_address[1:0]*8 +: 8] <= mailbox_i2c_write_data;
          6'h2d: mailbox_lane_mask
            [32 + mailbox_i2c_address[1:0]*8 +: 8] <= mailbox_i2c_write_data;
          6'h2e: mailbox_lane_mask
            [64 + mailbox_i2c_address[1:0]*8 +: 8] <= mailbox_i2c_write_data;
          6'h2f: if (!mailbox_i2c_address[1])
            mailbox_lane_mask[96 + mailbox_i2c_address[0]*8 +: 8]
              <= mailbox_i2c_write_data;
          6'h33: if (mailbox_i2c_address[1:0] == 0 &&
                       mailbox_i2c_write_data < LANES)
            selected_result_lane <= mailbox_i2c_write_data;
          default: ;
        endcase
      end

      case (state)
        ST_IDLE: ;

        ST_ARM_WAIT: begin
          // Every lane, including unselected lanes, acknowledges the start
          // toggle.  Physical acquisition additionally waits for the quad-local
          // reset/lock sequencer to declare its measurement window ready.
          if (platform_fault) begin
            // A lost QPLL/user clock cannot be relied upon to return a lane
            // handshake. Publish deterministic failed records entirely in
            // the management domain so the job still terminates atomically.
            stop_reason <= 8'd4;
            platform_failed_run <= 1;
            copy_lane <= 0;
            state <= ST_COPY;
          end else if (start_ack_sync == {LANES{start_req_toggle}} &&
                       acquisition_ready) begin
            elapsed_cycles <= 0;
            state <= ST_RUN;
          end
        end

        ST_RUN: begin
          if (platform_fault) begin
            stop_reason <= 8'd4;
            platform_failed_run <= 1;
            copy_lane <= 0;
            state <= ST_COPY;
          end else if (!descriptor_control[16] ||
                       millisecond_divider == 18'd199999) begin
            // Bit 16 selects a hardware-generated 1-ms tick.  With it clear,
            // duration and timeout retain their legacy 200-MHz-cycle units.
            millisecond_divider <= 0;
            elapsed_cycles <= elapsed_cycles + 1'b1;
            if (descriptor_timeout != 0 &&
                elapsed_cycles + 1'b1 >= descriptor_timeout &&
                descriptor_timeout < descriptor_duration) begin
              stop_reason <= 8'd3;
              stop_req_toggle <= ~stop_req_toggle;
              state <= ST_STOP_WAIT;
            end else if (elapsed_cycles + 1'b1 >= descriptor_duration) begin
              stop_reason <= 8'd1;
              stop_req_toggle <= ~stop_req_toggle;
              state <= ST_STOP_WAIT;
            end
          end else begin
            millisecond_divider <= millisecond_divider + 1'b1;
          end
        end

        ST_STOP_WAIT: begin
          // Lane stop acknowledgements are withheld until each 256-bit result
          // snapshot has completed its CDC handshake.
          if (platform_fault) begin
            stop_reason <= 8'd4;
            platform_failed_run <= 1;
            copy_lane <= 0;
            state <= ST_COPY;
          end else if (stop_ack_sync == {LANES{stop_req_toggle}}) begin
            state <= ST_CAPTURE_WAIT;
          end
        end

        ST_CAPTURE_WAIT: begin
          if (platform_fault) begin
            stop_reason <= 8'd4;
            platform_failed_run <= 1;
            copy_lane <= 0;
            state <= ST_COPY;
          end else if (result_capture_done) begin
            copy_lane <= 0;
            state <= ST_COPY;
          end
        end

        ST_COPY: begin
          // Write only the hidden bank while accumulating the aggregate.  The
          // currently published bank remains immutable for AXI/I2C readers.
          if (published_bank)
            result_bank_0[copy_lane] <= copy_lane_record;
          else
            result_bank_1[copy_lane] <= copy_lane_record;
          if (copy_lane_selected) begin
            selected_count <= selected_count + 1'b1;
            if (copy_lane_passed)
              passed_count <= passed_count + 1'b1;
            else
              failed_count <= failed_count + 1'b1;
          end
          if (copy_lane == LANES-1)
            state <= ST_PUBLISH;
          else
            copy_lane <= copy_lane + 1'b1;
        end

        ST_PUBLISH: begin
          // One bank-select flip makes all lane records and the aggregate
          // visible together.  Increment run_id and raise a level interrupt in
          // the same publication event.
          aggregate_summary <= {
            failed_count, passed_count, selected_count, stop_reason
          };
          published_bank <= ~published_bank;
          run_id <= run_id + 1'b1;
          irq_pending <= 1;
          state <= ST_IDLE;
        end

        default: state <= ST_IDLE;
      endcase
    end
  end
endmodule
