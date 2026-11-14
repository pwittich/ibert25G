`timescale 1ns/1ps

// One global scan, one receiver, up to 4096 immutable 256-bit point records.
// A point is executed locally in the selected quad; all transport is in the
// management clock domain. Descriptor payload settles before phase changes.
module eye_scan_controller #(
  parameter integer CYCLES_PER_MS = 200000,
  parameter integer MAX_POINTS = 4096,
  parameter integer PRELOAD_CYCLES = 16
) (
  input wire clk, resetn,
  input wire write,
  input wire [11:0] address, read_address,
  input wire [31:0] data,
  input wire [3:0] strobe,
  output logic [31:0] read_data,
  input wire eligible, local_tx_required,
  input wire [31:0] local_session_remaining_ms,
  input wire [27:0] rx_mask,
  input wire link_fatal,
  input wire [255:0] point_packet,
  output wire [68:0] controls,
  output wire lock,
  output logic fatal = 0,
  output wire [255:0] progress_record,
  output wire [255:0] page_record
);
  localparam logic [3:0] IDLE=0, VALIDATE=1, PRELOAD=2, WAIT_POINT=3,
    STORE=4, ACK=5, DRAIN=6, NEXT=7, FINISH=8;
  (* fsm_encoding = "none" *) logic [3:0] state = IDLE;
  logic [31:0] shadow_h=0,shadow_v=0,shadow_p=0,shadow_budget=0,shadow_timeout=0;
  logic [31:0] accepted_h=0,accepted_v=0,point_timeout=0;
  logic [31:0] job_id=0, remaining_ms=0, ms_divider=0;
  logic [15:0] reason=0;
  logic available=0,rejected=0,cancelled=0,phase=0,point_ack=0;
  logic [6:0] lane=0;
  logic signed [10:0] h=0, h_first=0, h_last=0;
  logic signed [8:0] v=0, v_first=0, v_last=0;
  logic [5:0] h_step=0;
  logic [7:0] v_step=0;
  logic [4:0] prescale=0;
  logic [12:0] count=0,planned=0;
  logic [11:0] page=0;
  logic [7:0] settle=0;
  logic [31:0] drain_age=0;
  (* ram_style = "block" *) logic [255:0] matrix [0:MAX_POINTS-1];
  logic [255:0] page_stage=0;
  logic page_valid=0;
  wire busy = state != IDLE;
  assign lock = busy || fatal;
  wire [31:0] status_word = {reason,8'd0,state,rejected,fatal,available,busy};
  assign progress_record = {{20'd0,page},remaining_ms,accepted_v,accepted_h,
    {19'd0,count},status_word,job_id,32'h45595001};
  assign page_record = page_valid ? page_stage : 256'd0;
  // [68] LPM, [67] permission, [66] cancel, [65] result ACK, [64] phase.
  assign controls = {1'b1,busy && !fatal && eligible,cancelled || fatal,
    point_ack,phase,point_timeout,prescale,v,h,lane};
  wire signed [11:0] next_h = $signed(h) + $signed({1'b0,h_step});
  wire signed [10:0] next_v = $signed(v) + $signed({1'b0,v_step});
  wire grid_end = next_h > $signed(h_last) && next_v > $signed(v_last);
  wire [6:0] request_lane = shadow_h[6:0];
  wire signed [6:0] request_h_first = shadow_h[13:7], request_h_last = shadow_h[20:14];
  wire signed [7:0] request_v_first = shadow_v[7:0], request_v_last = shadow_v[15:8];
  wire descriptor_valid = shadow_h[31:27] == 0 && request_lane < 112 &&
    request_h_first >= -32 && request_h_last <= 32 && request_h_first <= request_h_last &&
    shadow_h[26:21] != 0 && shadow_h[26:21] <= 32 && shadow_v[31:24] == 0 &&
    request_v_first >= -127 && request_v_last <= 127 && request_v_first <= request_v_last &&
    shadow_v[23:16] != 0 && shadow_v[23:16] <= 127 && shadow_p < 32 &&
    shadow_timeout != 0 && shadow_budget > 10 && shadow_budget <= 86400000;
  wire tx_budget_valid = !local_tx_required ||
    (local_session_remaining_ms > 10 && shadow_budget <= local_session_remaining_ms-10);
  wire packet_valid = point_packet[0];
  wire packet_matches = point_packet[1] == phase && point_packet[26:20] == lane;
  wire packet_failed = point_packet[13:6] != 0 || !point_packet[3] ||
    point_packet[2] || point_packet[5:4] != 1;

  always_comb begin
    case (read_address)
      12'h140: read_data=shadow_h;
      12'h144: read_data=shadow_v;
      12'h148: read_data=shadow_p;
      12'h14c: read_data=shadow_budget;
      12'h150: read_data=shadow_timeout;
      12'h158: read_data=status_word;
      12'h15c: read_data={20'd0,page};
      12'h160: read_data={19'd0,count};
      12'h164: read_data=job_id;
      12'h168: read_data={19'd0,planned};
      default: read_data=0;
    endcase
  end
  always_ff @(posedge clk) begin
    // No matrix reset: stale BRAM words are hidden by count/page_valid.
    page_stage <= matrix[page];
    page_valid <= page < count;
    if (!resetn) begin
      state<=IDLE; shadow_h<=0; shadow_v<=0; shadow_p<=0; shadow_budget<=0; shadow_timeout<=0;
      accepted_h<=0; accepted_v<=0; point_timeout<=0; job_id<=0; remaining_ms<=0; ms_divider<=0;
      reason<=0; available<=0; rejected<=0; cancelled<=0; phase<=0; point_ack<=0; fatal<=0;
      lane<=0; h<=0; h_first<=0; h_last<=0; v<=0; v_first<=0; v_last<=0;
      h_step<=0; v_step<=0; prescale<=0; count<=0; planned<=0; page<=0;
      settle<=0; drain_age<=0; page_valid<=0;
    end else begin
      if (busy) begin
        if (ms_divider == CYCLES_PER_MS-1) begin
          ms_divider<=0;
          if (remaining_ms != 0) remaining_ms<=remaining_ms-1'b1;
        end else ms_divider<=ms_divider+1'b1;
        if (!eligible) begin cancelled<=1; reason[2]<=1; end
        if (remaining_ms <= 10) begin cancelled<=1; reason[3]<=1; end
        if (link_fatal) begin cancelled<=1; fatal<=1; reason[5]<=1; end
        if (remaining_ms == 0 && state != FINISH) begin
          fatal<=1; reason[7]<=1; state<=FINISH;
        end
      end
      case (state)
        VALIDATE: begin
          if (cancelled || !eligible || link_fatal || remaining_ms<=10) state<=FINISH;
          else if (grid_end) begin h<=h_first; v<=v_first; settle<=0; state<=PRELOAD; end
          else if (planned >= MAX_POINTS) begin reason[0]<=1; state<=FINISH; end
          else begin
            planned<=planned+1'b1;
            if (next_h > $signed(h_last)) begin h<=h_first; v<=next_v[8:0]; end
            else h<=next_h[10:0];
          end
        end
        PRELOAD: begin
          if (cancelled || !eligible || link_fatal || remaining_ms<=10) state<=FINISH;
          else if (settle == PRELOAD_CYCLES-1) begin
            if (packet_valid) begin fatal<=1; reason[7]<=1; state<=FINISH; end
            else begin phase<=~phase; state<=WAIT_POINT; end
          end else settle<=settle+1'b1;
        end
        WAIT_POINT: if (packet_valid) begin
          if (!packet_matches) begin fatal<=1; reason[7]<=1; state<=FINISH; end
          else state<=STORE;
        end
        STORE: begin
          if (count >= MAX_POINTS) begin fatal<=1; reason[6]<=1; state<=FINISH; end
          else begin
            matrix[count[11:0]] <= {point_packet[191:0],job_id,32'h45594401};
            count<=count+1'b1;
            if (packet_failed) begin
              reason[4]<=1; reason[15:8]<=point_packet[13:6]; cancelled<=1;
            end
            if (point_packet[2] || !point_packet[3]) begin fatal<=1; state<=FINISH; end
            else begin point_ack<=1; drain_age<=0; state<=ACK; end
          end
        end
        ACK: begin
          drain_age<=drain_age+1'b1;
          if (!packet_valid) begin point_ack<=0; settle<=0; state<=DRAIN; end
          else if (drain_age >= CYCLES_PER_MS-1) begin
            fatal<=1; reason[7]<=1; state<=FINISH;
          end
        end
        DRAIN: if (settle == PRELOAD_CYCLES-1) state<=NEXT;
          else settle<=settle+1'b1;
        NEXT: begin
          if (cancelled || fatal || !eligible || grid_end || remaining_ms<=10) state<=FINISH;
          else begin
            if (next_h > $signed(h_last)) begin h<=h_first; v<=next_v[8:0]; end
            else h<=next_h[10:0];
            settle<=0; state<=PRELOAD;
          end
        end
        FINISH: begin available<=1; state<=IDLE; point_ack<=0; end
        default: ;
      endcase
      // This override is deliberately after the phase FSM: deadline expiry
      // cannot be overwritten by a same-edge point result or validation step.
      if (busy && remaining_ms == 0 && state != FINISH) begin
        fatal<=1; reason[7]<=1; cancelled<=1; state<=FINISH;
      end
      if (write && address >= 12'h140 && address <= 12'h168) begin
        if (strobe != 4'hf) rejected<=1;
        else case (address)
          12'h140,12'h144,12'h148,12'h14c,12'h150: begin
            if (busy || available || fatal) rejected<=1;
            else case(address)
              12'h140:shadow_h<=data;
              12'h144:shadow_v<=data;
              12'h148:shadow_p<=data;
              12'h14c:shadow_budget<=data;
              12'h150:shadow_timeout<=data;
              default: ;
            endcase
          end
          12'h15c: if (data < count) page<=data[11:0]; else rejected<=1;
          12'h154: case(data)
            1: if (!busy && !available && !fatal && eligible && descriptor_valid &&
                   tx_budget_valid && rx_mask[request_lane[6:2]]) begin
              lane<=request_lane; h_first<=request_h_first; h_last<=request_h_last;
              h<=request_h_first; v_first<=request_v_first; v_last<=request_v_last; v<=request_v_first;
              h_step<=shadow_h[26:21]; v_step<=shadow_v[23:16]; prescale<=shadow_p[4:0];
              point_timeout<=shadow_timeout; accepted_h<=shadow_h; accepted_v<=shadow_v;
              remaining_ms<=shadow_budget; ms_divider<=0; job_id<=job_id+1'b1;
              count<=0; planned<=1; reason<=0; cancelled<=0; rejected<=0;
              point_ack<=0; page<=0; state<=VALIDATE;
            end else rejected<=1;
            2: if (busy) begin cancelled<=1; reason[1]<=1; end else rejected<=1;
            4: if (!busy && available) begin available<=0; count<=0; end else rejected<=1;
            default: rejected<=1;
          endcase
          default: rejected<=1;
        endcase
      end
    end
  end
endmodule
