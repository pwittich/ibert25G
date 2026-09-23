`timescale 1ns/1ps

module tb_gt_runtime_integrity_monitor;
  logic clk = 0, resetn = 0, enable = 0, heartbeat = 0;
  logic heartbeat_running = 1;
  logic [3:0] selected = 4'hf, error_async = 0;
  wire fault, clock_fault;
  wire [3:0] error_fault_lanes, retained_error_lanes;
  wire [31:0] event_count, diagnostic_state;
  wire retained_clock_fault;

  always #2.5 clk = ~clk;
  always begin
    repeat (3) @(posedge clk);
    if (heartbeat_running) heartbeat <= ~heartbeat;
  end

  gt_runtime_integrity_monitor #(
    .ERROR_ASSERT_CYCLES(8), .ERROR_CLEAR_CYCLES(5),
    .HEARTBEAT_TIMEOUT_CYCLES(20), .HEARTBEAT_RECOVERY_EDGES(3)
  ) dut (
    .mgmt_clk(clk), .resetn(resetn), .monitor_enable(enable),
    .selected_lanes(selected), .rx_prbs_error_async(error_async),
    .rx_clock_heartbeat_async(heartbeat), .integrity_fault(fault),
    .error_fault_lanes(error_fault_lanes), .clock_fault(clock_fault),
    .event_count(event_count), .retained_error_lanes(retained_error_lanes),
    .retained_clock_fault(retained_clock_fault),
    .diagnostic_state(diagnostic_state)
  );

  initial begin
    repeat (4) @(posedge clk);
    resetn <= 1;
    enable <= 1;

    // The measured two-cycle transient must not assert the detector.
    repeat (5) @(posedge clk);
    error_async[0] <= 1;
    repeat (2) @(posedge clk);
    error_async[0] <= 0;
    repeat (12) @(posedge clk);
    if (fault || event_count != 0)
      $fatal(1, "short PRBS transient asserted integrity fault");

    // Sustained lane-local corruption asserts only that lane and records one
    // event.  Four clean cycles are insufficient; five clear the live fault.
    error_async[2] <= 1;
    wait (error_fault_lanes == 4'b0100);
    if (event_count != 1 || retained_error_lanes != 4'b0100)
      $fatal(1, "sustained PRBS event diagnostics are incorrect");
    error_async[2] <= 0;
    repeat (4) @(posedge clk);
    if (!fault) $fatal(1, "PRBS fault cleared before clean hysteresis");
    // Include the two management-clock synchronizer stages before the five
    // synchronized clean samples required by ERROR_CLEAR_CYCLES.
    repeat (5) @(posedge clk);
    if (fault) $fatal(1, "PRBS fault did not clear after clean hysteresis");

    // Stopping the common heartbeat is a distinct event.  It clears only
    // after the requested number of observed heartbeat edges.
    heartbeat_running <= 0;
    wait (clock_fault);
    if (event_count != 2 || !retained_clock_fault)
      $fatal(1, "missing-clock event diagnostics are incorrect");
    heartbeat_running <= 1;
    wait (!clock_fault);
    if (fault || event_count != 2 || retained_error_lanes != 4'b0100)
      $fatal(1, "clock recovery or retained evidence is incorrect");

    // Disabling monitoring clears live qualification but not retained data.
    enable <= 0;
    repeat (4) @(posedge clk);
    if (fault || event_count != 2 || diagnostic_state[9:6] != 4'b0100)
      $fatal(1, "disabled/retained monitor semantics are incorrect");

    $display("PASS: runtime integrity assertion, hysteresis, and retention");
    $finish;
  end

  initial begin
    repeat (1000) @(posedge clk);
    $fatal(1, "runtime-integrity testbench watchdog expired");
  end
endmodule
