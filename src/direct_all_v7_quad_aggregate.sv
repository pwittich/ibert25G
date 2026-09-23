`timescale 1ns/1ps

// One clock of intentional distribution latency keeps the engine's slowly
// changing, handshake-qualified controls local to each SLR. Every bank is
// clocked in parallel, so all fourteen quads observe each transition on the
// same management-clock edge.
module direct_all_v7_control_pipeline (
  input wire clk,
  input wire [6:0] controls_in,
  output logic [6:0] controls_out = 7'd0
);
  always_ff @(posedge clk)
    controls_out <= controls_in;
endmodule

module direct_all_v7_quad_group_aggregate #(
  parameter integer QUADS = 4
) (
  input wire clk, input wire resetn,
  input wire [QUADS-1:0] quad_ready_in, quad_fault_in,
  input wire [QUADS-1:0] controller_idle_in, acquisition_ready_in,
  input wire [QUADS-1:0] capture_done_in, tx_session_applied_in,
  input wire [QUADS*8-1:0] fault_reason_in,
  input wire [QUADS*224-1:0] diagnostics_in,
  output logic quad_ready, quad_fault, controller_idle,
  output logic acquisition_ready, capture_done, tx_session_applied,
  output logic [7:0] fault_reason,
  output logic [223:0] diagnostics
);
  logic ready_next, fault_next, idle_next, acquire_next, capture_next;
  logic session_applied_next;
  logic [7:0] reason_next;
  logic [223:0] diagnostics_next;
  integer q;
  always_comb begin
    ready_next = &quad_ready_in;
    fault_next = |quad_fault_in;
    idle_next = &controller_idle_in;
    acquire_next = &acquisition_ready_in;
    capture_next = &capture_done_in;
    session_applied_next = &tx_session_applied_in;
    reason_next = 8'd0;
    diagnostics_next = diagnostics_in[0 +: 224];
    for (q = QUADS-1; q >= 0; q = q-1) begin
      reason_next = reason_next | fault_reason_in[q*8 +: 8];
      if (quad_fault_in[q]) diagnostics_next = diagnostics_in[q*224 +: 224];
    end
  end
  always_ff @(posedge clk) begin
    if (!resetn) begin
      quad_ready <= 1'b0; quad_fault <= 1'b0; controller_idle <= 1'b0;
      acquisition_ready <= 1'b0; capture_done <= 1'b0;
      tx_session_applied <= 1'b0;
      fault_reason <= 8'd0; diagnostics <= 224'd0;
    end else begin
      quad_ready <= ready_next; quad_fault <= fault_next;
      controller_idle <= idle_next; acquisition_ready <= acquire_next;
      capture_done <= capture_next; tx_session_applied <= session_applied_next;
      fault_reason <= reason_next;
      diagnostics <= diagnostics_next;
    end
  end
endmodule

// The groups are the physical direct-GT ranges in SLR0/1/2/3: q221-q223,
// q224-q227, q228-q231, and q232-q234. Registering each local reduction and
// then the four-way global reduction breaks the impossible same-cycle route
// from a remote quad controller through session logic and back across SLRs.
module direct_all_v7_quad_aggregate (
  input wire clk, input wire resetn,
  input wire [13:0] quad_ready_in, quad_fault_in,
  input wire [13:0] controller_idle_in, acquisition_ready_in,
  input wire [13:0] capture_done_in, tx_session_applied_in,
  input wire [111:0] fault_reason_in,
  input wire [3135:0] diagnostics_in,
  output logic quad_ready, quad_fault, controller_idle,
  output logic acquisition_ready, capture_done, tx_session_applied,
  output logic [7:0] fault_reason,
  output logic [223:0] diagnostics
);
  wire [3:0] group_ready, group_fault, group_idle, group_acquire, group_capture;
  wire [3:0] group_session_applied;
  wire [31:0] group_reason;
  wire [895:0] group_diagnostics;

  (* KEEP_HIERARCHY = "yes" *)
  direct_all_v7_quad_group_aggregate #(.QUADS(3)) g_slr0 (
    .clk(clk), .resetn(resetn), .quad_ready_in(quad_ready_in[2:0]),
    .quad_fault_in(quad_fault_in[2:0]), .controller_idle_in(controller_idle_in[2:0]),
    .acquisition_ready_in(acquisition_ready_in[2:0]), .capture_done_in(capture_done_in[2:0]),
    .tx_session_applied_in(tx_session_applied_in[2:0]),
    .fault_reason_in(fault_reason_in[23:0]), .diagnostics_in(diagnostics_in[671:0]),
    .quad_ready(group_ready[0]), .quad_fault(group_fault[0]),
    .controller_idle(group_idle[0]), .acquisition_ready(group_acquire[0]),
    .capture_done(group_capture[0]), .tx_session_applied(group_session_applied[0]),
    .fault_reason(group_reason[7:0]),
    .diagnostics(group_diagnostics[223:0]));
  (* KEEP_HIERARCHY = "yes" *)
  direct_all_v7_quad_group_aggregate #(.QUADS(4)) g_slr1 (
    .clk(clk), .resetn(resetn), .quad_ready_in(quad_ready_in[6:3]),
    .quad_fault_in(quad_fault_in[6:3]), .controller_idle_in(controller_idle_in[6:3]),
    .acquisition_ready_in(acquisition_ready_in[6:3]), .capture_done_in(capture_done_in[6:3]),
    .tx_session_applied_in(tx_session_applied_in[6:3]),
    .fault_reason_in(fault_reason_in[55:24]), .diagnostics_in(diagnostics_in[1567:672]),
    .quad_ready(group_ready[1]), .quad_fault(group_fault[1]),
    .controller_idle(group_idle[1]), .acquisition_ready(group_acquire[1]),
    .capture_done(group_capture[1]), .tx_session_applied(group_session_applied[1]),
    .fault_reason(group_reason[15:8]),
    .diagnostics(group_diagnostics[447:224]));
  (* KEEP_HIERARCHY = "yes" *)
  direct_all_v7_quad_group_aggregate #(.QUADS(4)) g_slr2 (
    .clk(clk), .resetn(resetn), .quad_ready_in(quad_ready_in[10:7]),
    .quad_fault_in(quad_fault_in[10:7]), .controller_idle_in(controller_idle_in[10:7]),
    .acquisition_ready_in(acquisition_ready_in[10:7]), .capture_done_in(capture_done_in[10:7]),
    .tx_session_applied_in(tx_session_applied_in[10:7]),
    .fault_reason_in(fault_reason_in[87:56]), .diagnostics_in(diagnostics_in[2463:1568]),
    .quad_ready(group_ready[2]), .quad_fault(group_fault[2]),
    .controller_idle(group_idle[2]), .acquisition_ready(group_acquire[2]),
    .capture_done(group_capture[2]), .tx_session_applied(group_session_applied[2]),
    .fault_reason(group_reason[23:16]),
    .diagnostics(group_diagnostics[671:448]));
  (* KEEP_HIERARCHY = "yes" *)
  direct_all_v7_quad_group_aggregate #(.QUADS(3)) g_slr3 (
    .clk(clk), .resetn(resetn), .quad_ready_in(quad_ready_in[13:11]),
    .quad_fault_in(quad_fault_in[13:11]), .controller_idle_in(controller_idle_in[13:11]),
    .acquisition_ready_in(acquisition_ready_in[13:11]), .capture_done_in(capture_done_in[13:11]),
    .tx_session_applied_in(tx_session_applied_in[13:11]),
    .fault_reason_in(fault_reason_in[111:88]), .diagnostics_in(diagnostics_in[3135:2464]),
    .quad_ready(group_ready[3]), .quad_fault(group_fault[3]),
    .controller_idle(group_idle[3]), .acquisition_ready(group_acquire[3]),
    .capture_done(group_capture[3]), .tx_session_applied(group_session_applied[3]),
    .fault_reason(group_reason[31:24]),
    .diagnostics(group_diagnostics[895:672]));

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
      tx_session_applied <= 1'b0;
      fault_reason <= 8'd0; diagnostics <= 224'd0;
    end else begin
      quad_ready <= &group_ready; quad_fault <= |group_fault;
      controller_idle <= &group_idle; acquisition_ready <= &group_acquire;
      capture_done <= &group_capture;
      tx_session_applied <= &group_session_applied;
      fault_reason <= reason_next;
      diagnostics <= diagnostics_next;
    end
  end
endmodule
