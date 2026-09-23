`timescale 1ns/1ps

module tb_gt_prbs_runtime_integrity;
  logic clk = 0, resetn = 0, acquisition_active = 0;
  logic measurement_enable = 0, heartbeat = 0;
  logic [3:0] running = 0, locked = 0, rx_error = 0;
  wire acquisition_ready, controller_fault;
  wire [4:0] diagnostic_state;
  wire [255:0] recovery_diagnostics;

  always #2.5 clk = ~clk;
  always begin
    repeat (3) @(posedge clk);
    heartbeat <= ~heartbeat;
  end

  gt_prbs_test_controller #(
    .SETTLE_CYCLES(3), .RESET_PULSE_CYCLES(3),
    .RUNNING_MASK_SETTLE_CYCLES(3),
    .ERROR_FREE_QUALIFY_CYCLES(4),
    .STAGED_RX_ACQUISITION(1'b1),
    .REQUIRE_ERROR_FREE_QUALIFICATION(1'b0),
    .RUNTIME_INTEGRITY_DETECTOR(1'b1),
    .INTEGRITY_HEARTBEAT_TEST_HOOK(1'b1),
    .INTEGRITY_ERROR_ASSERT_CYCLES(8),
    .INTEGRITY_ERROR_CLEAR_CYCLES(5),
    .INTEGRITY_CLOCK_TIMEOUT_CYCLES(40),
    .OPERATION_TIMEOUT_CYCLES(100)
  ) dut (
    .mgmt_clk(clk), .resetn(resetn),
    .lane_running_async(running), .rx_prbs_locked_async(locked),
    .rx_prbs_error_async(rx_error), .requested_loopback(3'b000),
    .acquisition_active(acquisition_active),
    .measurement_enable(measurement_enable),
    .rx_clock_heartbeat_async(heartbeat),
    .result_capture_request(1'b0),
    .gtwiz_reset_rx_done_async(1'b1),
    .rxresetdone_async(4'hf), .rxpmaresetdone_async(4'hf),
    .quad_ready(1'b1), .acquisition_ready(acquisition_ready),
    .controller_fault(controller_fault),
    .diagnostic_state(diagnostic_state),
    .recovery_diagnostics(recovery_diagnostics),
    .drpdo(64'd0), .drprdy(4'd0)
  );

  initial begin
    repeat (4) @(posedge clk);
    resetn <= 1;
    acquisition_active <= 1;
    running <= 4'b0011;
    locked <= 4'b0011;
    wait (acquisition_ready);
    measurement_enable <= 1;
    acquisition_active <= 0;

    // The v271 hardware transient was two RX error-active cycles.  It must
    // remain below the candidate's sustained-corruption threshold.
    repeat (5) @(posedge clk);
    rx_error[0] <= 1;
    repeat (2) @(posedge clk);
    rx_error[0] <= 0;
    repeat (12) @(posedge clk);
    if (controller_fault || recovery_diagnostics[223:192] != 0)
      $fatal(1, "short error pulse caused a runtime-integrity fault");

    rx_error[1] <= 1;
    wait (controller_fault);
    if (diagnostic_state != 5'd27)
      $fatal(1, "runtime integrity did not retain its distinct fault stage");
    if (recovery_diagnostics[63:32] != 32'h0000_0007 ||
        recovery_diagnostics[223:192] != 1 ||
        recovery_diagnostics[233:230] != 4'b0010)
      $fatal(1, "runtime-integrity recovery diagnostics are incorrect");

    $display("PASS: controller runtime-integrity fault integration");
    $finish;
  end

  initial begin
    repeat (1000) @(posedge clk);
    $fatal(1, "controller runtime-integrity watchdog expired");
  end
endmodule
