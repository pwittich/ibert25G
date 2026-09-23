`timescale 1ns/1ps

module tb_managed_quad124_lane_reset_policy;
  logic rx_clk = 0;
  logic quad_ready = 0;
  logic acquisition_active = 0;
  wire lane_rx_reset;

  always #1.5 rx_clk = ~rx_clk;

  managed_quad124_lane_reset_policy dut (
    .resetn(1'b1),
    .rx_clk(rx_clk),
    .quad_ready(quad_ready),
    .acquisition_active(acquisition_active),
    .lane_rx_reset(lane_rx_reset)
  );

  task automatic settle;
    repeat (8) @(posedge rx_clk);
    #0.1;
  endtask

  initial begin
    settle();
    if (!lane_rx_reset)
      $fatal(1, "lane reset was not held through initial bring-up");

    quad_ready = 1;
    settle();
    if (lane_rx_reset)
      $fatal(1, "lane reset did not release after initial readiness");

    // Acquisition recovery resets datapath controls; protocol phase is held
    // separately by the lane engine and the command must not be consumed again.
    acquisition_active = 1;
    quad_ready = 0;
    settle();
    if (!lane_rx_reset)
      $fatal(1, "acquisition restart did not reset lane engines");
    quad_ready = 1;
    settle();
    if (lane_rx_reset)
      $fatal(1, "acquisition restart did not release lane reset");

    // Post-capture recovery occurs outside acquisition and must retain the
    // start/stop toggle phase for the next command.
    acquisition_active = 0;
    settle();
    quad_ready = 0;
    settle();
    if (lane_rx_reset)
      $fatal(1, "post-capture restart reset lane-engine handshake phase");
    quad_ready = 1;
    settle();
    if (lane_rx_reset)
      $fatal(1, "post-capture restart left lane reset asserted");

    $display("PASS: acquisition-only lane-engine reset policy");
    $finish;
  end

  initial begin
    repeat (100) @(posedge rx_clk);
    $fatal(1, "lane-reset policy testbench watchdog expired");
  end
endmodule
