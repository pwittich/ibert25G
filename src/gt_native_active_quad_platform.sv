`timescale 1ns/1ps

// Native all-link adapter for the scalar platform interface already consumed
// by gt_test_engine_core.  A later all-link target supplies its frozen
// descriptor/active lane mask here; this block makes only selected quads
// participate in ready, fault, idle, and restart decisions.
module gt_native_active_quad_platform #(
  parameter int unsigned LANES = 112,
  parameter int unsigned QUADS = 28
) (
  input  wire [LANES-1:0] selected_lanes,
  input  wire [QUADS-1:0] quad_ready,
  input  wire [QUADS-1:0] quad_idle,
  input  wire [QUADS-1:0] quad_fault,
  input  wire              quad_restart_request,
  output wire [QUADS-1:0] active_quads,
  output wire              platform_ready,
  output wire              platform_fault,
  output wire [QUADS-1:0] active_quad_restart
);
  wire selected_lanes_ready;
  wire active_quad_fault;

  gt_native_active_quad_contract #(.LANES(LANES), .QUADS(QUADS)) u_contract (
    .selected_lanes(selected_lanes), .quad_ready(quad_ready),
    .quad_fault(quad_fault), .active_quads(active_quads),
    .selected_lanes_ready(selected_lanes_ready),
    .active_quad_fault(active_quad_fault)
  );

  assign platform_ready = selected_lanes_ready &&
    ((active_quads & ~quad_idle) == '0);
  assign platform_fault = active_quad_fault;
  assign active_quad_restart = active_quads & {QUADS{quad_restart_request}};
endmodule
