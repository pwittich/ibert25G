`timescale 1ns/1ps

module tb_gt_prbs_test_controller #(parameter bit NO_CLEANUP_ACK = 0);
  wire [255:0] recovery_diagnostics;
  logic clk = 0, resetn = 0;
  logic [3:0] running = 0, locked = 0;
  logic [3:0] rx_error = 0;
  logic [2:0] requested_loopback = 0;
  logic acquisition_active = 0;
  logic measurement_enable = 0, rx_clock_heartbeat_async = 0;
  logic capture_request = 0, wizard_rx_done = 1;
  logic [3:0] rx_done = 4'hf, pma_done = 4'hf;
  wire [2:0] applied_loopback;
  wire wizard_rx_reset, acquisition_ready, runtime_reset, idle, fault;
  wire [3:0] pma_reset, counter_reset;
  wire rx_checker_enable;
  wire [4:0] diagnostic_state;
  wire [31:0] diagnostic_live, diagnostic_rx, diagnostic_counter;
  wire [39:0] drpaddr;
  wire [3:0] drpclk, drpen, drpwe;
  wire [63:0] drpdi;
  logic [63:0] drpdo = 0;
  logic [3:0] drprdy = 0;
  wire capture_done;
  wire [127:0] exact_counts;
  wire [3:0] exact_valid, exact_saturated;
  integer runtime_reset_count = 0;
  logic require_pma_continuity = 0;
  logic delay_cleanup_status = 0;
  logic post_idle_status_drop = 0;
  integer cleanup_status_delay = 0;

  always @(negedge clk) begin
    if (require_pma_continuity && applied_loopback != 3'b010)
      $fatal(1, "PMA loopback dropped during acquisition/measurement state %0d", diagnostic_state);
    if (delay_cleanup_status && idle && cleanup_status_delay < 73)
      $fatal(1, "cleanup did not require stable reset-done after the second delayed drop");
  end

  always #2.5 clk = ~clk;

  // A missing progress assignment in a wait-driven state machine would
  // otherwise hang this test indefinitely instead of reporting a regression.
  initial begin
    repeat (5000) @(posedge clk);
    $fatal(1, "PRBS-controller testbench watchdog expired");
  end

  gt_prbs_test_controller #(
    .SETTLE_CYCLES(3), .RESET_PULSE_CYCLES(3),
    .RUNNING_MASK_SETTLE_CYCLES(3),
    .ERROR_FREE_QUALIFY_CYCLES(4),
    .POST_CAPTURE_SETTLE_CYCLES(20),
    .POST_CAPTURE_RX_REQUAL(1'b1),
    .RETAIN_POST_CLEANUP_IDLE_GUARD(1'b1),
    .STAGED_RX_ACQUISITION(1'b1),
    .OPERATION_TIMEOUT_CYCLES(100)
  ) dut (.*,
    .mgmt_clk(clk), .lane_running_async(running),
    .rx_prbs_locked_async(locked),
    .rx_prbs_error_async(rx_error),
    .result_capture_request(capture_request),
    .gtwiz_reset_rx_done_async(wizard_rx_done),
    .rxresetdone_async(rx_done), .rxpmaresetdone_async(pma_done),
    .quad_ready(1'b1),
    .gtwiz_reset_rx_datapath(wizard_rx_reset),
    .rxpmareset(pma_reset),
    .sequenced_prbs_counter_reset(counter_reset),
    .rx_checker_enable(rx_checker_enable),
    .runtime_rx_reset_active(runtime_reset),
    .quad_restart_request(),
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

    if (delay_cleanup_status) begin
      if (wizard_rx_reset || cleanup_status_delay != 0)
        cleanup_status_delay <= cleanup_status_delay + 1;
      // Model control/Wizard/CDC latency: reset-done initially remains high,
      // drops after the short request, recovers, drops a second time when the
      // separately propagated loopback removal takes effect, then recovers.
      // Deliberately later than POST_CAPTURE_SETTLE_CYCLES: elapsed time
      // alone cannot acknowledge that the requested reset actually happened.
      wizard_rx_done <= NO_CLEANUP_ACK ||
        !((cleanup_status_delay >= 28 && cleanup_status_delay < 38) ||
          (cleanup_status_delay >= 48 && cleanup_status_delay < 53));
      rx_done <= (!NO_CLEANUP_ACK &&
                  ((cleanup_status_delay >= 28 && cleanup_status_delay < 38) ||
                   (cleanup_status_delay >= 48 && cleanup_status_delay < 53))) ? 0 : 4'hf;
    end else if (wizard_rx_reset || post_idle_status_drop) begin
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
    acquisition_active <= 1;
    running <= 4'b0011;
    repeat (2) @(posedge clk);
    if (rx_checker_enable)
      $fatal(1, "RX checker enabled before TX-control settling");
    wait (wizard_rx_reset);
    if (applied_loopback != 0 || !runtime_reset)
      $fatal(1, "PMA loopback was applied before the required RX reset");
    wait (applied_loopback == 3'b010);
    require_pma_continuity = 1;
    if (!runtime_reset)
      $fatal(1, "RX recovery qualification ended before PMA reset");
    wait (|pma_reset);
    if (!runtime_reset)
      $fatal(1, "RX recovery qualification missing during PMA reset");
    wait (|counter_reset);
    if (!rx_checker_enable)
      $fatal(1, "RX checker was not enabled after PMA recovery");
    if (!runtime_reset)
      $fatal(1, "RX recovery qualification ended before PRBS reacquisition");
    repeat (3) @(posedge clk);
    if (!runtime_reset || acquisition_ready)
      $fatal(1, "RX recovery qualification did not cover lock wait");
    wait (!(|counter_reset));
    locked <= 4'b0011;
    rx_error <= 4'b0001;
    repeat (2) @(posedge clk);
    rx_error <= 0;
    wait (|counter_reset);
    if (acquisition_ready)
      $fatal(1, "measurement began before the post-lock counter reset");
    wait (!(|counter_reset));
    wait (acquisition_ready);
    acquisition_active <= 0;
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
    require_pma_continuity = 0;
    delay_cleanup_status = 1;
    capture_request <= 0;
    wait (wizard_rx_reset);
    if (NO_CLEANUP_ACK) begin
      wait (fault);
      if (diagnostic_state != 18 || diagnostic_counter < 99)
        $fatal(1, "missing cleanup acknowledgement did not retain bounded stage-18 fault");
      $display("PASS: missing cleanup reset acknowledgement fails boundedly");
      $finish;
    end
    wait (idle);
    if (cleanup_status_delay < 73)
      $fatal(1, "cleanup accepted reset-done before the final stable-high interval");
    delay_cleanup_status = 0;
    if (!runtime_reset)
      $fatal(1, "post-PMA IDLE did not retain the intentional-reset guard");
    // Reproduce the still-later reset-done fall observed on hardware after
    // the previous 100-ms clean interval.  IDLE must mask this cleanup tail.
    post_idle_status_drop = 1;
    repeat (7) @(posedge clk);
    if (!runtime_reset || fault || !idle)
      $fatal(1, "late post-IDLE cleanup transition was not guarded");
    post_idle_status_drop = 0;
    repeat (5) @(posedge clk);

    runtime_reset_count = 0;
    requested_loopback <= 3'b000;
    acquisition_active <= 1;
    running <= 4'b0111;
    repeat (2) @(posedge clk);
    running <= 4'b1111;
    repeat (2) @(posedge clk);
    if (rx_checker_enable)
      $fatal(1, "external RX checker enabled before TX-control settling");
    wait (|counter_reset);
    if (wizard_rx_reset || !runtime_reset ||
        diagnostic_live[11:8] != 4'b1111)
      $fatal(1, "external acquisition reset or lane-mask sequence was wrong");
    wait (!(|counter_reset));
    locked <= 4'b1111;
    wait (|counter_reset);
    if (acquisition_ready)
      $fatal(1, "external measurement began before post-lock counter reset");
    wait (!(|counter_reset));
    wait (acquisition_ready);
    acquisition_active <= 0;
    if (runtime_reset_count != 0 || runtime_reset ||
        applied_loopback != 0 || |pma_reset)
      $fatal(1, "external acquisition disturbed the RX datapath");
    running <= 0;
    repeat (5) @(posedge clk);
    capture_request <= 1;
    wait (capture_done);
    capture_request <= 0;
    wait (idle);
    if (fault || !runtime_reset)
      $fatal(1, "external cleanup did not retain its IDLE guard");
    post_idle_status_drop = 1;
    repeat (7) @(posedge clk);
    if (fault || !idle || !runtime_reset)
      $fatal(1, "late post-external cleanup transition was not guarded");
    post_idle_status_drop = 0;
    repeat (5) @(posedge clk);

    resetn <= 0;
    running <= 0;
    locked <= 0;
    repeat (3) @(posedge clk);
    resetn <= 1;
    repeat (3) @(posedge clk);
    requested_loopback <= 3'b000;
    acquisition_active <= 1;
    running <= 4'b0001;
    wait (fault);
    repeat (5) @(posedge clk);
    if (diagnostic_state != 5'd8)
      $fatal(1, "lock timeout did not retain ST_LOCK_WAIT diagnostic");
    if (!diagnostic_live[31] || diagnostic_live[23:20] != 0 ||
        diagnostic_counter < 32'd99)
      $fatal(1, "lock-timeout diagnostic context was not retained");

    $display("PASS: PMA reset, external live-RX acquisition, stable mask, lock, DRP, diagnostics");
    $finish;
  end
endmodule

module tb_gt_prbs_cleanup_no_ack;
  tb_gt_prbs_test_controller #(.NO_CLEANUP_ACK(1)) test_case();
endmodule
