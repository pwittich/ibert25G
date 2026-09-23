`timescale 1ns/1ps

// Selection-aware platform contract for a native all-link GT fabric.
//
// Global lanes are deliberately allocated as consecutive four-lane quads:
// 0-55 map to quads 121-134 and 56-111 map to quads 221-234.  Therefore the
// logical quad index is lane/4.  The current engine accepts scalar platform
// ready/fault inputs; the native target must instead accept selected lanes only
// when their quads are ready and fail a RUN only for an active-quad fault.
// This standalone combinational block establishes that contract without
// changing v15 or any historical target.
module gt_native_active_quad_contract #(
  parameter int unsigned LANES = 112,
  parameter int unsigned QUADS = 28
) (
  input  wire [LANES-1:0] selected_lanes,
  input  wire [QUADS-1:0] quad_ready,
  input  wire [QUADS-1:0] quad_fault,
  output logic [QUADS-1:0] active_quads,
  output logic             selected_lanes_ready,
  output logic             active_quad_fault
);
  initial begin
    if (LANES != QUADS * 4)
      $error("native active-quad contract requires four lanes per quad");
  end

  always_comb begin
    active_quads = '0;
    for (int lane = 0; lane < LANES; lane++)
      if (selected_lanes[lane]) active_quads[lane / 4] = 1'b1;
    selected_lanes_ready = (active_quads != '0) &&
      ((active_quads & ~quad_ready) == '0);
    active_quad_fault = |(active_quads & quad_fault);
  end
endmodule
