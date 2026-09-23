`timescale 1ns/1ps

module tb_gt_prbs_test_controller_fixed;
  wire [255:0] recovery_diagnostics;
  logic clk = 0, resetn = 0, acquisition_active = 0;
  logic [3:0] running = 0, locked = 0, rx_error = 0;
  logic capture_request = 0;
  logic [3:0] drp_ready = 0;
  wire [2:0] applied_loopback;
  wire wizard_rx_reset, rx_checker_enable, acquisition_ready;
  wire runtime_reset, idle, fault, capture_done;
  wire [3:0] pma_reset, counter_reset;
  wire [4:0] diagnostic_state;
  wire [31:0] diagnostic_live, diagnostic_rx, diagnostic_counter;
  wire [39:0] drpaddr;
  wire [3:0] drpclk, drpen, drpwe;
  wire [63:0] drpdi;
  wire [127:0] exact_counts;
  wire [3:0] exact_valid, exact_saturated;
  logic [25:0] retained_observation;

  always #2.5 clk = ~clk;
  always_ff @(posedge clk) drp_ready <= drpen;

  gt_prbs_test_controller #(
    .SETTLE_CYCLES(3),
    .RESET_PULSE_CYCLES(3),
    .RUNNING_MASK_SETTLE_CYCLES(3),
    .ERROR_FREE_QUALIFY_CYCLES(12),
    .STAGED_RX_ACQUISITION(1'b1),
    .REQUIRE_ERROR_FREE_QUALIFICATION(1'b0),
    .OPERATION_TIMEOUT_CYCLES(100)
  ) dut (
    .mgmt_clk(clk), .resetn(resetn),
    .lane_running_async(running), .rx_prbs_locked_async(locked),
    .rx_prbs_error_async(rx_error), .requested_loopback(3'b000),
    .acquisition_active(acquisition_active),
    .result_capture_request(capture_request),
    .gtwiz_reset_rx_done_async(1'b1),
    .rxresetdone_async(4'hf), .rxpmaresetdone_async(4'hf),
    .quad_ready(1'b1),
    .applied_loopback(applied_loopback),
    .gtwiz_reset_rx_datapath(wizard_rx_reset),
    .rxpmareset(pma_reset),
    .sequenced_prbs_counter_reset(counter_reset),
    .rx_checker_enable(rx_checker_enable),
    .acquisition_ready(acquisition_ready),
    .runtime_rx_reset_active(runtime_reset),
    .quad_restart_request(),
    .controller_idle(idle), .controller_fault(fault),
    .diagnostic_state(diagnostic_state),
    .diagnostic_live(diagnostic_live), .diagnostic_rx(diagnostic_rx),
    .diagnostic_counter(diagnostic_counter),
    .drpaddr(drpaddr), .drpclk(drpclk), .drpdi(drpdi),
    .drpen(drpen), .drpwe(drpwe), .drpdo(64'd0), .drprdy(drp_ready),
    .result_capture_done(capture_done),
    .exact_error_counts(exact_counts), .exact_error_valid(exact_valid),
    .exact_error_saturated(exact_saturated)
  );

  initial begin
    repeat (3) @(posedge clk);
    resetn <= 1;
    acquisition_active <= 1;
    running <= 4'b0001;
    wait (diagnostic_state == 5'd8);
    locked <= 4'b0001;
    wait (diagnostic_state == 5'd21);

    rx_error <= 4'b0001;
    repeat (3) @(posedge clk);
    rx_error <= 0;
    locked <= 0;
    repeat (3) @(posedge clk);
    locked <= 4'b0001;

    wait (|counter_reset);
    wait (!(|counter_reset));
    wait (acquisition_ready);
    if (fault)
      $fatal(1, "fixed qualification incorrectly faulted");
    if (diagnostic_rx[0] != 1'b1 ||
        diagnostic_rx[31:28] != 4'b0001 ||
        diagnostic_rx[27:24] != 4'b0001)
      $fatal(1, "qualification cause diagnostics are incorrect");
    if (diagnostic_rx[23:6] == 0 || diagnostic_rx[23:6] >= 12)
      $fatal(1, "maximum clean-streak diagnostic is incorrect");
    if (applied_loopback != 0 || wizard_rx_reset || |pma_reset)
      $fatal(1, "fixed external acquisition disturbed RX datapath");

    retained_observation = diagnostic_rx[31:6];
    running <= 0;
    acquisition_active <= 0;
    wait (diagnostic_state == 5'd11);
    capture_request <= 1;
    wait (capture_done);
    capture_request <= 0;
    wait (idle);
    repeat (5) @(posedge clk);
    if (diagnostic_rx[31:6] != retained_observation)
      $fatal(1, "fixed-window diagnostics were not retained through IDLE");

    acquisition_active <= 1;
    running <= 4'b0010;
    wait (diagnostic_state == 5'd1);
    if (diagnostic_rx[31:6] != 0)
      $fatal(1, "fixed-window diagnostics were not cleared for next run");

    $display("PASS: fixed staged acquisition retains evidence through IDLE and clears it on the next run");
    $finish;
  end

  initial begin
    repeat (1000) @(posedge clk);
    $fatal(1, "fixed-acquisition testbench watchdog expired");
  end
endmodule
