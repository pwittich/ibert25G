`timescale 1ns/1ps

// Interface shell for the first shared-refclk native proof: q221-223.
//
// These are global lanes 56-67 and logical quad bits 14-16.  The checked-in
// IBERT wrapper routes MGTREFCLK0_222 south to q221, locally to q222, and
// north to q223 for both channel and common inputs.  A later generated native
// GT group must connect here; this shell intentionally contains no GT Wizard
// instance and therefore cannot accidentally be used as a bitstream target.
module gt_native_right221_223_shell (
  input  wire [111:0] selected_lanes,
  input  wire [27:0]  quad_ready,
  input  wire [27:0]  quad_fault,
  output wire [27:0]  active_quads,
  output wire         selected_lanes_ready,
  output wire         active_quad_fault,
  output wire [11:0]  proof_selected_lanes,
  output wire [2:0]   proof_active_quads
);
  gt_native_active_quad_contract #(.LANES(112), .QUADS(28)) u_contract (
    .selected_lanes(selected_lanes), .quad_ready(quad_ready),
    .quad_fault(quad_fault), .active_quads(active_quads),
    .selected_lanes_ready(selected_lanes_ready),
    .active_quad_fault(active_quad_fault)
  );

  assign proof_selected_lanes = selected_lanes[56 +: 12];
  assign proof_active_quads = active_quads[14 +: 3];
endmodule
