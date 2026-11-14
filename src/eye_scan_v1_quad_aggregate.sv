`timescale 1ns/1ps

// Eye-image-only registered bank status returns; historical modules remain unchanged.

// Final four-bank reduction.  The SLR banks retain the established local
// left-low/right-high packing and this unchanged stage retains global
// lowest-bank diagnostic priority and the all-four session barrier.
module eye_scan_v1_quad_aggregate (
  input wire clk, resetn, session_requested,
  input wire [1:0] session_tag,
  input wire [7:0] group_session_ack_tag,
  input wire [3:0] group_session_on_ack, group_session_off_ack,
  input wire [3:0] group_config_idle,
  output logic config_idle = 0,
  input wire [3:0] group_ready, group_fault, group_idle, group_acquire,
  input wire [3:0] group_capture, group_session_applied,
  input wire [31:0] group_reason,
  input wire [895:0] group_diagnostics,
  output logic quad_ready, quad_fault, controller_idle,
  output logic acquisition_ready, capture_done,
  output wire tx_session_applied,
  output logic [7:0] fault_reason,
  output logic [223:0] diagnostics
);
  logic [7:0] reason_next;
  logic [1:0] acknowledged_tag = 0, acknowledged_tag_guard = 0;
  logic on_complete = 0, off_complete = 0;
  wire [3:0] tags_match;
  wire [15:0] session_return;
  `define SESSION_RETURN(NAME,IDX) \
  (* KEEP_HIERARCHY = "yes" *) all_links_v3_return_pipeline #(.WIDTH(4)) NAME ( \
    .clk(clk), .data({group_session_ack_tag[IDX*2+:2],group_session_on_ack[IDX],group_session_off_ack[IDX]}), \
    .stage_two(session_return[IDX*4+:4]));
  `SESSION_RETURN(u_session_return_slr0,0)
  `SESSION_RETURN(u_session_return_slr1,1)
  `SESSION_RETURN(u_session_return_slr2,2)
  `SESSION_RETURN(u_session_return_slr3,3)
`undef SESSION_RETURN
  for(genvar s=0;s<4;s++) assign tags_match[s] = session_return[s*4+2 +: 2] == session_tag;
  always_ff @(posedge clk) begin
    config_idle <= resetn && (&group_config_idle);
    acknowledged_tag <= session_tag;
    acknowledged_tag_guard <= acknowledged_tag;
    on_complete <= resetn && (&tags_match) && (session_return[1] && session_return[5] && session_return[9] && session_return[13]);
    off_complete <= resetn && (&tags_match) && (session_return[0] && session_return[4] && session_return[8] && session_return[12]);
  end
  assign tx_session_applied = session_requested
    ? (acknowledged_tag == session_tag && acknowledged_tag_guard == session_tag && on_complete)
    : !(acknowledged_tag == session_tag && acknowledged_tag_guard == session_tag && off_complete);
  // Match status, reason and diagnostic latency across each physical bank.
  // Fault publication can never precede its diagnostic payload. The existing
  // tagged TX-session return above retains its exact independent handshake.
  wire [947:0] status_return;
  wire [3:0] ready_local, fault_local, idle_local, acquire_local, capture_local;
  wire [31:0] reason_local;
  wire [895:0] diagnostics_local;
  for (genvar s=0;s<4;s++) begin:g_status_return
    (* KEEP_HIERARCHY = "yes" *) all_links_v3_return_pipeline #(.WIDTH(237)) u_return (
      .clk(clk), .data({group_diagnostics[s*224+:224],group_reason[s*8+:8],
        group_capture[s],group_acquire[s],group_idle[s],group_fault[s],group_ready[s]}),
      .stage_two(status_return[s*237+:237]));
    assign {diagnostics_local[s*224+:224],reason_local[s*8+:8],capture_local[s],
      acquire_local[s],idle_local[s],fault_local[s],ready_local[s]} = status_return[s*237+:237];
  end
  logic [223:0] diagnostics_next;
  integer g;
  always_comb begin
    reason_next = reason_local[7:0] | reason_local[15:8] |
                  reason_local[23:16] | reason_local[31:24];
    diagnostics_next = diagnostics_local[223:0];
    for (g = 3; g >= 0; g = g-1)
      if (fault_local[g]) diagnostics_next = diagnostics_local[g*224 +: 224];
  end
  always_ff @(posedge clk) begin
    if (!resetn) begin
      quad_ready <= 1'b0; quad_fault <= 1'b0; controller_idle <= 1'b0;
      acquisition_ready <= 1'b0; capture_done <= 1'b0;
      fault_reason <= 8'd0; diagnostics <= 224'd0;
    end else begin
      quad_ready <= &ready_local; quad_fault <= |fault_local;
      controller_idle <= &idle_local; acquisition_ready <= &acquire_local;
      capture_done <= &capture_local;
      // This is the acknowledgement barrier: all 28 TX domains must report
      // the globally requested session before the engine may enter RUN.
      fault_reason <= reason_next; diagnostics <= diagnostics_next;
    end
  end
endmodule
