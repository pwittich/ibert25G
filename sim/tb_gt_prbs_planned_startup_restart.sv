`timescale 1ns/1ps

module tb_gt_prbs_planned_startup_restart;
  logic clk = 0, resetn = 0, acquisition_active = 0, quad_ready = 1;
  logic [3:0] running = 0, locked = 0, rx_error = 0, drp_ready = 0;
  logic capture_request = 0;
  wire [2:0] applied_loopback;
  wire wizard_rx_reset, rx_checker_enable, acquisition_ready;
  wire runtime_reset, quad_restart_request, controller_idle, controller_fault;
  wire [3:0] pma_reset, counter_reset;
  wire [4:0] diagnostic_state;
  wire [31:0] diagnostic_live, diagnostic_rx, diagnostic_counter;
  wire [255:0] recovery_diagnostics;
  wire [39:0] drpaddr;
  wire [3:0] drpclk, drpen, drpwe;
  wire [63:0] drpdi;
  wire capture_done;
  wire [127:0] exact_counts;
  wire [3:0] exact_valid, exact_saturated;
  integer restart_edges = 0;
  logic restart_previous = 0;

  always #2.5 clk = ~clk;
  always_ff @(posedge clk) begin
    drp_ready <= drpen;
    restart_previous <= quad_restart_request;
    if (!resetn) restart_edges <= 0;
    else if (quad_restart_request && !restart_previous)
      restart_edges <= restart_edges + 1;
  end

  gt_prbs_test_controller #(
    .SETTLE_CYCLES(3),
    .RESET_PULSE_CYCLES(3),
    .RUNNING_MASK_SETTLE_CYCLES(3),
    .ERROR_FREE_QUALIFY_CYCLES(6),
    .STAGED_RX_ACQUISITION(1'b1),
    .REQUIRE_ERROR_FREE_QUALIFICATION(1'b0),
    .EXTERNAL_QUAD_RECOVERY(1'b1),
    .EXTERNAL_STARTUP_QUAD_RESTART(1'b1),
    .POST_CAPTURE_QUAD_RESTART(1'b1),
    .EXTERNAL_LOCK_RECOVERY_CYCLES(12),
    .OPERATION_TIMEOUT_CYCLES(100)
  ) dut (
    .mgmt_clk(clk), .resetn(resetn),
    .lane_running_async(running), .rx_prbs_locked_async(locked),
    .rx_prbs_error_async(rx_error), .requested_loopback(3'b000),
    .acquisition_active(acquisition_active), .measurement_enable(1'b0),
    .rx_clock_heartbeat_async(1'b0),
    .result_capture_request(capture_request),
    .gtwiz_reset_rx_done_async(1'b1), .rxresetdone_async(4'hf),
    .rxpmaresetdone_async(4'hf), .quad_ready(quad_ready),
    .applied_loopback(applied_loopback),
    .gtwiz_reset_rx_datapath(wizard_rx_reset), .rxpmareset(pma_reset),
    .sequenced_prbs_counter_reset(counter_reset),
    .rx_checker_enable(rx_checker_enable),
    .acquisition_ready(acquisition_ready),
    .runtime_rx_reset_active(runtime_reset),
    .quad_restart_request(quad_restart_request),
    .controller_idle(controller_idle), .controller_fault(controller_fault),
    .diagnostic_state(diagnostic_state), .diagnostic_live(diagnostic_live),
    .diagnostic_rx(diagnostic_rx), .diagnostic_counter(diagnostic_counter),
    .recovery_diagnostics(recovery_diagnostics),
    .drpaddr(drpaddr), .drpclk(drpclk), .drpdi(drpdi), .drpen(drpen),
    .drpwe(drpwe), .drpdo(64'd0), .drprdy(drp_ready),
    .result_capture_done(capture_done), .exact_error_counts(exact_counts),
    .exact_error_valid(exact_valid),
    .exact_error_saturated(exact_saturated)
  );

  task automatic complete_restart(input logic expect_checker_setup);
    begin
      wait (diagnostic_state == 5'd23);
      @(negedge clk);
      if (!quad_restart_request || rx_checker_enable || wizard_rx_reset)
        $fatal(1, "planned restart controls are incorrect");
      quad_ready <= 0;
      wait (diagnostic_state == 5'd24);
      repeat (3) @(negedge clk);
      quad_ready <= 1;
      if (expect_checker_setup)
        wait (diagnostic_state == 5'd20);
      else
        wait (controller_idle);
    end
  endtask

  initial begin
    // A healthy post-restart checker must reach measurement after exactly one
    // cause-4 startup restart, then use the ordinary cause-3 cleanup restart.
    repeat (3) @(posedge clk);
    resetn <= 1;
    acquisition_active <= 1;
    running <= 4'hf;
    complete_restart(1'b1);
    if (restart_edges != 1 || recovery_diagnostics[135:128] != 8'd4)
      $fatal(1, "planned startup restart was not recorded as cause 4");
    locked <= 4'hf;
    rx_error <= 0;
    wait (acquisition_ready);
    if (controller_fault || recovery_diagnostics[95:64] != 32'd1 ||
        recovery_diagnostics[127:96] != 32'd1 ||
        recovery_diagnostics[191:160] != 32'd1)
      $fatal(1, "planned startup restart did not complete exactly once");
    acquisition_active <= 0;
    running <= 0;
    wait (diagnostic_state == 5'd11);
    capture_request <= 1;
    wait (capture_done);
    capture_request <= 0;
    complete_restart(1'b0);
    if (restart_edges != 2 || recovery_diagnostics[135:128] != 8'd3 ||
        recovery_diagnostics[95:64] != 32'd2 ||
        recovery_diagnostics[127:96] != 32'd2 ||
        recovery_diagnostics[191:160] != 32'd2)
      $fatal(1, "planned startup plus cleanup restart accounting failed");

    // Reset the diagnostic instance and prove that bad post-restart PRBS does
    // not consume another recovery. It must fault in state 25 after one reset.
    resetn <= 0;
    acquisition_active <= 0;
    running <= 0;
    locked <= 0;
    rx_error <= 0;
    quad_ready <= 1;
    repeat (4) @(posedge clk);
    resetn <= 1;
    acquisition_active <= 1;
    running <= 4'hf;
    complete_restart(1'b1);
    locked <= 4'hf;
    rx_error <= 4'hf;
    wait (diagnostic_state == 5'd25);
    wait (controller_fault);
    if (diagnostic_state != 5'd25 || restart_edges != 1 ||
        recovery_diagnostics[95:64] != 32'd1 ||
        recovery_diagnostics[135:128] != 8'd4)
      $fatal(1, "failed post-restart acquisition retried or lost evidence");

    $display("PASS: planned startup restart and conclusive failure policy");
    $finish;
  end

  initial begin
    repeat (2000) @(posedge clk);
    $fatal(1, "planned-startup-restart testbench watchdog expired");
  end
endmodule
