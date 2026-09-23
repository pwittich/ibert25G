`timescale 1ns/1ps

// Final four-bank reduction.  The SLR banks retain the established local
// left-low/right-high packing and this unchanged stage retains global
// lowest-bank diagnostic priority and the all-four session barrier.
module all_links_v1_quad_aggregate (
  input wire clk, resetn,
  input wire [3:0] group_ready, group_fault, group_idle, group_acquire,
  input wire [3:0] group_capture, group_session_applied,
  input wire [31:0] group_reason,
  input wire [895:0] group_diagnostics,
  output logic quad_ready, quad_fault, controller_idle,
  output logic acquisition_ready, capture_done, tx_session_applied,
  output logic [7:0] fault_reason,
  output logic [223:0] diagnostics
);
  logic [7:0] reason_next;
  logic [223:0] diagnostics_next;
  integer g;
  always_comb begin
    reason_next = group_reason[7:0] | group_reason[15:8] |
                  group_reason[23:16] | group_reason[31:24];
    diagnostics_next = group_diagnostics[223:0];
    for (g = 3; g >= 0; g = g-1)
      if (group_fault[g]) diagnostics_next = group_diagnostics[g*224 +: 224];
  end
  always_ff @(posedge clk) begin
    if (!resetn) begin
      quad_ready <= 1'b0; quad_fault <= 1'b0; controller_idle <= 1'b0;
      acquisition_ready <= 1'b0; capture_done <= 1'b0;
      tx_session_applied <= 1'b0; fault_reason <= 8'd0; diagnostics <= 224'd0;
    end else begin
      quad_ready <= &group_ready; quad_fault <= |group_fault;
      controller_idle <= &group_idle; acquisition_ready <= &group_acquire;
      capture_done <= &group_capture;
      // This is the acknowledgement barrier: all 28 TX domains must report
      // the globally requested session before the engine may enter RUN.
      tx_session_applied <= &group_session_applied;
      fault_reason <= reason_next; diagnostics <= diagnostics_next;
    end
  end
endmodule
