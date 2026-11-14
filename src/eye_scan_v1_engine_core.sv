`timescale 1ns/1ps

// Separate eye-scan v1 implementation, based on preserved v3 commit a82d50b.

// Management-domain control plane for the GT test engine.  Software supplies
// one immutable descriptor, then rings a doorbell.  Hardware owns timing,
// lane-domain handshakes, result collection, atomic publication, and the
// completion interrupt; MicroBlaze does not poll acquisition data.
//
// The AXI and I2C views intentionally expose the same mailbox/result ABI.
// Result records are double-buffered so readers always see one complete run,
// never a mixture of records from the old and new runs.
module eye_scan_v1_engine_core #(
  // XSim 2023.2 shares $past history for identical XPM request ports.
  // Hardware builds retain vendor assertions; the engine simulation overrides
  // this and checks every chunk with independent procedural monitors.
  parameter bit SNAPSHOT_VENDOR_ASSERTIONS = 1'b1,
  parameter integer CONFIG_TIMEOUT_CYCLES = 200000000,
  parameter bit ENABLE_TX_SESSION = 1'b0,
  parameter int unsigned SESSION_CYCLES_PER_MS = 200000,
  parameter int unsigned LANES = 112,
  parameter int unsigned USER_BITS_PER_CYCLE = 80,
  parameter bit LOCALIZE_DESCRIPTOR_CONTROLS = 1'b0,
  parameter logic [31:0] HARDWARE_VERSION = 32'h0001_0002,
  parameter bit ALL_LINKS_V2_TIMING_HARDENING =
    1'b1,
  parameter logic [LANES-1:0] MANAGED_LANE_MASK = {LANES{1'b1}},
  parameter logic [LANES-1:0] ASYNC_SNAPSHOT_MASK = MANAGED_LANE_MASK
) (
  input  wire                    mgmt_clk,
  input  wire                    mgmt_resetn,

  input wire eye_lock,
  output wire eye_eligible,
  output wire [31:0] eye_session_remaining_ms,
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
  input wire config_controllers_idle,
  input  wire                    platform_fault,
  input  wire [31:0]             platform_status,
  input  wire [223:0]            platform_diagnostics,
  input  wire [255:0]            recovery_diagnostics,
  input  wire [255:0]            diagnostic_record,
  output wire [7:0]              diagnostic_selector,
  output logic [1:0]             diagnostic_bank = 0,
  output wire [31:0]             engine_protocol_debug,
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
  input  wire [LANES-1:0]        rx_cdr_locked,
  input  wire [LANES*16-1:0]     rx_prbs_errors,
  output wire [LANES*3-1:0]      tx_prbs_select,
  output wire [LANES*3-1:0]      rx_prbs_select,
  output wire [LANES-1:0]        prbs_counter_reset,
  output wire [LANES-1:0]        lane_running,
  output wire [2:0]              loopback_mode,
  output wire                    measurement_enable,
  output wire                    measurement_run_toggle,
  output wire                    controls_enable,
  output logic                   tx_session_active = 0,
  output wire [1:0] session_tag,
  input  wire                    tx_session_ready,
  output wire [27:0] config_tx_mask, config_rx_mask,
  output wire config_epoch,
  input wire [27:0] config_tx_observed, config_bank_epoch_ack,
  output wire                    acquisition_active,
  output wire                    result_capture_request,
  output wire [LANES-1:0]        accepted_lane_mask,
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

  // Low state bits are visible through AXI and I2C status registers.
  (* fsm_encoding = "none" *) state_t state = ST_IDLE;
  logic [2:0] active_loopback_mode = 0;
  logic [31:0] session_duration_ms = 0, session_remaining_ms = 0;
  logic [31:0] session_tick = 0;
  logic session_expired = 0, session_rejected = 0;
  logic [1:0] session_serial = 0;
  assign session_tag = session_serial ^ (session_serial >> 1);
  wire session_measurement_fault = ENABLE_TX_SESSION && state != ST_IDLE &&
                                   active_loopback_mode == 0 &&
                                   (config_tx_mask != 0 && (!tx_session_active || !tx_session_ready));
  wire effective_platform_fault = platform_fault || session_measurement_fault;
  wire [LANES-1:0] snapshot_send;
  wire config_busy, config_usable;
  wire [255:0] config_record;
  wire [111:0] config_rx_lanes, config_tx_lanes;
  wire [111:0] lane_epoch_ack;
  (* ASYNC_REG = "TRUE" *) logic [111:0] epoch_meta = 0, epoch_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic [111:0] send_meta = 0, send_sync = 0;
  assign eye_session_remaining_ms = session_remaining_ms;
  assign eye_eligible = state == ST_IDLE && config_controllers_idle &&
    config_usable && !config_busy && send_sync == 0 && !effective_platform_fault &&
    (config_tx_mask == 0 || (tx_session_active && tx_session_ready));
  always_ff @(posedge mgmt_clk) begin
    if (!mgmt_resetn) begin
      epoch_meta <= 0; epoch_sync <= 0; send_meta <= 0; send_sync <= 0;
    end else begin
      epoch_meta <= lane_epoch_ack; epoch_sync <= epoch_meta;
      send_meta <= snapshot_send; send_sync <= send_meta;
    end
  end
  wire [27:0] config_rx_observed, config_rx_observed_local, config_tx_observed_return;
  for (genvar cq = 0; cq < 28; cq++) begin : g_config_expand
    assign config_rx_lanes[cq*4 +: 4] = {4{config_rx_mask[cq]}};
    assign config_tx_lanes[cq*4 +: 4] = {4{config_tx_mask[cq]}};
  end
  wire [3:0] config_group_ok, config_group_phase;
  wire [7:0] config_return;
  wire [27:0] config_lane_enabled, config_lane_epoch;
  logic [2:0] config_phase_guard = 0;
  logic config_phase_seen = 0;
  always_ff @(posedge mgmt_clk) begin
    config_phase_seen <= config_epoch;
    if (config_phase_seen != config_epoch) config_phase_guard <= 0;
    else if (config_phase_guard != 7) config_phase_guard <= config_phase_guard + 1'b1;
  end
  logic config_settled = 0, config_settled_phase = 0;
  wire config_application_settled = (&config_phase_guard) && config_phase_seen == config_epoch &&
    config_settled && config_settled_phase == config_epoch;
  always_ff @(posedge mgmt_clk) begin
    config_settled_phase <= config_epoch;
    config_settled <= config_return[0] && config_return[2] && config_return[4] && config_return[6] &&
      {config_return[7],config_return[5],config_return[3],config_return[1]} == {4{config_epoch}};
  end
`define CONFIG_ACK_BANK(NAME,IDX,FIRST,NQ) \
  (* KEEP_HIERARCHY = "yes" *) all_links_v3_config_ack_bank #(.QUADS(NQ)) NAME ( \
    .clk(mgmt_clk),.epoch(config_epoch), \
    .left_tx(config_tx_mask[FIRST+:NQ]),.right_tx(config_tx_mask[14+FIRST+:NQ]), \
    .left_rx(config_rx_mask[FIRST+:NQ]),.right_rx(config_rx_mask[14+FIRST+:NQ]), \
    .left_tx_observed(config_tx_observed[FIRST+:NQ]), \
    .right_tx_observed(config_tx_observed[14+FIRST+:NQ]), \
    .left_rx_ack(epoch_sync[FIRST*4+:NQ*4]),.right_rx_ack(epoch_sync[56+FIRST*4+:NQ*4]), \
    .group_ok(config_group_ok[IDX]),.group_phase(config_group_phase[IDX]), \
    .left_rx_observed(config_rx_observed_local[FIRST+:NQ]), \
    .right_rx_observed(config_rx_observed_local[14+FIRST+:NQ]), \
    .left_lane_enable(config_lane_enabled[FIRST+:NQ]), \
    .right_lane_enable(config_lane_enabled[14+FIRST+:NQ]), \
    .left_lane_epoch(config_lane_epoch[FIRST+:NQ]), \
    .right_lane_epoch(config_lane_epoch[14+FIRST+:NQ]));
  `CONFIG_ACK_BANK(u_config_ack_slr0,0,0,3)
  `CONFIG_ACK_BANK(u_config_ack_slr1,1,3,4)
  `CONFIG_ACK_BANK(u_config_ack_slr2,2,7,4)
  `CONFIG_ACK_BANK(u_config_ack_slr3,3,11,3)
`undef CONFIG_ACK_BANK
`define CONFIG_RETURN(NAME,IDX) \
  (* KEEP_HIERARCHY = "yes" *) all_links_v3_return_pipeline #(.WIDTH(2)) NAME ( \
    .clk(mgmt_clk), .data({config_group_phase[IDX],config_group_ok[IDX]}), \
    .stage_two(config_return[IDX*2 +: 2]));
  `CONFIG_RETURN(u_config_return_slr0,0)
  `CONFIG_RETURN(u_config_return_slr1,1)
  `CONFIG_RETURN(u_config_return_slr2,2)
  `CONFIG_RETURN(u_config_return_slr3,3)
`undef CONFIG_RETURN
`define OBSERVED_RETURN(NAME,FIRST,NQ) \
  (* KEEP_HIERARCHY = "yes" *) all_links_v3_return_pipeline #(.WIDTH(4*NQ)) NAME ( \
    .clk(mgmt_clk), \
    .data({config_rx_observed_local[14+FIRST+:NQ],config_rx_observed_local[FIRST+:NQ], \
           config_tx_observed[14+FIRST+:NQ],config_tx_observed[FIRST+:NQ]}), \
    .stage_two({config_rx_observed[14+FIRST+:NQ],config_rx_observed[FIRST+:NQ], \
                config_tx_observed_return[14+FIRST+:NQ],config_tx_observed_return[FIRST+:NQ]}));
  `OBSERVED_RETURN(u_observed_return_slr0,0,3)
  `OBSERVED_RETURN(u_observed_return_slr1,3,4)
  `OBSERVED_RETURN(u_observed_return_slr2,7,4)
  `OBSERVED_RETURN(u_observed_return_slr3,11,3)
`undef OBSERVED_RETURN
  all_links_v3_config #(.APPLY_TIMEOUT_CYCLES(CONFIG_TIMEOUT_CYCLES)) u_config (
    .clk(mgmt_clk), .resetn(mgmt_resetn),
    .eligible(!eye_lock && state == ST_IDLE && config_controllers_idle && !tx_session_active && !tx_session_ready && send_sync == 0),
    .barrier_clear(!tx_session_ready),
    .write(reg_write), .address(reg_write_address), .data(reg_write_data),
    .strobe(reg_write_strobe), .tx_observed(config_tx_observed_return),
    .rx_observed(config_rx_observed), .epoch_ack(config_bank_epoch_ack),
    .application_settled(config_application_settled),
    .tx_mask(config_tx_mask), .rx_mask(config_rx_mask), .epoch(config_epoch),
    .busy(config_busy), .usable(config_usable), .record(config_record));
  wire [31:0] session_status = ENABLE_TX_SESSION ?
    {27'd0, tx_session_ready, 1'b1, session_rejected, session_expired,
     tx_session_active} : 32'd0;
  // Session control is independent of RX clocks and local measurement state.
  // No implicit renewal, and no register can extend an active lease.
  always_ff @(posedge mgmt_clk) begin
    if (!mgmt_resetn || !ENABLE_TX_SESSION) begin
      tx_session_active <= 0; session_serial <= 0;
      session_duration_ms <= 0; session_remaining_ms <= 0; session_tick <= 0;
      session_expired <= 0; session_rejected <= 0;
    end else begin
      if (tx_session_active) begin
        if (platform_fault || session_tick == SESSION_CYCLES_PER_MS-1) begin
          session_tick <= 0;
          if (platform_fault || session_remaining_ms <= 1) begin
            tx_session_active <= 0; session_serial <= session_serial + 1'b1;
            session_remaining_ms <= 0; session_expired <= 1;
          end else session_remaining_ms <= session_remaining_ms - 1'b1;
        end else session_tick <= session_tick + 1'b1;
      end
      if (reg_write && reg_write_strobe == 4'hf) begin
        if (reg_write_address == 12'h10c && !tx_session_active && state == ST_IDLE)
          session_duration_ms <= reg_write_data;
        if (reg_write_address == 12'h100) begin
          session_rejected <= 1;
          if (reg_write_data == 1 && !eye_lock && !tx_session_active && state == ST_IDLE &&
              config_usable && !config_busy && config_tx_mask != 0 && !tx_session_ready &&
              platform_ready && !platform_fault && session_duration_ms != 0 &&
              session_duration_ms <= 86400000) begin
            tx_session_active <= 1; session_serial <= session_serial + 1'b1; session_expired <= 0; session_rejected <= 0;
            session_remaining_ms <= session_duration_ms; session_tick <= 0;
          end else if (reg_write_data == 2 && state == ST_IDLE &&
                       (tx_session_active || !tx_session_ready)) begin
            if (tx_session_active) session_serial <= session_serial + 1'b1;
            tx_session_active <= 0; session_remaining_ms <= 0; session_tick <= 0;
            session_rejected <= 0;
          end
        end
      end
    end
  end
  // Software may edit descriptor_* only while idle.  active_* is the frozen
  // execution copy and cannot be changed by later register/I2C traffic.
  logic [31:0] descriptor_control = 32'h0000_0501; // opcode 0x1, PRBS31
  logic [31:0] descriptor_duration = 32'd1000;
  logic [31:0] descriptor_timeout = 32'd0;
  logic [LANES-1:0] descriptor_lane_mask = {LANES{1'b1}};
  logic [7:0] selected_result_lane = 0;
  logic diagnostic_page_selected = 0;
  logic recovery_page_selected = 0;
  logic [255:0] recovery_snapshot = 0;
  logic trace_page_selected = 0;
  logic [7:0] trace_selector = 0;
  assign diagnostic_selector = trace_selector;

  logic [LANES-1:0] active_lane_mask = 0;
  // Frozen at descriptor acceptance and unchanged through publication.  This
  // management-domain copy lets target-specific platform reducers use the
  // same execution epoch as every lane descriptor launch.
  assign accepted_lane_mask = active_lane_mask;
  logic [2:0] active_prbs_mode = 0;
  wire [LANES-1:0] descriptor_selected_to_lane;
  wire [LANES*3-1:0] descriptor_prbs_to_lane;

  // The all-direct image spans four SLRs.  One parallel management-clock
  // launch stage per managed lane gives each native-domain descriptor CDC a
  // local, equal-latency source.  The descriptor is handshake-stable until
  // all lane acknowledgements return, so this intentional cycle is benign.
  for (genvar descriptor_lane = 0; descriptor_lane < LANES; descriptor_lane++) begin : g_descriptor_launch
    if (LOCALIZE_DESCRIPTOR_CONTROLS && MANAGED_LANE_MASK[descriptor_lane]) begin : g_local
      (* DONT_TOUCH = "yes" *) logic selected_launch = 1'b0;
      (* DONT_TOUCH = "yes" *) logic [2:0] prbs_launch = 3'd0;
      always_ff @(posedge mgmt_clk) begin
        selected_launch <= active_lane_mask[descriptor_lane];
        prbs_launch <= active_prbs_mode;
      end
      assign descriptor_selected_to_lane[descriptor_lane] = selected_launch;
      assign descriptor_prbs_to_lane[descriptor_lane*3 +: 3] = prbs_launch;
    end else begin : g_direct
      assign descriptor_selected_to_lane[descriptor_lane] = active_lane_mask[descriptor_lane];
      assign descriptor_prbs_to_lane[descriptor_lane*3 +: 3] = active_prbs_mode;
    end
  end
  logic start_req_toggle = 0, stop_req_toggle = 0;
  // A dedicated source flop prevents decoded-FSM skew from appearing as a
  // second measurement window in an RX clock domain.
  logic measurement_active = 0;
  logic [31:0] elapsed_cycles = 0;
  logic [17:0] millisecond_divider = 0;
  logic [31:0] run_id = 0;
  logic [7:0] stop_reason = 0;
  logic irq_pending = 0, bad_command = 0;
  logic platform_failed_run = 0;
  logic published_bank = 0;
  logic [6:0] copy_lane = 0;
  // The 56-to-1 result mux crosses SLR boundaries.  Hold its selector and
  // immutable post-capture sources for a settle cycle, register the selected
  // record, then commit it on a third cycle.  This preserves the published
  // FSM encoding/ABI while making the wide mux an explicit two-cycle path.
  logic [2:0] copy_phase = 0;
  (* dont_touch = "true" *) logic [255:0] copy_record_stage = 0;
  logic copy_mask_mismatch_stage = 0;
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
  wire [LANES-1:0] snapshot_rcv;
  assign engine_protocol_debug = {12'd0, start_ack_sync[15:12], stop_ack_sync[15:12],
    state, controls_enable, measurement_enable, acquisition_active,
    start_req_toggle, stop_req_toggle, 3'd0};

  wire [LANES*256-1:0] snapshot_payload_raw;
  wire [LANES*256-1:0] snapshot_payload;
  wire [LANES*256-1:0] snapshot_received;

  (* ram_style = "block" *) logic [255:0] result_bank_0 [0:LANES-1];
  (* ram_style = "block" *) logic [255:0] result_bank_1 [0:LANES-1];
  logic [255:0] bank_0_read_data, bank_1_read_data;
  wire [255:0] selected_lane_record = published_bank
    ? bank_1_read_data : bank_0_read_data;
  // Selector 0xfe reserves one read-only 256-bit page for persistent platform
  // diagnostics without consuming the deployed 0xa0-0xff mailbox addresses.
  wire [255:0] selected_record_next = diagnostic_page_selected
    ? {platform_diagnostics, platform_status} :
      recovery_page_selected ? recovery_snapshot :
      trace_page_selected ? (trace_selector == 8'hf7 ? config_record : diagnostic_record) : selected_lane_record;
  // Separate BRAM/page selection from AXI/I2C word and byte selection. Page
  // writes settle before either bus can complete its following data access.
  logic [255:0] selected_record = 0;
  always_ff @(posedge mgmt_clk) selected_record <= selected_record_next;

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
      6'h32: mailbox_word = {15'd0, effective_platform_fault, bad_command, irq_pending,
                              10'd0, state} | (session_status << 17); // 0xc8
      6'h33: mailbox_word = diagnostic_page_selected
        ? 32'h0000_00fe : recovery_page_selected ? 32'hfd :
          trace_page_selected ? {22'd0, diagnostic_bank, trace_selector} :
          {24'd0, selected_result_lane}; // 0xcc
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
    if (MANAGED_LANE_MASK[lane]) begin : g_managed
      // Protocol phase follows the management reset only. GT recovery must
      // never reset toggles, including unselected or stopped lane engines.
      (* ASYNC_REG = "TRUE" *) logic [1:0] protocol_reset_sync = 2'b11;
      always_ff @(posedge rx_clk[lane] or negedge mgmt_resetn) begin
        if (!mgmt_resetn) protocol_reset_sync <= 2'b11;
        else protocol_reset_sync <= {protocol_reset_sync[0], 1'b0};
      end
      // Elaborate the complete counter and CDC datapath only for lanes owned
      // by this target. As later milestones expand MANAGED_LANE_MASK, their
      // full engines appear automatically; an all-ones mask still builds the
      // original 112-engine architecture.
      all_links_v3_lane_engine #(
        .LANE_ID(lane),
        .USER_BITS_PER_CYCLE(USER_BITS_PER_CYCLE)
      ) u_lane (
        .config_epoch(config_lane_epoch[lane/4]), .lane_enable(config_lane_enabled[lane/4]), .config_ack(lane_epoch_ack[lane]),
        .start_req_toggle(start_req_toggle),
        .stop_req_toggle(stop_req_toggle),
        .descriptor_selected(descriptor_selected_to_lane[lane]),
        .descriptor_prbs_mode(descriptor_prbs_to_lane[lane*3 +: 3]),
        .measurement_enable(measurement_enable),
        .controls_enable(controls_enable),
        .start_ack_toggle(start_ack_toggle[lane]),
        .stop_ack_toggle(stop_ack_toggle[lane]),
        .snapshot_send(snapshot_send[lane]),
        .snapshot_rcv(snapshot_rcv[lane]),
        .rx_clk(rx_clk[lane]),
        .protocol_reset(protocol_reset_sync[1]),
        .rx_reset(rx_reset[lane]),
        .rx_prbs_locked(rx_prbs_locked[lane]),
        .rx_cdr_locked(rx_cdr_locked[lane]),
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

      assign snapshot_payload[lane*256 +: 256] = snapshot_received[lane*256 +: 256];
      if (ASYNC_SNAPSHOT_MASK[lane]) begin : g_snapshot_cdc
        // The lane holds src_in and src_send until the internal destination
        // handshake has atomically captured the complete result record.
        if (ALL_LINKS_V2_TIMING_HARDENING) begin : g_split_snapshot
          // Four equal handshakes reduce each destination capture-enable
          // fanout from 256 flops to 64.  The source payload is immutable
          // while snapshot_send is high, and the lane may acknowledge stop
          // only after all four chunks have returned src_rcv; therefore the
          // management domain cannot consume a mixed snapshot.
          wire [3:0] chunk_rcv;
          assign snapshot_rcv[lane] = &chunk_rcv;
          for (genvar chunk = 0; chunk < 4; chunk++) begin : g_chunk
            xpm_cdc_handshake #(
              .DEST_EXT_HSK(0), .DEST_SYNC_FF(2), .INIT_SYNC_FF(0),
              .SIM_ASSERT_CHK(SNAPSHOT_VENDOR_ASSERTIONS), .SRC_SYNC_FF(2), .WIDTH(64)
            ) u_snapshot_handshake (
              .src_clk(rx_clk[lane]),
              .src_in(snapshot_payload_raw[lane*256+chunk*64 +: 64]),
              .src_send(snapshot_send[lane]),
              .src_rcv(chunk_rcv[chunk]),
              .dest_clk(mgmt_clk),
              .dest_out(snapshot_received[lane*256+chunk*64 +: 64]),
              .dest_req(),
              .dest_ack(1'b0)
            );
          end
        end else begin : g_single_snapshot
          xpm_cdc_handshake #(
            .DEST_EXT_HSK(0), .DEST_SYNC_FF(2), .INIT_SYNC_FF(0),
            .SIM_ASSERT_CHK(1), .SRC_SYNC_FF(2), .WIDTH(256)
          ) u_snapshot_handshake (
            .src_clk(rx_clk[lane]),
            .src_in(snapshot_payload_raw[lane*256 +: 256]),
            .src_send(snapshot_send[lane]),
            .src_rcv(snapshot_rcv[lane]),
            .dest_clk(mgmt_clk),
            .dest_out(snapshot_received[lane*256 +: 256]),
            .dest_req(),
            .dest_ack(1'b0)
          );
        end
      end else begin : g_snapshot_same_clock
        assign snapshot_received[lane*256 +: 256] =
          snapshot_payload_raw[lane*256 +: 256];
        assign snapshot_rcv[lane] = snapshot_send[lane];
      end
    end else begin : g_unmanaged
      // The 112-lane ABI includes lanes still owned by IBERT, but the
      // descriptor mask makes them permanently unselectable in this build.
      // A combinational protocol stub preserves collective start/stop
      // acknowledgement and a deterministic unselected lane-ID record without
      // implementing unreachable counters or a high-fanout reset tree.
      localparam logic [31:0] UNMANAGED_STATUS = lane;
      assign lane_epoch_ack[lane] = config_epoch;
      assign start_ack_toggle[lane] = start_req_toggle;
      assign stop_ack_toggle[lane] = stop_req_toggle;
      assign snapshot_send[lane] = 1'b0;
      assign snapshot_rcv[lane] = 1'b0;
      assign snapshot_payload_raw[lane*256 +: 256] =
        {224'd0, UNMANAGED_STATUS};
      assign snapshot_payload[lane*256 +: 256] =
        {224'd0, UNMANAGED_STATUS};
      assign tx_prbs_select[lane*3 +: 3] = 3'd0;
      assign rx_prbs_select[lane*3 +: 3] = 3'd0;
      assign prbs_counter_reset[lane] = 1'b0;
      assign lane_running[lane] = 1'b0;
    end
  end

  wire [31:0] platform_failure_status =
    32'h0000_2800 | {24'd0, copy_lane};
  wire [255:0] platform_failure_record = {
    64'd0, 32'd1, 64'd0, 64'd0, platform_failure_status
  };
  wire copy_lane_exact_valid = exact_error_valid[copy_lane] && config_rx_lanes[copy_lane];
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
  // Snapshot selection is transferred atomically with the lane result. Do
  // not silently reduce the requested lane count when a lane captured stale
  // descriptor data. Reuse the existing failed-platform record/stop reason.
  wire copy_lane_mask_mismatch =
    measured_lane_record[11] != active_lane_mask[copy_lane];
  wire [255:0] copy_lane_record =
    // A physical-platform failure can remove the RX clocks needed for normal
    // lane acknowledgements.  In that case publish deterministic failed
    // records from mgmt_clk so the job still completes atomically.
    ((platform_failed_run || copy_lane_mask_mismatch) && active_lane_mask[copy_lane])
      ? platform_failure_record
      : measured_lane_record;
  wire [6:0] copy_lane_within_side = copy_lane >= 56 ? copy_lane - 56 : copy_lane;
  wire [1:0] copy_lane_bank = copy_lane_within_side < 12 ? 2'd0 :
                              copy_lane_within_side < 28 ? 2'd1 :
                              copy_lane_within_side < 44 ? 2'd2 : 2'd3;
  logic [1:0] copy_bank_stage = 0;
  wire [1023:0] copy_bank_record;
  wire [3:0] copy_bank_mismatch;
  wire copy_bank_load = state == ST_COPY && copy_phase == 0;
  wire copy_bank_capture = state == ST_COPY && copy_phase == 2;
  if (ALL_LINKS_V2_TIMING_HARDENING) begin : g_banked_result_copy
`define RESULT_COPY_BANK(NAME, P_FIRST, P_COUNT, P_INDEX) \
    (* KEEP_HIERARCHY = "yes" *) \
    eye_scan_v1_result_copy_bank #(.FIRST(P_FIRST), .COUNT(P_COUNT)) NAME ( \
      .clk(mgmt_clk), .load_selector(copy_bank_load), \
      .capture_record(copy_bank_capture), .global_lane(copy_lane), \
      .platform_failed(platform_failed_run), \
      .left_active(active_lane_mask[P_FIRST +: P_COUNT]), \
      .right_active(active_lane_mask[56+P_FIRST +: P_COUNT]), \
      .left_exact_valid(exact_error_valid[P_FIRST +: P_COUNT]), \
      .right_exact_valid(exact_error_valid[56+P_FIRST +: P_COUNT]), \
      .left_exact_saturated(exact_error_saturated[P_FIRST +: P_COUNT]), \
      .right_exact_saturated(exact_error_saturated[56+P_FIRST +: P_COUNT]), \
      .left_exact_counts(exact_error_counts[P_FIRST*32 +: P_COUNT*32]), \
      .right_exact_counts(exact_error_counts[(56+P_FIRST)*32 +: P_COUNT*32]), \
      .left_snapshot(snapshot_payload[P_FIRST*256 +: P_COUNT*256]), \
      .right_snapshot(snapshot_payload[(56+P_FIRST)*256 +: P_COUNT*256]), \
      .record_stage(copy_bank_record[P_INDEX*256 +: 256]), \
      .mismatch_stage(copy_bank_mismatch[P_INDEX]));
    `RESULT_COPY_BANK(u_result_copy_slr0, 0, 12, 0)
    `RESULT_COPY_BANK(u_result_copy_slr1, 12, 16, 1)
    `RESULT_COPY_BANK(u_result_copy_slr2, 28, 16, 2)
    `RESULT_COPY_BANK(u_result_copy_slr3, 44, 12, 3)
`undef RESULT_COPY_BANK
  end else begin : g_legacy_result_copy
    assign copy_bank_record = '0;
    assign copy_bank_mismatch = '0;
  end
  wire copy_stage_selected = copy_record_stage[11];
  wire copy_stage_passed = copy_stage_selected &&
                           copy_record_stage[12] &&
                           !copy_record_stage[13] &&
                           copy_record_stage[32 +: 64] == 0;

  always_comb begin
    // The native AXI register map includes debug controls and direct descriptor
    // access.  Addresses 0A0-0FC mirror the MCU-visible mailbox byte range.
    reg_read_data = 32'd0;
    case (reg_read_address)
      12'h000: reg_read_data = HARDWARE_ID;
      12'h004: reg_read_data = HARDWARE_VERSION;
      12'h008: reg_read_data = {LANES[7:0], 8'd28, 8'd12, 8'h3f};
      12'h00c: reg_read_data = 32'd0;
      12'h010: reg_read_data = {15'd0, effective_platform_fault, bad_command,
                                irq_pending, 10'd0, state} | (session_status << 17);
      12'h104: reg_read_data = session_status;
      12'h120: reg_read_data = {4'd0,config_tx_mask};
      12'h124: reg_read_data = {4'd0,config_rx_mask};
      12'h12c: reg_read_data = {config_record[224 +: 16],11'd0,config_record[192 +: 3],config_busy,config_usable};
      12'h108: reg_read_data = session_remaining_ms;
      12'h10c: reg_read_data = session_duration_ms;
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
      12'h03c: reg_read_data = diagnostic_page_selected
        ? 32'h0000_00fe : recovery_page_selected ? 32'hfd :
          trace_page_selected ? {22'd0, diagnostic_bank, trace_selector} : {24'd0, selected_result_lane};
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
      12'h084: reg_read_data = platform_diagnostics[31:0];
      12'h088: reg_read_data = platform_diagnostics[63:32];
      12'h08c: reg_read_data = platform_diagnostics[95:64];
      12'h090: reg_read_data = platform_diagnostics[127:96];
      12'h094: reg_read_data = platform_diagnostics[159:128];
      12'h098: reg_read_data = platform_diagnostics[191:160];
      12'h09c: reg_read_data = platform_diagnostics[223:192];
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
      12'h0cc: reg_read_data = diagnostic_page_selected
        ? 32'h0000_00fe : recovery_page_selected ? 32'hfd :
          trace_page_selected ? {22'd0, diagnostic_bank, trace_selector} : {24'd0, selected_result_lane};
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
  assign measurement_enable = measurement_active;
  // The start toggle changes exactly once for each accepted descriptor.  RX
  // diagnostics use it as a run epoch so only one completion can be published
  // for that descriptor, even if measurement_enable is disturbed later.
  assign measurement_run_toggle = start_req_toggle;
  assign controls_enable = state != ST_IDLE;
  assign acquisition_active = state == ST_ARM_WAIT;
  assign result_capture_request = state == ST_CAPTURE_WAIT;
  // These coarse status outputs are intended for board-level indicators.
  // Firmware-alive cannot assert until MicroBlaze has executed its AXI write
  // to the version mailbox, making the indication distinct from configuration
  // and fabric clock activity.
  assign status_firmware_alive = mailbox_firmware_version != 0;
  assign status_engine_busy = state != ST_IDLE;
  assign status_fault = bad_command ||
                        effective_platform_fault || session_expired ||
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
      diagnostic_page_selected <= 0;
      recovery_page_selected <= 0;
      recovery_snapshot <= 0;
      trace_page_selected <= 0;
      trace_selector <= 0;
      diagnostic_bank <= 0;
      active_lane_mask <= 0;
      active_prbs_mode <= 0;
      active_loopback_mode <= 0;
      start_req_toggle <= 0;
      stop_req_toggle <= 0;
      measurement_active <= 0;
      elapsed_cycles <= 0;
      millisecond_divider <= 0;
      run_id <= 0;
      stop_reason <= 0;
      irq_pending <= 0;
      bad_command <= 0;
      platform_failed_run <= 0;
      published_bank <= 0;
      copy_lane <= 0;
      copy_phase <= 0;
      copy_record_stage <= 0;
      copy_mask_mismatch_stage <= 0;
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
      // Additional diagnostic pages never overlap the 112 ordinary lanes.
      if ((reg_write && (reg_write_address == 12'h03c || reg_write_address == 12'h0cc)) ||
          (mailbox_i2c_write && mailbox_i2c_address == 8'hcc)) begin : select_trace
        logic [7:0] s;
        s = mailbox_i2c_write && mailbox_i2c_address == 8'hcc ?
            mailbox_i2c_write_data : reg_write_data[7:0];
        if ((s >= 8'h80 && s <= 8'hbf) || (s >= 8'hf5 && s <= 8'hfc)) begin
          trace_selector <= s; trace_page_selected <= 1;
          diagnostic_bank <= mailbox_i2c_write ? 0 : reg_write_data[9:8];
          diagnostic_page_selected <= 0; recovery_page_selected <= 0;
        end else if (s < LANES || s == 8'hfd || s == 8'hfe)
          trace_page_selected <= 0;
      end
      // MCU multibyte writes arrive CC then CD. Existing one-byte selector
      // writes reset the bank to zero; CD supplies the optional trace bank.
      if (mailbox_i2c_write && mailbox_i2c_address == 8'hcd && trace_page_selected)
        diagnostic_bank <= mailbox_i2c_write_data[1:0];
      start_ack_meta <= (start_ack_toggle & config_rx_lanes) | ({LANES{start_req_toggle}} & ~config_rx_lanes);
      start_ack_sync <= start_ack_meta;
      stop_ack_meta <= (stop_ack_toggle & config_rx_lanes) | ({LANES{stop_req_toggle}} & ~config_rx_lanes);
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
              measurement_active <= 0;
              state <= ST_STOP_WAIT;
            end
            if (reg_write_data[0]) begin
              // Validate the complete descriptor at the doorbell.  In
              // particular, hardware rejects every lane outside the target's
              // MANAGED_LANE_MASK even if software writes such a mask.
              if (!eye_lock && state == ST_IDLE && config_usable && !config_busy && platform_ready && !platform_fault &&
                  (!ENABLE_TX_SESSION ||
                   (descriptor_control[13:11] == 0 &&
                    (config_tx_mask == 0 || (tx_session_active && tx_session_ready)) &&
                    descriptor_control[10:8] == 5) ||
                   (descriptor_control[13:11] == 2 && !tx_session_active &&
                    (descriptor_lane_mask & ~config_tx_lanes) == 0)) &&
                  descriptor_control[7:0] == 8'h1 &&
                  descriptor_control[10:8] != 0 &&
                  descriptor_control[10:8] <= 5 &&
                  descriptor_duration != 0 &&
                  descriptor_lane_mask != 0 &&
                  (descriptor_lane_mask & ~MANAGED_LANE_MASK) == 0 &&
                  (descriptor_lane_mask & ~config_rx_lanes) == 0) begin
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
          12'h03c: if (reg_write_data[7:0] == 8'hfd) begin
            recovery_page_selected <= 1;
            diagnostic_page_selected <= 0;
            recovery_snapshot <= recovery_diagnostics;
          end else if (reg_write_data[7:0] == 8'hfe) begin
            diagnostic_page_selected <= 1;
            recovery_page_selected <= 0;
          end
          else if (reg_write_data[7:0] < LANES) begin
            selected_result_lane <= reg_write_data[7:0];
            diagnostic_page_selected <= 0;
            recovery_page_selected <= 0;
          end
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
          12'h0cc: if (reg_write_data[7:0] == 8'hfd) begin
            recovery_page_selected <= 1;
            diagnostic_page_selected <= 0;
            recovery_snapshot <= recovery_diagnostics;
          end else if (reg_write_data[7:0] == 8'hfe) begin
            diagnostic_page_selected <= 1;
            recovery_page_selected <= 0;
          end
          else if (reg_write_data[7:0] < LANES) begin
            selected_result_lane <= reg_write_data[7:0];
            diagnostic_page_selected <= 0;
            recovery_page_selected <= 0;
          end
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
          6'h33: if (mailbox_i2c_address[1:0] == 0) begin
            if (mailbox_i2c_write_data == 8'hfd) begin
              recovery_page_selected <= 1;
              diagnostic_page_selected <= 0;
              recovery_snapshot <= recovery_diagnostics;
            end else if (mailbox_i2c_write_data == 8'hfe) begin
              diagnostic_page_selected <= 1;
              recovery_page_selected <= 0;
            end
            else if (mailbox_i2c_write_data < LANES) begin
              selected_result_lane <= mailbox_i2c_write_data;
              diagnostic_page_selected <= 0;
              recovery_page_selected <= 0;
            end
          end
          default: ;
        endcase
      end

      case (state)
        ST_IDLE: ;

        ST_ARM_WAIT: begin
          // Every lane, including unselected lanes, acknowledges the start
          // toggle.  Physical acquisition additionally waits for the quad-local
          // reset/lock sequencer to declare its measurement window ready.
          if (effective_platform_fault) begin
            // A lost QPLL/user clock cannot be relied upon to return a lane
            // handshake. Publish deterministic failed records entirely in
            // the management domain so the job still terminates atomically.
            stop_reason <= 8'd4;
            platform_failed_run <= 1;
            copy_lane <= 0;
            copy_phase <= 0;
            state <= ST_COPY;
          end else if (start_ack_sync == {LANES{start_req_toggle}} &&
                       acquisition_ready) begin
            elapsed_cycles <= 0;
            measurement_active <= 1;
            state <= ST_RUN;
          end
        end

        ST_RUN: begin
          if (effective_platform_fault) begin
            stop_reason <= 8'd4;
            platform_failed_run <= 1;
            copy_lane <= 0;
            copy_phase <= 0;
            measurement_active <= 0;
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
              measurement_active <= 0;
              state <= ST_STOP_WAIT;
            end else if (elapsed_cycles + 1'b1 >= descriptor_duration) begin
              stop_reason <= 8'd1;
              stop_req_toggle <= ~stop_req_toggle;
              measurement_active <= 0;
              state <= ST_STOP_WAIT;
            end
          end else begin
            millisecond_divider <= millisecond_divider + 1'b1;
          end
        end

        ST_STOP_WAIT: begin
          // Lane stop acknowledgements are withheld until each 256-bit result
          // snapshot has completed its CDC handshake.
          if (effective_platform_fault) begin
            stop_reason <= 8'd4;
            platform_failed_run <= 1;
            copy_lane <= 0;
            copy_phase <= 0;
            state <= ST_COPY;
          end else if (stop_ack_sync == {LANES{stop_req_toggle}}) begin
            state <= ST_CAPTURE_WAIT;
          end
        end

        ST_CAPTURE_WAIT: begin
          if (effective_platform_fault) begin
            stop_reason <= 8'd4;
            platform_failed_run <= 1;
            copy_lane <= 0;
            copy_phase <= 0;
            state <= ST_COPY;
          end else if (result_capture_done) begin
            copy_lane <= 0;
            copy_phase <= 0;
            state <= ST_COPY;
          end
        end

        ST_COPY: begin
          if (ALL_LINKS_V2_TIMING_HARDENING) begin
            case (copy_phase)
              3'd0: begin
                // Register both the SLR bank and each bank-local selector.
                copy_bank_stage <= copy_lane_bank;
                copy_phase <= 3'd1;
              end
              3'd1: copy_phase <= 3'd2; // settle local 24/32-to-1 muxes
              3'd2: copy_phase <= 3'd3; // bank modules capture local records
              3'd3: copy_phase <= 3'd4; // settle registered SLR-bank outputs
              3'd4: begin
                // Only a four-to-one mux reaches the central staging bank.
                copy_record_stage <= copy_bank_record[copy_bank_stage*256 +: 256];
                copy_mask_mismatch_stage <= copy_bank_mismatch[copy_bank_stage];
                copy_phase <= 3'd5;
              end
              default: begin
                if (copy_mask_mismatch_stage)
                  stop_reason <= 8'd4;
                if (published_bank)
                  result_bank_0[copy_lane] <= copy_record_stage;
                else
                  result_bank_1[copy_lane] <= copy_record_stage;
                if (copy_stage_selected) begin
                  selected_count <= selected_count + 1'b1;
                  if (copy_stage_passed)
                    passed_count <= passed_count + 1'b1;
                  else
                    failed_count <= failed_count + 1'b1;
                end
                if (copy_lane == LANES-1)
                  state <= ST_PUBLISH;
                else begin
                  copy_lane <= copy_lane + 1'b1;
                  copy_phase <= 3'd0;
                end
              end
            endcase
          end else begin
            case (copy_phase)
              3'd0: begin
                // Deliberate settle interval for the new copy_lane selector.
                copy_phase <= 3'd1;
              end
              3'd1: begin
                copy_record_stage <= copy_lane_record;
                copy_mask_mismatch_stage <=
                  !platform_failed_run && copy_lane_mask_mismatch;
                copy_phase <= 3'd2;
              end
              default: begin
              if (copy_mask_mismatch_stage)
                stop_reason <= 8'd4;
              // Write only the hidden bank while accumulating the aggregate.
              // The currently published bank remains immutable for readers.
              if (published_bank)
                result_bank_0[copy_lane] <= copy_record_stage;
              else
                result_bank_1[copy_lane] <= copy_record_stage;
              if (copy_stage_selected) begin
                selected_count <= selected_count + 1'b1;
                if (copy_stage_passed)
                  passed_count <= passed_count + 1'b1;
                else
                  failed_count <= failed_count + 1'b1;
              end
              if (copy_lane == LANES-1)
                state <= ST_PUBLISH;
              else begin
                copy_lane <= copy_lane + 1'b1;
                copy_phase <= 2'd0;
              end
              end
            endcase
          end
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

        default: begin
          measurement_active <= 0;
          state <= ST_IDLE;
        end
      endcase
    end
  end
endmodule
