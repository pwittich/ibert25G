`timescale 1ns/1ps

// Eye-image-only DRP lease for one quad. All ports use mgmt_clk, including
// GT DRPCLK. The existing pulse-based PRBS client has no backpressure, so it
// has priority until an idle, fully drained scan lease can be granted.
//
// The central coordinator must block BER/configuration before asserting
// scan_request, keep scan_eligible true through restoration, and drop request
// after grant. scan_release certifies that scan registers have been restored;
// it is deferred until both the DRP transaction and its response are drained.
// A timeout quarantines the port: a late DRPRDY cannot become another job's
// response. resetn must only clear with the corresponding GT DRP reset.
module eye_scan_drp_arbiter #(
  parameter integer DRP_TIMEOUT_CYCLES = 1024
) (
  input wire mgmt_clk, resetn,
  input wire prbs_idle, scan_eligible,
  input wire [39:0] prbs_addr,
  input wire [63:0] prbs_di,
  input wire [3:0] prbs_en, prbs_we,
  output wire [63:0] prbs_do,
  output wire [3:0] prbs_rdy,

  input wire scan_request,
  input wire [1:0] scan_lane,
  input wire scan_release,
  output wire scan_granted,
  output wire blocked,
  // Sticky: bit 0 PRBS access during lease, bit 1 eligibility lost during
  // lease, bit 2 scan DRP timeout. Bits 0/1 still permit scan restoration.
  output logic [2:0] fault = 0,
  input wire cmd_valid,
  output wire cmd_ready,
  input wire [9:0] cmd_addr,
  input wire [15:0] cmd_di,
  input wire cmd_we,
  output logic rsp_valid = 0,
  input wire rsp_ready,
  output logic [15:0] rsp_do = 0,
  output logic rsp_error = 0,

  output logic [39:0] gt_addr,
  output logic [63:0] gt_di,
  output logic [3:0] gt_en, gt_we,
  input wire [63:0] gt_do,
  input wire [3:0] gt_rdy
);
  localparam integer TIMER_WIDTH = DRP_TIMEOUT_CYCLES > 1 ?
    $clog2(DRP_TIMEOUT_CYCLES) : 1;
  localparam logic [1:0] NORMAL = 0, OWNED = 1, QUARANTINE = 2;
  (* fsm_encoding = "none" *) logic [1:0] state = NORMAL;
  logic [3:0] prbs_pending = 0;
  logic [1:0] lane = 0;
  logic inflight = 0, launch_pending = 0, release_pending = 0;
  logic [63:0] prbs_reply_data = 0;
  logic [3:0] prbs_reply_ready = 0;
  logic [9:0] addr_hold = 0;
  logic [15:0] di_hold = 0;
  logic we_hold = 0;
  logic [TIMER_WIDTH-1:0] timer = 0;

  assign scan_granted = resetn && state == OWNED;
  assign blocked = resetn && state != NORMAL;
  // Requests retain their no-backpressure passthrough. Replies gain one
  // registered cycle, breaking the GT-to-controller state/CE path.
  assign prbs_do = resetn && state == NORMAL ? prbs_reply_data : 64'd0;
  assign prbs_rdy = resetn && state == NORMAL ? prbs_reply_ready : 4'd0;
  assign cmd_ready = scan_granted && !fault[2] && !inflight &&
    !rsp_valid && !release_pending && !scan_release;

  always_comb begin
    gt_addr = 0; gt_di = 0; gt_en = 0; gt_we = 0;
    if (resetn && state == NORMAL) begin
      gt_addr = prbs_addr; gt_di = prbs_di;
      gt_en = prbs_en; gt_we = prbs_we;
    end else if (scan_granted && !fault[2]) begin
      // Keep the accepted bundle stable throughout DRP completion. EN is
      // exactly one clock; the client holds valid/data until ready.
      gt_addr[lane*10 +: 10] = inflight ? addr_hold : cmd_addr;
      gt_di[lane*16 +: 16] = inflight ? di_hold : cmd_di;
      gt_we[lane] = inflight ? we_hold : cmd_we;
      // Queue before launch: a lingering old RDY delays the actual GT pulse
      // without feeding combinationally into the point sequencer's ready.
      gt_en[lane] = launch_pending && !(|gt_rdy);
    end else if (resetn && state == QUARANTINE && fault[2]) begin
      // A timed-out GT operation may still complete later. Keep its accepted
      // bundle stable even in quarantine, with EN permanently low.
      gt_addr[lane*10 +: 10] = addr_hold;
      gt_di[lane*16 +: 16] = di_hold;
      gt_we[lane] = we_hold;
    end
  end

  always_ff @(posedge mgmt_clk) begin
    if (!resetn) begin
      state <= NORMAL; prbs_pending <= 0; lane <= 0;
      inflight <= 0; launch_pending <= 0; release_pending <= 0; timer <= 0;
      prbs_reply_data <= 0; prbs_reply_ready <= 0;
      addr_hold <= 0; di_hold <= 0; we_hold <= 0;
      rsp_valid <= 0; rsp_do <= 0; rsp_error <= 0; fault <= 0;
    end else begin
      prbs_reply_ready <= state == NORMAL ? gt_rdy : 4'd0;
      if (state == NORMAL && |gt_rdy) prbs_reply_data <= gt_do;
      if (rsp_valid && rsp_ready) rsp_valid <= 0;
      case (state)
        NORMAL: begin
          prbs_pending <= (prbs_pending | prbs_en) & ~gt_rdy;
          if (scan_request && scan_eligible && prbs_idle &&
              !(|prbs_pending) && !(|prbs_en) && !(|gt_rdy) && !(|prbs_reply_ready)) begin
            lane <= scan_lane;
            release_pending <= 0;
            state <= OWNED;
          end
        end
        OWNED: begin
          if (|prbs_en) fault[0] <= 1;
          if (!scan_eligible || !prbs_idle) fault[1] <= 1;
          if (scan_release) release_pending <= 1;
          if (cmd_valid && cmd_ready) begin
            addr_hold <= cmd_addr; di_hold <= cmd_di; we_hold <= cmd_we;
            inflight <= 1; launch_pending <= 1; timer <= 0;
          end else if (inflight) begin
            if (launch_pending && !(|gt_rdy)) begin
              launch_pending <= 0; timer <= 0;
            end else if (!launch_pending && gt_rdy[lane]) begin
              rsp_do <= gt_do[lane*16 +: 16];
              rsp_error <= 0; rsp_valid <= 1; inflight <= 0;
            end else if (timer == DRP_TIMEOUT_CYCLES-1) begin
              fault[2] <= 1; rsp_error <= 1; rsp_do <= 0;
              rsp_valid <= 1; inflight <= 0; launch_pending <= 0;
              state <= QUARANTINE;
            end else timer <= timer + 1'b1;
          end
          if ((release_pending || scan_release) && !scan_request &&
              !inflight && !rsp_valid && !(|gt_rdy)) begin
            release_pending <= 0;
            // Include current-cycle violations, before sticky bits update.
            if ((|fault) || (|prbs_en) || !scan_eligible || !prbs_idle)
              state <= QUARANTINE;
            else state <= NORMAL;
          end
        end
        QUARANTINE: begin
          // No retry, port reassignment or automatic GT reset. Response
          // backpressure is still honored for the failed transaction.
        end
        default: state <= QUARANTINE;
      endcase
    end
  end
endmodule
