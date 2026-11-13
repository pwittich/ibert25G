`timescale 1ns/1ps

// Two real management-clock hops, with data and its tag kept together.
// Each hop has an ordinary one-cycle setup/hold requirement. The far SLR3
// return first lands in SLR2 before reaching the central SLR1 control plane.
module all_links_v3_return_pipeline #(parameter integer WIDTH=2) (
  input wire clk,
  input wire [WIDTH-1:0] data,
  (* KEEP = "TRUE" *) output logic [WIDTH-1:0] stage_two = 0
);
  (* KEEP = "TRUE" *) logic [WIDTH-1:0] stage_one = 0;
  always_ff @(posedge clk) begin
    stage_one <= data;
    stage_two <= stage_one;
  end
endmodule
