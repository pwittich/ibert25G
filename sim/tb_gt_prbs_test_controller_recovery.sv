`timescale 1ns/1ps

module tb_gt_prbs_test_controller_recovery;
  wire [255:0] recovery_diagnostics;
  logic clk = 0, resetn = 0, acquisition_active = 0;
  logic [3:0] running = 0, locked = 0, rx_error = 0;
  logic capture_request = 0, wizard_rx_done = 1;
  logic [3:0] rx_done = 4'hf, pma_done = 4'hf;
  logic [3:0] drp_ready = 0;
  wire [2:0] applied_loopback;
  wire wizard_rx_reset, rx_checker_enable, acquisition_ready;
  wire runtime_reset, idle, fault, capture_done;
  wire quad_ready, quad_fault, quad_reset_all;
  wire [3:0] pma_reset, counter_reset;
  wire [4:0] diagnostic_state;
  wire [31:0] diagnostic_live, diagnostic_rx, diagnostic_counter;
  wire [39:0] drpaddr;
  wire [3:0] drpclk, drpen, drpwe;
  wire [63:0] drpdi;
  wire [127:0] exact_counts;
  wire [3:0] exact_valid, exact_saturated;
  integer rx_reset_pulses = 0;
  logic reset_was_active = 0;
  logic post_capture_drop = 0;
  logic wizard_stuck_low = 0;

  always #2.5 clk = ~clk;
  always_ff @(posedge clk) begin
    drp_ready <= drpen;
    reset_was_active <= wizard_rx_reset;
    if (wizard_rx_reset && !reset_was_active)
      rx_reset_pulses <= rx_reset_pulses + 1;
    if (wizard_rx_reset || post_capture_drop) begin
      rx_done <= 0;
    end else begin
      rx_done <= 4'hf;
    end
    wizard_rx_done <= !(wizard_rx_reset || post_capture_drop ||
                        wizard_stuck_low);
  end

  // Exercise the real supervisor boundary. F2 q231 showed RXRESETDONE falling
  // while its local controller was already in CAPTURE_DONE but the global
  // capture request was still asserted. That post-measurement transition must
  // be guarded before the later RX-requalification state begins.
  gt_quad_controller #(
    .RESET_HOLD_CYCLES(3), .INIT_TIMEOUT_CYCLES(100)
  ) supervisor (
    .mgmt_clk(clk), .resetn(resetn), .gtpowergood_async(4'hf),
    .qpll0lock_async(1'b1), .tx_userclk_active_async(1'b1),
    .rx_userclk_active_async(1'b1), .txresetdone_async(4'hf),
    .rxresetdone_async(rx_done), .runtime_rx_reset_active(runtime_reset),
    .runtime_quad_restart_request(1'b0),
    .gtwiz_reset_all(quad_reset_all), .quad_ready(quad_ready),
    .quad_fault(quad_fault), .fault_reason(), .state(), .diagnostic_live()
  );

  gt_prbs_test_controller #(
    .SETTLE_CYCLES(3),
    .RESET_PULSE_CYCLES(3),
    .RUNNING_MASK_SETTLE_CYCLES(3),
    .ERROR_FREE_QUALIFY_CYCLES(6),
    .STAGED_RX_ACQUISITION(1'b1),
    .REQUIRE_ERROR_FREE_QUALIFICATION(1'b0),
    .EXTERNAL_RX_RECOVERY(1'b1),
    .POST_CAPTURE_RX_REQUAL(1'b1),
    .EXTERNAL_LOCK_RECOVERY_CYCLES(12),
    .POST_CAPTURE_SETTLE_CYCLES(12),
    .OPERATION_TIMEOUT_CYCLES(100)
  ) dut (
    .mgmt_clk(clk), .resetn(resetn),
    .lane_running_async(running), .rx_prbs_locked_async(locked),
    .rx_prbs_error_async(rx_error), .requested_loopback(3'b000),
    .acquisition_active(acquisition_active),
    .result_capture_request(capture_request),
    .gtwiz_reset_rx_done_async(wizard_rx_done),
    .rxresetdone_async(rx_done), .rxpmaresetdone_async(pma_done),
    .quad_ready(quad_ready),
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
    wait (quad_ready);
    acquisition_active <= 1;
    running <= 4'hf;
    wait (diagnostic_state == 5'd8);

    // Reproduce the hardware symptom: only one lane initially locks. The
    // first bounded wait must cause exactly one external RX recovery pulse.
    locked <= 4'h8;
    wait (wizard_rx_reset);
    locked <= 0;
    if (!runtime_reset || rx_checker_enable || applied_loopback != 0)
      $fatal(1, "external recovery controls are incorrect");
    wait (!wizard_rx_reset);
    wait (diagnostic_state == 5'd7);
    locked <= 4'hf;
    wait (acquisition_ready);
    acquisition_active <= 0;

    if (fault || runtime_reset || rx_reset_pulses != 1)
      $fatal(1, "external recovery did not complete with exactly one reset");
    repeat (20) @(posedge clk);
    if (rx_reset_pulses != 1)
      $fatal(1, "external recovery reset repeated after lock");

    // Complete the local counter reads, then reproduce the early RX-done drop
    // seen on q231 while the global capture request is still high. The guard
    // must begin in CAPTURE_DONE, before the later requalification state.
    running <= 0;
    wait (diagnostic_state == 5'd11);
    capture_request <= 1;
    wait (capture_done);
    post_capture_drop <= 1;
    repeat (5) @(posedge clk);
    if (!runtime_reset || idle || fault || quad_fault)
      $fatal(1, "CAPTURE_DONE RX-done drop was not guarded");
    capture_request <= 0;
    wait (diagnostic_state == 5'd22);
    repeat (6) @(posedge clk);
    if (!runtime_reset || idle || fault || quad_fault)
      $fatal(1, "post-capture RX-done drop was not continuously guarded");
    // V11 hardware left the Wizard aggregate low after every primitive
    // RXRESETDONE and the selected PMA-done inputs recovered.
    wizard_stuck_low <= 1;
    post_capture_drop <= 0;
    wait (idle);
    if (wizard_rx_done || runtime_reset || fault || quad_fault)
      $fatal(1, "per-lane post-capture RX status did not requalify cleanly");

    $display("PASS: bounded external recovery and CAPTURE_DONE-to-IDLE RX requalification");
    $finish;
  end

  initial begin
    repeat (1000) @(posedge clk);
    $fatal(1, "external-recovery testbench watchdog expired");
  end
endmodule
