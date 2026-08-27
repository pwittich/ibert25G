`timescale 1ns/1ps

module tb_gt_prbs_test_controller;
  logic clk = 0, resetn = 0;
  logic [3:0] running = 0, locked = 0;
  logic [2:0] requested_loopback = 0;
  logic capture_request = 0, wizard_rx_done = 1;
  logic [3:0] rx_done = 4'hf, pma_done = 4'hf;
  wire [2:0] applied_loopback;
  wire wizard_rx_reset, acquisition_ready, runtime_reset, idle, fault;
  wire [3:0] pma_reset, counter_reset;
  wire [4:0] diagnostic_state;
  wire [39:0] drpaddr;
  wire [3:0] drpclk, drpen, drpwe;
  wire [63:0] drpdi;
  logic [63:0] drpdo = 0;
  logic [3:0] drprdy = 0;
  wire capture_done;
  wire [127:0] exact_counts;
  wire [3:0] exact_valid, exact_saturated;
  integer runtime_reset_count = 0;

  always #2.5 clk = ~clk;

  gt_prbs_test_controller #(
    .SETTLE_CYCLES(3), .RESET_PULSE_CYCLES(3),
    .OPERATION_TIMEOUT_CYCLES(100)
  ) dut (.*,
    .mgmt_clk(clk), .lane_running_async(running),
    .rx_prbs_locked_async(locked),
    .result_capture_request(capture_request),
    .gtwiz_reset_rx_done_async(wizard_rx_done),
    .rxresetdone_async(rx_done), .rxpmaresetdone_async(pma_done),
    .gtwiz_reset_rx_datapath(wizard_rx_reset),
    .rxpmareset(pma_reset),
    .sequenced_prbs_counter_reset(counter_reset),
    .runtime_rx_reset_active(runtime_reset),
    .controller_idle(idle), .controller_fault(fault),
    .diagnostic_state(diagnostic_state),
    .result_capture_done(capture_done),
    .exact_error_counts(exact_counts),
    .exact_error_valid(exact_valid),
    .exact_error_saturated(exact_saturated)
  );

  always @(posedge clk) begin
    drprdy <= drpen;
    for (int lane = 0; lane < 4; lane++) begin
      if (drpen[lane]) begin
        if (drpaddr[lane*10 +: 10] == 10'h25e)
          drpdo[lane*16 +: 16] <= 16'h0100 + lane;
        else if (drpaddr[lane*10 +: 10] == 10'h25f)
          drpdo[lane*16 +: 16] <= 16'h0200 + lane;
        else
          $fatal(1, "unexpected DRP address");
      end
    end

    if (wizard_rx_reset) begin
      wizard_rx_done <= 0;
      rx_done <= 0;
      runtime_reset_count <= runtime_reset_count + 1;
    end else begin
      wizard_rx_done <= 1;
      rx_done <= 4'hf;
    end
    if (|pma_reset)
      pma_done <= pma_done & ~pma_reset;
    else
      pma_done <= 4'hf;
  end

  initial begin
    repeat (3) @(posedge clk);
    resetn <= 1;
    repeat (3) @(posedge clk);

    requested_loopback <= 3'b010;
    running <= 4'b0011;
    wait (wizard_rx_reset);
    if (applied_loopback != 0 || !runtime_reset)
      $fatal(1, "PMA loopback was applied before the required RX reset");
    wait (applied_loopback == 3'b010);
    if (!runtime_reset)
      $fatal(1, "RX recovery qualification ended before PMA reset");
    wait (|pma_reset);
    if (!runtime_reset)
      $fatal(1, "RX recovery qualification missing during PMA reset");
    wait (|counter_reset);
    if (!runtime_reset)
      $fatal(1, "RX recovery qualification ended before PRBS reacquisition");
    repeat (3) @(posedge clk);
    if (!runtime_reset || acquisition_ready)
      $fatal(1, "RX recovery qualification did not cover lock wait");
    locked <= 4'b0011;
    wait (acquisition_ready);
    if (fault || runtime_reset)
      $fatal(1, "PMA acquisition did not finish cleanly");

    running <= 0;
    repeat (5) @(posedge clk);
    capture_request <= 1;
    wait (capture_done);
    if (exact_valid != 4'b0011 || exact_saturated != 0)
      $fatal(1, "wrong exact-counter validity");
    if (exact_counts[31:0] != 32'h0200_0100 ||
        exact_counts[63:32] != 32'h0201_0101)
      $fatal(1, "wrong exact DRP counter assembly");
    capture_request <= 0;
    wait (wizard_rx_reset);
    wait (idle);

    runtime_reset_count = 0;
    requested_loopback <= 3'b000;
    running <= 4'b0100;
    wait (|counter_reset);
    if (runtime_reset)
      $fatal(1, "external-loopback lock wait masked RX status");
    locked <= 4'b0100;
    wait (acquisition_ready);
    if (runtime_reset_count != 0 || applied_loopback != 0)
      $fatal(1, "external-loopback acquisition performed a PMA RX reset");
    running <= 0;
    repeat (5) @(posedge clk);
    capture_request <= 1;
    wait (capture_done);
    capture_request <= 0;
    wait (idle);
    if (fault) $fatal(1, "external-loopback acquisition faulted");

    resetn <= 0;
    running <= 0;
    locked <= 0;
    repeat (3) @(posedge clk);
    resetn <= 1;
    repeat (3) @(posedge clk);
    requested_loopback <= 3'b000;
    running <= 4'b0001;
    wait (fault);
    if (diagnostic_state != 5'd8)
      $fatal(1, "lock timeout did not retain ST_LOCK_WAIT diagnostic");

    $display("PASS: PMA reset ordering, lock, DRP capture, cleanup, fault stage");
    $finish;
  end
endmodule
