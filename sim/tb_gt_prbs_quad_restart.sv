`timescale 1ns/1ps

module tb_gt_prbs_quad_restart;
  logic clk = 0;
  logic resetn = 0;
  logic acquisition_active = 0;
  logic [3:0] running = 0;
  logic [3:0] locked = 0;
  logic [3:0] rx_error = 0;
  logic capture_request = 0;
  logic [3:0] drp_ready = 0;
  wire reset_all, quad_ready, quad_fault;
  wire [7:0] quad_fault_reason;
  wire [2:0] quad_state;
  wire [31:0] quad_diagnostic;
  wire quad_restart_request, runtime_reset;
  wire wizard_rx_reset, rx_checker_enable, acquisition_ready;
  wire controller_idle, controller_fault, capture_done;
  wire [2:0] applied_loopback;
  wire [3:0] pma_reset, counter_reset;
  wire [4:0] diagnostic_state;
  wire [31:0] diagnostic_live, diagnostic_rx, diagnostic_counter;
  wire [39:0] drpaddr;
  wire [3:0] drpclk, drpen, drpwe;
  wire [63:0] drpdi;
  wire [127:0] exact_counts;
  wire [3:0] exact_valid, exact_saturated;
  integer restart_edges = 0;
  integer restart_assert_cycles = 0;
  logic restart_request_previous = 0;

  always #2.5 clk = ~clk;
  always_ff @(posedge clk) begin
    drp_ready <= drpen;
    restart_request_previous <= quad_restart_request;
    if (quad_restart_request && !restart_request_previous)
      restart_edges <= restart_edges + 1;
    if (quad_state == 3'd7)
      restart_assert_cycles <= restart_assert_cycles + 1;
  end

  // Model the hardware-observed Wizard behavior: the initial completion rises
  // after reset release, but a runtime restart retains stale-high status while
  // reset_all is asserted. Status falls only after release, stays low briefly,
  // and then returns. This prevents a testbench-only assumption that status
  // must deassert during the level reset request.
  logic gt_completion = 0;
  logic rx_completion = 0;
  logic reset_all_previous = 1;
  logic initial_completion_seen = 0;
  integer completion_delay = 0;
  integer rx_completion_delay = 0;
  always_ff @(posedge clk) begin
    reset_all_previous <= reset_all;
    if (!resetn) begin
      gt_completion <= 0;
      rx_completion <= 0;
      initial_completion_seen <= 0;
      completion_delay <= 0;
      rx_completion_delay <= 0;
    end else if (!initial_completion_seen) begin
      if (!reset_all) begin
        gt_completion <= 1;
        rx_completion <= 1;
        initial_completion_seen <= 1;
      end
    end else if (reset_all_previous && !reset_all) begin
      gt_completion <= 0;
      rx_completion <= 0;
      completion_delay <= 4;
      rx_completion_delay <= 8;
    end else if (!reset_all && completion_delay != 0) begin
      completion_delay <= completion_delay - 1;
      if (completion_delay == 1)
        gt_completion <= 1;
    end
    if (!reset_all && rx_completion_delay != 0) begin
      rx_completion_delay <= rx_completion_delay - 1;
      if (rx_completion_delay == 1)
        rx_completion <= 1;
    end
  end

  gt_quad_controller #(
    .RESET_HOLD_CYCLES(4),
    .INIT_TIMEOUT_CYCLES(40)
  ) quad_controller (
    .mgmt_clk(clk), .resetn(resetn),
    .gtpowergood_async(4'hf), .qpll0lock_async(gt_completion),
    .tx_userclk_active_async(gt_completion),
    .rx_userclk_active_async(rx_completion),
    .txresetdone_async({4{gt_completion}}),
    .rxresetdone_async({4{rx_completion}}),
    .runtime_rx_reset_active(runtime_reset),
    .runtime_quad_restart_request(quad_restart_request),
    .gtwiz_reset_all(reset_all), .quad_ready(quad_ready),
    .quad_fault(quad_fault), .fault_reason(quad_fault_reason),
    .state(quad_state), .diagnostic_live(quad_diagnostic)
  );

  gt_prbs_test_controller #(
    .SETTLE_CYCLES(3),
    .RESET_PULSE_CYCLES(3),
    .RUNNING_MASK_SETTLE_CYCLES(3),
    .ERROR_FREE_QUALIFY_CYCLES(6),
    .STAGED_RX_ACQUISITION(1'b1),
    .REQUIRE_ERROR_FREE_QUALIFICATION(1'b0),
    .EXTERNAL_QUAD_RECOVERY(1'b1),
    .POST_CAPTURE_QUAD_RESTART(1'b1),
    .EXTERNAL_LOCK_RECOVERY_CYCLES(12),
    .OPERATION_TIMEOUT_CYCLES(100)
  ) prbs_controller (
    .mgmt_clk(clk), .resetn(resetn),
    .lane_running_async(running), .rx_prbs_locked_async(locked),
    .rx_prbs_error_async(rx_error), .requested_loopback(3'b000),
    .acquisition_active(acquisition_active),
    .result_capture_request(capture_request),
    .gtwiz_reset_rx_done_async(rx_completion),
    .rxresetdone_async({4{rx_completion}}),
    .rxpmaresetdone_async(4'hf), .quad_ready(quad_ready),
    .applied_loopback(applied_loopback),
    .gtwiz_reset_rx_datapath(wizard_rx_reset),
    .rxpmareset(pma_reset),
    .sequenced_prbs_counter_reset(counter_reset),
    .rx_checker_enable(rx_checker_enable),
    .acquisition_ready(acquisition_ready),
    .runtime_rx_reset_active(runtime_reset),
    .quad_restart_request(quad_restart_request),
    .controller_idle(controller_idle), .controller_fault(controller_fault),
    .diagnostic_state(diagnostic_state),
    .diagnostic_live(diagnostic_live), .diagnostic_rx(diagnostic_rx),
    .diagnostic_counter(diagnostic_counter),
    .drpaddr(drpaddr), .drpclk(drpclk), .drpdi(drpdi),
    .drpen(drpen), .drpwe(drpwe), .drpdo(64'b0), .drprdy(drp_ready),
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

    // Model the hardware loss case where PRBSLOCKED is falsely high while the
    // checker reports continuous garbage. The fixed acquisition observation
    // remains intact, then the sustained-failure qualifier must request the
    // same bounded full-quad restart used for genuinely missing lock.
    locked <= 4'hf;
    rx_error <= 4'h1;
    wait (diagnostic_state == 5'd25);
    wait (diagnostic_state == 5'd23);
    @(negedge clk);
    if (!quad_restart_request || !runtime_reset || wizard_rx_reset)
      $fatal(1, "quad-restart request controls are incorrect");
    wait (diagnostic_state == 5'd24);
    @(negedge clk);
    if (quad_restart_request || quad_ready)
      $fatal(1, "quad-restart acknowledgement was not completed");
    wait (quad_ready);
    rx_error <= 0;
    locked <= 4'hf;
    wait (diagnostic_state == 5'd26);
    wait (acquisition_ready);
    acquisition_active <= 0;
    running <= 0;

    if (quad_fault || controller_fault || restart_edges != 1 ||
        restart_assert_cycles < 2)
      $fatal(1, "coordinated recovery did not complete exactly once");

    // Result capture removes RXPRBSSEL. The hardware showed that waiting for
    // RX reset-done cannot repair that transition, so the enabled policy must
    // perform one coordinated post-capture restart before returning IDLE.
    wait (diagnostic_state == 5'd11);
    capture_request <= 1;
    wait (capture_done);
    capture_request <= 0;
    wait (diagnostic_state == 5'd23);
    wait (diagnostic_state == 5'd24);
    wait (quad_ready);
    wait (controller_idle);
    if (restart_edges != 2 || quad_restart_request || quad_fault ||
        controller_fault)
      $fatal(1, "post-capture coordinated restart did not complete once");

    $display("PASS: sustained-failure and post-capture quad restarts");
    $finish;
  end

  initial begin
    repeat (1000) @(posedge clk);
    $fatal(1, "quad-restart integration testbench watchdog expired");
  end
endmodule
