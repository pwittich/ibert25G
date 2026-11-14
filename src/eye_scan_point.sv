`timescale 1ns/1ps

// One statistical eye point on a GTYE4_CHANNEL with the inspected
// RX_DATA_WIDTH=80 / RX_INT_DATAWIDTH=2 / RXOUT_DIV=1 profile. All ports use
// mgmt_clk. UG578 v1.4 Tables 4-20/21 and C-2 define the register map.
//
// The caller supplies the actual equalizer mode and verified initialization
// profile, keeps the receiver/TX source healthy, and blocks BER/configuration
// atomically before start. This module never resets the GT or changes EQ.
// Results remain immutable until acknowledged. Fatal transport/restoration
// failures retain ownership; clearing resetn requires coordinated GT reset.
module eye_scan_point #(
  parameter integer BUS_TIMEOUT_CYCLES = 4096,
  parameter integer LEASE_TIMEOUT_CYCLES = 200000
) (
  input wire mgmt_clk, resetn,
  input wire start, cancel, permit, rx_healthy, profile_ok, lpm_mode,
  input wire [1:0] lane,
  input wire signed [10:0] horizontal,
  input wire signed [8:0] vertical,
  input wire [4:0] prescale,
  input wire [31:0] sample_timeout_cycles,
  output wire start_ready, busy,
  output logic result_valid = 0,
  input wire result_ready,
  // Sticky per job: bad descriptor/profile, cancel, health/policy loss,
  // sample timeout, DRP/policy fault, readback/invalid counters, preexisting scan,
  // restoration/release failure, respectively.
  output logic [7:0] result_status = 0,
  output logic cleanup_verified = 0,
  output logic fatal = 0,
  output logic [1:0] result_measurements = 0,
  output logic [15:0] errors0 = 0, samples0 = 0, errors1 = 0, samples1 = 0,
  output wire [63:0] bits0, bits1,
  output logic result_lpm = 1,
  output logic signed [10:0] result_horizontal = 0,
  output logic signed [8:0] result_vertical = 0,
  output logic [4:0] result_prescale = 0,
  output logic [1:0] result_vertical_range = 0,

  output wire scan_request,
  output logic [1:0] scan_lane = 0,
  output wire scan_release,
  input wire scan_granted,
  input wire [2:0] port_fault,
  output wire cmd_valid,
  input wire cmd_ready,
  output logic [9:0] cmd_addr,
  output logic [15:0] cmd_di,
  output logic cmd_we,
  input wire rsp_valid,
  output wire rsp_ready,
  input wire [15:0] rsp_do,
  input wire rsp_error
);
  localparam logic [4:0] IDLE=0, ACQUIRE=1, WITHDRAW=2, SAVE=3,
    CHECK_IDLE=4, CONFIG_WRITE=5, CONFIG_VERIFY=6, RUN_WRITE=7,
    RUN_VERIFY=8, POLL=9, READ_ERRORS=10, READ_SAMPLES=11,
    STOP_WRITE=12, STOP_VERIFY=13, WAIT_IDLE=14, RESTORE_WRITE=15,
    RESTORE_VERIFY=16, RELEASE=17, RELEASE_WAIT=18, RESULT=19, HALTED=20;
  (* fsm_encoding = "none" *) logic [4:0] state = IDLE;
  logic [15:0] saved [0:22];
  logic [4:0] index = 0;
  logic issued = 0, dirty = 0, cancelled = 0, ut = 0;
  logic measuring = 0, sample_expired = 0;
  logic [31:0] sample_age = 0, sample_limit = 0;
  logic [31:0] bus_age = 0, lease_age = 0, idle_age = 0;

  function automatic [9:0] saved_address(input logic [4:0] n);
    if (n == 0) saved_address = 10'h03c;
    else if (n == 1) saved_address = 10'h04f;
    else if (n == 2) saved_address = 10'h097;
    else if (n < 8) saved_address = 10'h044 + (n-3);
    else if (n < 13) saved_address = 10'h0ec + (n-8);
    else if (n < 18) saved_address = 10'h049 + (n-13);
    else saved_address = 10'h0f1 + (n-18);
  endfunction

  wire [15:0] control_stop = (saved[0] & 16'h00e0) |
    16'h0300 | {11'd0, result_prescale};
  wire [15:0] control_run = control_stop | 16'h0400;
  wire [8:0] magnitude = result_vertical < 0 ? -result_vertical : result_vertical;
  wire [15:0] vertical_word = (saved[2] & 16'hf803) |
    {5'd0, (result_vertical < 0), ut, magnitude[6:0], 2'd0};
  logic [15:0] configured;
  always_comb begin
    case (index)
      0: configured = control_stop;
      1: configured = {1'b1, result_horizontal[10:0], saved[1][3:0]};
      2: configured = vertical_word;
      default: configured = index < 13 || index >= 18 ? 16'hffff : 16'h0000;
    endcase
  end
  wire transaction = state == SAVE || state == CHECK_IDLE ||
    state == CONFIG_WRITE || state == CONFIG_VERIFY || state == RUN_WRITE ||
    state == RUN_VERIFY || state == POLL || state == READ_ERRORS ||
    state == READ_SAMPLES || state == STOP_WRITE || state == STOP_VERIFY ||
    state == WAIT_IDLE || state == RESTORE_WRITE || state == RESTORE_VERIFY;
  wire cleaning = state == STOP_WRITE || state == STOP_VERIFY ||
    state == WAIT_IDLE || state == RESTORE_WRITE || state == RESTORE_VERIFY ||
    state == RELEASE || state == RELEASE_WAIT;
  wire abort_job = cancelled || cancel || !permit || !rx_healthy ||
    (|port_fault) || sample_expired;
  assign start_ready = resetn && state == IDLE && !result_valid && !fatal && !(|port_fault);
  assign busy = state != IDLE && state != RESULT && state != HALTED;
  assign scan_request = resetn && state == ACQUIRE;
  assign scan_release = resetn && state == RELEASE;
  assign cmd_valid = resetn && transaction && !issued;
  // Also drain a late error response while halted; never reuse its data.
  assign rsp_ready = resetn && (issued || state == HALTED);
  // Use a six-bit shift count: prescale 31 means shift 32, not shift zero.
  wire [22:0] unscaled_bits0 = {1'b0,samples0,6'd0} + {3'd0,samples0,4'd0};
  wire [22:0] unscaled_bits1 = {1'b0,samples1,6'd0} + {3'd0,samples1,4'd0};
  assign bits0 = {41'd0,unscaled_bits0} << ({1'b0,result_prescale}+6'd1);
  assign bits1 = {41'd0,unscaled_bits1} << ({1'b0,result_prescale}+6'd1);

  always_comb begin
    cmd_addr = saved_address(index); cmd_di = configured; cmd_we = 0;
    case (state)
      CHECK_IDLE, POLL, WAIT_IDLE: cmd_addr = 10'h253;
      CONFIG_WRITE: cmd_we = 1;
      RUN_WRITE, RUN_VERIFY: begin
        cmd_addr = 10'h03c; cmd_di = control_run; cmd_we = state == RUN_WRITE;
      end
      STOP_WRITE, STOP_VERIFY: begin
        cmd_addr = 10'h03c; cmd_di = control_stop; cmd_we = state == STOP_WRITE;
      end
      READ_ERRORS: cmd_addr = 10'h251;
      READ_SAMPLES: cmd_addr = 10'h252;
      RESTORE_WRITE, RESTORE_VERIFY: begin
        cmd_di = saved[index]; cmd_we = state == RESTORE_WRITE;
      end
      default: ;
    endcase
  end

  // All normal paths after a possible write stop counting before restoring
  // offsets/masks. A read-only/preflight abort simply returns the lease.
  task automatic begin_cleanup;
    begin
      measuring <= 0; idle_age <= 0;
      if (dirty) state <= STOP_WRITE;
      else begin cleanup_verified <= 1; state <= RELEASE; end
    end
  endtask
  task automatic halt_transport;
    begin
      result_status[4] <= 1;
      if (dirty) result_status[7] <= 1;
      fatal <= 1; measuring <= 0; cleanup_verified <= 0;
      state <= HALTED; result_valid <= 1;
    end
  endtask

  always_ff @(posedge mgmt_clk) begin
    if (!resetn) begin
      state <= IDLE; index <= 0; issued <= 0; dirty <= 0;
      cancelled <= 0; ut <= 0; measuring <= 0; sample_expired <= 0;
      sample_age <= 0; sample_limit <= 0; bus_age <= 0; lease_age <= 0; idle_age <= 0;
      result_valid <= 0; result_status <= 0; cleanup_verified <= 0; fatal <= 0;
      result_measurements <= 0; errors0 <= 0; samples0 <= 0; errors1 <= 0; samples1 <= 0;
      result_lpm <= 1; result_horizontal <= 0; result_vertical <= 0; result_prescale <= 0;
      result_vertical_range <= 0;
      scan_lane <= 0;
    end else begin
      if (busy) begin
        if (cancel || cancelled) begin cancelled <= 1; result_status[1] <= 1; end
        if (!permit || !rx_healthy) result_status[2] <= 1;
        if (|port_fault) result_status[4] <= 1;
        if (sample_expired) result_status[3] <= 1;
      end
      // Keep the counter cleared before RUN acceptance. Only the registered
      // measuring flag fans out to its reset; command-ready drives one bit.
      if (!measuring) sample_age <= 0;
      else if (!sample_expired) begin
        if (sample_age >= sample_limit-1) sample_expired <= 1;
        else sample_age <= sample_age + 1'b1;
      end
      if (state == WAIT_IDLE) idle_age <= idle_age + 1'b1;
      if (transaction) begin
        bus_age <= bus_age + 1'b1;
        if (cmd_valid && cmd_ready) begin
          issued <= 1;
          if (cmd_we) dirty <= 1;
          if (state == RUN_WRITE) begin
            sample_expired <= 0; measuring <= 1;
          end
        end
      end else bus_age <= 0;

      case (state)
        IDLE: if (start && start_ready) begin
          result_status <= 0; cleanup_verified <= 0; result_measurements <= 0;
          errors0 <= 0; samples0 <= 0; errors1 <= 0; samples1 <= 0;
          result_lpm <= lpm_mode; result_horizontal <= horizontal;
          result_vertical <= vertical; result_prescale <= prescale;
          result_vertical_range <= 0;
          sample_limit <= sample_timeout_cycles; scan_lane <= lane;
          dirty <= 0; cancelled <= 0; ut <= 0; issued <= 0; sample_expired <= 0;
          index <= 0; lease_age <= 0; idle_age <= 0;
          if (cancel) begin
            result_status <= 2; cleanup_verified <= 1;
            result_valid <= 1; state <= RESULT;
          end else if (!permit || !rx_healthy || !profile_ok || sample_timeout_cycles == 0 ||
              horizontal < -32 || horizontal > 32 || vertical < -127 || vertical > 127) begin
            result_status <= 1; cleanup_verified <= 1;
            result_valid <= 1; state <= RESULT;
          end else state <= ACQUIRE;
        end
        ACQUIRE: begin
          lease_age <= lease_age + 1'b1;
          if (scan_granted) begin
            if (abort_job) begin_cleanup();
            else state <= SAVE;
          end else if (abort_job || lease_age == LEASE_TIMEOUT_CYCLES-1) begin
            if (!abort_job) result_status[4] <= 1;
            state <= WITHDRAW;
          end
        end
        // Allow a grant from the same edge that withdrew request to settle.
        WITHDRAW: begin
          cleanup_verified <= 1;
          if (scan_granted) state <= RELEASE;
          else begin result_valid <= 1; state <= RESULT; end
        end
        RELEASE: begin state <= RELEASE_WAIT; lease_age <= 0; end
        RELEASE_WAIT: begin
          lease_age <= lease_age + 1'b1;
          if (!scan_granted) begin result_valid <= 1; state <= RESULT; end
          else if (lease_age == BUS_TIMEOUT_CYCLES-1) begin
            result_status[7] <= 1; halt_transport();
          end
        end
        RESULT: if (result_ready) begin result_valid <= 0; state <= IDLE; end
        HALTED: if (result_ready) result_valid <= 0;
        default: ;
      endcase

      if (transaction && issued && rsp_valid) begin
        issued <= 0; bus_age <= 0;
        if (rsp_error) halt_transport();
        else if (!cleaning && abort_job) begin_cleanup();
        else case (state)
          SAVE: begin
            saved[index] <= rsp_do;
            if (index == 2) result_vertical_range <= rsp_do[1:0];
            if (index == 0 && (!rsp_do[8] || rsp_do[15:10] != 0)) begin
              result_status <= !rsp_do[8] ? 8'h01 : 8'h40;
              cleanup_verified <= 1; state <= RELEASE;
            end else if (index == 22) begin index <= 0; state <= CHECK_IDLE; end
            else index <= index + 1'b1;
          end
          CHECK_IDLE: begin
            if (rsp_do[3:0] != 4'h1) begin
              result_status[6] <= 1; cleanup_verified <= 1; state <= RELEASE;
            end else begin index <= 0; state <= CONFIG_WRITE; end
          end
          CONFIG_WRITE: state <= CONFIG_VERIFY;
          CONFIG_VERIFY: begin
            if (rsp_do != configured) begin result_status[5] <= 1; begin_cleanup(); end
            else if (index == 22) begin index <= 0; state <= RUN_WRITE; end
            else begin index <= index + 1'b1; state <= CONFIG_WRITE; end
          end
          RUN_WRITE: state <= RUN_VERIFY;
          RUN_VERIFY: begin
            if (rsp_do != control_run) begin result_status[5] <= 1; begin_cleanup(); end
            else state <= POLL;
          end
          POLL: if (rsp_do[3:0] == 4'h5) begin
            // DONE in WAIT (1) is not measurement completion. END is 5.
            measuring <= 0; state <= READ_ERRORS;
          end
          READ_ERRORS: begin
            if (ut) errors1 <= rsp_do; else errors0 <= rsp_do;
            state <= READ_SAMPLES;
          end
          READ_SAMPLES: begin
            if (ut) begin samples1 <= rsp_do; result_measurements[1] <= 1; end
            else begin samples0 <= rsp_do; result_measurements[0] <= 1; end
            if (rsp_do == 0) result_status[5] <= 1;
            idle_age <= 0; state <= STOP_WRITE;
          end
          STOP_WRITE: state <= STOP_VERIFY;
          STOP_VERIFY: begin
            if (rsp_do != control_stop) begin
              result_status[5] <= 1; result_status[7] <= 1;
              fatal <= 1; cleanup_verified <= 0; result_valid <= 1; state <= HALTED;
            end else state <= WAIT_IDLE;
          end
          WAIT_IDLE: if (rsp_do[3:0] == 4'h1) begin
            if (!result_lpm && !ut && !abort_job && result_status == 0) begin
              ut <= 1; index <= 2; state <= CONFIG_WRITE;
              // Reapplying the remaining masks is harmless and verified;
              // control/phase remain as configured for the first UT pass.
            end else begin index <= 1; state <= RESTORE_WRITE; end
          end
          RESTORE_WRITE: state <= RESTORE_VERIFY;
          RESTORE_VERIFY: begin
            if (rsp_do != saved[index]) begin
              result_status[5] <= 1; result_status[7] <= 1;
              fatal <= 1; cleanup_verified <= 0; result_valid <= 1; state <= HALTED;
            end else if (index == 0) begin cleanup_verified <= 1; state <= RELEASE; end
            else if (index == 22) begin index <= 0; state <= RESTORE_WRITE; end
            else begin index <= index + 1'b1; state <= RESTORE_WRITE; end
          end
          default: ;
        endcase
      end
      // No command may wait indefinitely, including a stuck ready signal,
      // stopped eye FSM, or failed restoration. No retry is hidden here.
      if ((transaction && bus_age >= BUS_TIMEOUT_CYCLES-1 &&
           !(issued && rsp_valid)) ||
          (state == WAIT_IDLE && idle_age >= BUS_TIMEOUT_CYCLES-1)) begin
        if (cleaning) result_status[7] <= 1;
        halt_transport();
      end
      if (busy && state != ACQUIRE && state != WITHDRAW &&
          state != RELEASE && state != RELEASE_WAIT &&
          (!scan_granted || port_fault[2])) halt_transport();
    end
  end
endmodule
