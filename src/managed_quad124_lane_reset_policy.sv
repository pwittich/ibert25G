`timescale 1ns/1ps

// Reset the RX-clock-domain lane engines during initial GT bring-up and an
// acquisition-time quad recovery. A post-capture quad restart must preserve
// their toggle-handshake phase so the next command is not mistaken for an
// already acknowledged request.
module managed_quad124_lane_reset_policy (
  input  wire rx_clk,
  input  wire resetn,
  input  wire quad_ready,
  input  wire acquisition_active,
  output wire lane_rx_reset
);
  logic initial_quad_ready_seen = 0;
  (* ASYNC_REG = "TRUE" *) logic [1:0] ready_sync = 0;
  always_ff @(posedge rx_clk or negedge resetn) begin
    if (!resetn) begin
      ready_sync <= 0;
      initial_quad_ready_seen <= 0;
    end else begin
      ready_sync <= {ready_sync[0], quad_ready};
      if (ready_sync[1]) initial_quad_ready_seen <= 1;
    end
  end
  // Assertion must survive an absent RX clock, even if management completes
  // the restart before that clock returns. Release takes two RX edges.
  wire recovery_assert = !resetn || !initial_quad_ready_seen ||
                         (acquisition_active && !quad_ready);
  (* ASYNC_REG = "TRUE" *) logic [1:0] reset_pipe = 2'b11;
  always_ff @(posedge rx_clk or posedge recovery_assert) begin
    if (recovery_assert) reset_pipe <= 2'b11;
    else reset_pipe <= {reset_pipe[0], 1'b0};
  end
  assign lane_rx_reset = reset_pipe[1];
endmodule
