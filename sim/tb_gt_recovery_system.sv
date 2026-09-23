`timescale 1ns/1ps

// Real core, lane engines/XPM snapshots, PRBS controller, quad controller and
// reset policy. Only physical GT behavior and CPU register transport are
// modeled. RX and management clocks are unrelated; RX stops during reset.
module tb_gt_recovery_system;
  logic clk = 0, rxclk = 0, resetn = 0;
  logic rx_heartbeat = 0;
  logic pause_rx = 0, stuck_gt = 0;
  wire reset_all, ready, qfault, pfault, idle, acquire_ready;
  always #2.5 clk = ~clk;
  always #1.551 if (!pause_rx && !reset_all) rxclk = ~rxclk;
  always @(posedge rxclk) rx_heartbeat <= ~rx_heartbeat;
  wire acquire, measure, measurement_run_toggle;
  wire controls, capture_request, capture_done;
  wire lane_reset, restart, runtime_reset, checker_enable;
  wire [111:0] running, counter_reset;
  wire [335:0] txsel, rxsel;
  wire [2:0] loopback;
  wire [4:0] pstate;
  wire [31:0] live_prbs, live_rx, live_counter, live_quad;
  wire [255:0] diagnostics;
  wire [3:0] drpen;
  logic [3:0] drprdy = 0;
  logic gt_done = 0, reset_previous = 1;
  integer gt_delay = 0;
  logic [1:0] stimulus = 0; // 1 missing lock, 2 sustained error
  wire [3:0] errors = stimulus == 2 ? 4'h1 : 4'h0;
  wire [3:0] locked;
  for (genvar l = 0; l < 4; l++) begin
    assign locked[l] = gt_done && checker_enable && stimulus != 1 &&
                       rxsel[(12+l)*3 +: 3] == 5 &&
                       txsel[(12+l)*3 +: 3] == 5;
  end
  // Wizard-like delayed reset-done: status drops after release and returns
  // later, including when the RX clock was absent throughout reset.
  always @(posedge clk) begin
    reset_previous <= reset_all;
    drprdy <= drpen;
    if (!resetn) begin gt_done <= 0; gt_delay <= 0; end
    else if (reset_previous && !reset_all) begin
      gt_done <= 0; gt_delay <= 8;
    end else if (gt_delay != 0 && !stuck_gt) begin
      gt_delay <= gt_delay - 1;
      if (gt_delay == 1) gt_done <= 1;
    end
  end
  gt_quad_controller #(.RESET_HOLD_CYCLES(8), .INIT_TIMEOUT_CYCLES(100)) quad (
    .mgmt_clk(clk), .resetn(resetn), .gtpowergood_async(4'hf),
    .qpll0lock_async(gt_done), .tx_userclk_active_async(gt_done),
    .rx_userclk_active_async(gt_done), .txresetdone_async({4{gt_done}}),
    .rxresetdone_async({4{gt_done}}), .runtime_rx_reset_active(runtime_reset),
    .runtime_quad_restart_request(restart), .gtwiz_reset_all(reset_all),
    .quad_ready(ready), .quad_fault(qfault), .fault_reason(), .state(),
    .diagnostic_live(live_quad)
  );
  managed_quad124_lane_reset_policy policy (
    .rx_clk(rxclk), .resetn(resetn), .quad_ready(ready),
    .acquisition_active(acquire), .lane_rx_reset(lane_reset)
  );
  gt_prbs_test_controller #(
    .SETTLE_CYCLES(8), .RESET_PULSE_CYCLES(4),
    .RUNNING_MASK_SETTLE_CYCLES(8), .ERROR_FREE_QUALIFY_CYCLES(12),
    .STAGED_RX_ACQUISITION(1), .REQUIRE_ERROR_FREE_QUALIFICATION(0),
    .EXTERNAL_QUAD_RECOVERY(1), .POST_CAPTURE_QUAD_RESTART(1),
    .RUNTIME_INTEGRITY_DETECTOR(1),
    .INTEGRITY_ERROR_ASSERT_CYCLES(8),
    .INTEGRITY_ERROR_CLEAR_CYCLES(5),
    .INTEGRITY_CLOCK_TIMEOUT_CYCLES(40),
    .EXTERNAL_LOCK_RECOVERY_CYCLES(40), .OPERATION_TIMEOUT_CYCLES(400)
  ) prbs (
    .mgmt_clk(clk), .resetn(resetn), .lane_running_async(running[15:12]),
    .rx_prbs_locked_async(locked), .rx_prbs_error_async(errors),
    .requested_loopback(loopback), .acquisition_active(acquire),
    .measurement_enable(measure),
    .rx_clock_heartbeat_async(rx_heartbeat),
    .result_capture_request(capture_request),
    .gtwiz_reset_rx_done_async(gt_done), .rxresetdone_async({4{gt_done}}),
    .rxpmaresetdone_async({4{gt_done}}), .quad_ready(ready),
    .applied_loopback(), .gtwiz_reset_rx_datapath(), .rxpmareset(),
    .sequenced_prbs_counter_reset(), .rx_checker_enable(checker_enable),
    .acquisition_ready(acquire_ready), .runtime_rx_reset_active(runtime_reset),
    .quad_restart_request(restart), .controller_idle(idle),
    .controller_fault(pfault), .diagnostic_state(pstate),
    .diagnostic_live(live_prbs), .diagnostic_rx(live_rx),
    .diagnostic_counter(live_counter), .recovery_diagnostics(diagnostics),
    .drpaddr(), .drpclk(), .drpdi(), .drpen(drpen), .drpwe(),
    .drpdo(64'd0), .drprdy(drprdy), .result_capture_done(capture_done),
    .exact_error_counts(), .exact_error_valid(), .exact_error_saturated()
  );
  logic write = 0;
  logic [11:0] wa = 0, ra = 0;
  logic [31:0] wd = 0;
  wire [31:0] rd;
  wire irq;
  logic [7:0] ia = 0, iwdata = 0;
  logic iw = 0;
  wire [7:0] ir;
  wire [7:0] diagnostic_selector;
  wire [1:0] diagnostic_bank;
  wire [255:0] diagnostic_record = {8{22'h2af37b, diagnostic_bank, diagnostic_selector}};
  gt_test_engine_core #(.MANAGED_LANE_MASK(112'hf000)) core (
    .mgmt_clk(clk), .mgmt_resetn(resetn), .reg_write(write),
    .reg_write_address(wa), .reg_write_data(wd), .reg_write_strobe(4'hf),
    .reg_read_address(ra), .reg_read_data(rd), .interrupt(irq),
    .status_firmware_alive(), .status_engine_busy(), .status_fault(),
    .platform_ready(ready && idle), .platform_fault(qfault || pfault),
    .platform_status(32'h12345678),
    .platform_diagnostics({128'd0, live_quad, live_rx, live_prbs}),
    .recovery_diagnostics(diagnostics), .acquisition_ready(acquire_ready),
    .diagnostic_record(diagnostic_record), .diagnostic_selector(diagnostic_selector), .engine_protocol_debug(),
    .diagnostic_bank(diagnostic_bank),
    .result_capture_done(capture_done), .exact_error_counts(3584'd0),
    .exact_error_valid(112'd0), .exact_error_saturated(112'd0),
    .mailbox_i2c_address(ia), .mailbox_i2c_write(iw),
    .mailbox_i2c_write_data(iwdata), .mailbox_i2c_read_data(ir),
    .mailbox_i2c_read_data_next(), .rx_clk({112{rxclk}}),
    .rx_reset({112{lane_reset}}), .rx_prbs_locked({96'd0, locked, 12'd0}),
    .rx_cdr_locked({112{gt_done}}), .rx_prbs_errors(1792'd0),
    .tx_prbs_select(txsel), .rx_prbs_select(rxsel),
    .prbs_counter_reset(counter_reset), .lane_running(running),
    .loopback_mode(loopback), .measurement_enable(measure),
    .measurement_run_toggle(measurement_run_toggle),
    .controls_enable(controls), .tx_session_ready(1'b1),
    .acquisition_active(acquire),
    .result_capture_request(capture_request), .tx_error_inject_toggle()
  );
  task automatic wr(input logic [11:0] address, input logic [31:0] data);
    @(negedge clk); wa = address; wd = data; write = 1;
    @(negedge clk); write = 0;
  endtask
  task automatic expect_reg(input logic [11:0] address, input logic [31:0] value);
    ra = address; #1;
    if (rd !== value) $fatal(1, "register %h got %h expected %h", address, rd, value);
  endtask
  task automatic select_i2c(input logic [7:0] selector);
    @(negedge clk); ia = 8'hcc; iwdata = selector; iw = 1;
    @(negedge clk); iw = 0;
  endtask
  integer start_edges = 0, stop_edges = 0;
  integer measurement_starts = 0, measurement_stops = 0;
  integer measurement_epochs = 0;
  logic [31:0] observed_run_id = 0;
  logic [255:0] published_records [12:15];
  logic [255:0] observed_record;
  // Once published, every byte must remain unchanged until the single next
  // publication event. This catches a partial-bank overwrite during recovery.
  always @(negedge clk) begin
    if (!resetn) begin
      // The later fresh-start scenario deliberately resets the core, whose
      // run ID restarts at zero. Reset this testbench-only history with it.
      observed_run_id = 0;
    end else if (core.run_id != 0) begin
      for (integer lane = 12; lane < 16; lane++) begin
        observed_record = core.published_bank ? core.result_bank_1[lane] :
                                               core.result_bank_0[lane];
        if (observed_run_id == core.run_id &&
            published_records[lane] !== observed_record)
          $fatal(1, "published record changed without run-ID increment");
        published_records[lane] = observed_record;
      end
      if (core.run_id != observed_run_id && core.run_id != observed_run_id + 1)
        $fatal(1, "run ID skipped or repeated");
      observed_run_id = core.run_id;
    end
  end
  logic old_start = 0, old_stop = 0;
  logic old_measure = 0, old_measurement_run_toggle = 0;
  always @(negedge clk) if (resetn) begin
    if (measure !== (core.state == 4'd2))
      $fatal(1, "registered measurement control is not aligned with RUN");
    if (measure && !old_measure) measurement_starts = measurement_starts + 1;
    if (!measure && old_measure) measurement_stops = measurement_stops + 1;
    if (measurement_run_toggle != old_measurement_run_toggle)
      measurement_epochs = measurement_epochs + 1;
    old_measure = measure;
    old_measurement_run_toggle = measurement_run_toggle;
  end
  always @(posedge rxclk) if (resetn) begin
    if (core.start_ack_toggle[12] != old_start) start_edges = start_edges + 1;
    if (core.stop_ack_toggle[12] != old_stop) stop_edges = stop_edges + 1;
    old_start = core.start_ack_toggle[12]; old_stop = core.stop_ack_toggle[12];
  end

  task automatic run_request(input integer seq, input integer fault_mode,
                             input integer ending, input logic [31:0] mask);
    integer before_requests, before_completions;
    integer before_measurement_starts, before_measurement_stops;
    integer before_measurement_epochs;
    logic [31:0] expected_summary;
    wait (ready && idle);
    before_requests = diagnostics[95:64];
    before_completions = diagnostics[127:96];
    before_measurement_starts = measurement_starts;
    before_measurement_stops = measurement_stops;
    before_measurement_epochs = measurement_epochs;
    stimulus = fault_mode;
    // Explicit CPU transport model: hardware owns runs/publication; the CPU
    // model writes response sequence after interrupt, just like firmware.
    @(negedge clk); ia = 8'ha0; iwdata = seq; iw = 1;
    @(negedge clk); iw = 0;
    wr(12'h00c, 4);
    wr(12'h020, 32'h501); wr(12'h024, 150);
    wr(12'h028, ending == 3 ? 60 : 0); wr(12'h02c, mask);
    wr(12'h00c, 1);
    wait (acquire);
    if (fault_mode != 0) begin
      wait (restart);
      // Freeze a coherent page at request entry, then prove it remains frozen
      // while live counters advance. Re-select later to refresh.
      select_i2c(8'hfd);
      wait (!ready);
      pause_rx = 1;
      stimulus = 0;
      wait (ready);
      repeat (6) @(negedge clk);
      if (!lane_reset) $fatal(1, "recovery reset lost during absent RX clock");
      expect_reg(12'h0dc, before_completions);
      pause_rx = 0;
    end
    wait (measure);
    if (ending == 4)
      force core.g_lane[12].g_managed.u_lane.selected = 1'b0;
    if (fault_mode != 0) begin
      select_i2c(8'hfd);
      expect_reg(12'h0d8, before_requests + 1);
      expect_reg(12'h0dc, before_completions + 1);
      expect_reg(12'h0e4, before_requests + 1);
      expect_reg(12'h0e0, (mask == 32'hf000 ? 32'h000f0300 :
                           32'h00010300) | fault_mode);
    end
    if (ending == 2) begin repeat (30) @(negedge clk); wr(12'h00c, 2); end
    wait (irq);
    if (ending == 4)
      release core.g_lane[12].g_managed.u_lane.selected;
    expect_reg(12'h018, seq);
    expected_summary = mask == 32'hf000 ? 32'h00040400 : 32'h00010100;
    if (ending == 4) expected_summary = 32'h01030400;
    expect_reg(12'h01c, expected_summary | ending);
    wr(12'h0f0, seq);
    expect_reg(12'h0f0, seq); expect_reg(12'h0a0, seq);
    wait (idle && ready);
    repeat (10) @(negedge clk);
    if (qfault || pfault || running != 0 || start_edges != seq || stop_edges != seq)
      $fatal(1, "request %0d protocol/idle failure start=%0d stop=%0d", seq, start_edges, stop_edges);
    if (measurement_epochs != before_measurement_epochs + 1 ||
        measurement_starts != before_measurement_starts + 1 ||
        measurement_stops != before_measurement_stops + 1)
      $fatal(1, "request %0d measurement ownership mismatch epochs=%0d starts=%0d stops=%0d",
        seq, measurement_epochs, measurement_starts, measurement_stops);
    if (diagnostics[95:64] != before_requests + 1 + (fault_mode != 0) ||
        diagnostics[127:96] != before_completions + 1 + (fault_mode != 0))
      $fatal(1, "request %0d restart count mismatch requests=%h completed=%h before=%h/%h expected=%h/%h", seq,
        diagnostics[95:64], diagnostics[127:96], before_requests, before_completions,
        before_requests + 1 + (fault_mode != 0), before_completions + 1 + (fault_mode != 0));
    select_i2c(8'hfd);
    expect_reg(12'h0d0, 32'h52430001);
    expect_reg(12'h0d4, 3);
    expect_reg(12'h0d8, diagnostics[95:64]);
    expect_reg(12'h0dc, diagnostics[127:96]);
    expect_reg(12'h0e0, mask == 32'hf000 ? 32'h000f0303 : 32'h00010303);
    // Check the full little-endian page through MCU reads as well as AXI.
    for (integer b = 0; b < 32; b++) begin
      ia = 8'hd0 + b; #1;
      if (ir !== core.recovery_snapshot[b*8 +: 8])
        $fatal(1, "recovery I2C byte %0d mismatch", b);
    end
    select_i2c(8'hfe); expect_reg(12'h0d0, 32'h12345678);
    for (integer lane = 12; lane < 16; lane++) begin
      wr(12'h03c, lane); repeat (3) @(negedge clk);
      expect_reg(12'h040, ((ending == 4 && lane == 12) ? 32'h2800 :
                          (mask[lane] ? 32'h1800 : 0)) | lane);
      expect_reg(12'h044, 0); expect_reg(12'h048, 0);
      expect_reg(12'h054, (ending == 4 && lane == 12) ? 1 : 0);
      ra = 12'h04c; #1;
      if (mask[lane] && !(ending == 4 && lane == 12) && rd == 0)
        $fatal(1, "selected lane has no tested bits");
    end
    if (core.g_lane[12].g_managed.u_lane.snapshot_send)
      $fatal(1, "snapshot handshake left pending");
    $display("request %0d passed mode=%0d ending=%0d", seq, fault_mode, ending);
  endtask

  initial begin
    repeat (5) @(negedge clk); resetn = 1;
    // Exercise all trace/profile selectors through both transports, including
    // the legacy result-window alias and every little-endian MCU byte.
    for (integer s = 128; s <= 252; s++) if (s <= 191 || s >= 248) begin
      wr(12'h03c, s);
      expect_reg(12'h03c, s); expect_reg(12'h040, 32'habcdec00 | s);
      select_i2c(s);
      expect_reg(12'h0cc, s);
      for (integer b = 0; b < 32; b++) begin
        ia = 8'hd0 + b; #1;
        if (ir !== diagnostic_record[b*8 +: 8])
          $fatal(1, "trace selector %h byte %0d mismatch", s, b);
      end
    end
    for (integer bank = 0; bank < 4; bank++) begin
      for (integer slot = 0; slot < 64; slot++) begin
        wr(12'h03c, (bank << 8) | 128 | slot);
        expect_reg(12'h03c, (bank << 8) | 128 | slot);
        expect_reg(12'h040, 32'habcdec80 | (bank << 8) | slot);
        select_i2c(8'h80 | slot);
        expect_reg(12'h03c, 128 | slot); // one-byte selection clears bank
        @(negedge clk); ia = 8'hcd; iwdata = bank; iw = 1;
        @(negedge clk); iw = 0;
        expect_reg(12'h0cc, (bank << 8) | 128 | slot);
        expect_reg(12'h0d0, 32'habcdec80 | (bank << 8) | slot);
      end
    end
    select_i2c(8'hfd); expect_reg(12'h0d0, 32'h52430001);
    select_i2c(8'hfe); expect_reg(12'h0d0, 32'h12345678);
    wr(12'h03c, 12); expect_reg(12'h03c, 12);
    run_request(1, 0, 1, 32'hf000);
    run_request(2, 0, 1, 32'hf000);
    run_request(3, 1, 1, 32'h1000);
    run_request(4, 2, 1, 32'hf000);
    run_request(5, 0, 1, 32'hf000);
    run_request(6, 0, 2, 32'hf000);
    run_request(7, 0, 3, 32'hf000);
    // Corrupt the accepted selected bit: publication must fail the requested
    // lane, not shrink the aggregate to a three-lane success.
    run_request(8, 0, 4, 32'hf000);
    // Testbench deposit near saturation: one completed cleanup reaches max,
    // then the following failed request must not wrap any counter.
    @(negedge clk);
    prbs.restart_count = 32'hfffffffe;
    prbs.restart_completed_count = 32'hfffffffe;
    prbs.restart_accepted_count = 32'hfffffffe;
    #1; // allow continuous diagnostic packing to reflect the test deposit
    run_request(9, 0, 1, 32'hf000);
    // Permanent clock failure: management must publish failed atomic records
    // without waiting forever for RX-domain acknowledgements.
    stimulus = 1;
    wr(12'h00c, 4); wr(12'h00c, 1);
    wait (restart); stuck_gt = 1; pause_rx = 1;
    wait (irq); expect_reg(12'h018, 10);
    expect_reg(12'h01c, 32'h04000404);
    wait (pfault);
    repeat (3) @(negedge clk);
    if (diagnostics[143:136] != 4) $fatal(1, "restart failure not retained");
    select_i2c(8'hfd); expect_reg(12'h0e0, 32'h000f0401);
    expect_reg(12'h0d8, 32'hffffffff);
    expect_reg(12'h0dc, 32'hffffffff);
    expect_reg(12'h0e4, 32'hffffffff);
    resetn = 0; repeat (3) @(negedge clk);
    if (diagnostics[191:64] != 0) $fatal(1, "management reset did not clear records");

    // Fresh post-reset request: a short transient remains harmless, while a
    // sustained measurement-time error becomes a platform fault, publishes
    // one failed atomic result, and retains the integrity event through FD.
    pause_rx = 0; stuck_gt = 0; stimulus = 0;
    resetn = 1;
    wait (ready && idle);
    @(negedge clk); ia = 8'ha0; iwdata = 1; iw = 1;
    @(negedge clk); iw = 0;
    wr(12'h00c, 4); wr(12'h020, 32'h501); wr(12'h024, 150);
    wr(12'h02c, 32'hf000); wr(12'h00c, 1);
    wait (measure);
    stimulus = 2;
    wait (irq);
    expect_reg(12'h018, 1);
    expect_reg(12'h01c, 32'h04000404);
    if (!pfault || pstate != 5'd27 || diagnostics[223:192] != 1 ||
        diagnostics[233:230] != 4'b0001)
      $fatal(1, "integrated runtime-integrity evidence/publication failed");
    // A retained PRBS-controller fault disables the checker, so modeled
    // RXPRBSLOCKED falls after the first-fault snapshot. This must not be
    // confused with a second physical-quad fault or a Wizard reset. The core
    // publishes synthetic 0x280x platform-failure records in this path rather
    // than lane-domain lock-loss counters.
    repeat (8) @(negedge clk);
    if (checker_enable || locked != 0 || qfault || reset_all || !ready ||
        quad.state != 3'd4)
      $fatal(1, "post-integrity checker shutdown disturbed the ready quad");
    for (integer lane = 12; lane < 16; lane++) begin
      observed_record = core.published_bank ? core.result_bank_1[lane] :
                                             core.result_bank_0[lane];
      if (observed_record[31:0] != (32'h0000_2800 | lane) ||
          observed_record[159:32] != 0 ||
          observed_record[191:160] != 32'd1 ||
          observed_record[255:192] != 0)
        $fatal(1, "lane %0d is not a deterministic platform-failure record", lane);
    end

    $display("PASS: integrated recovery, both phases, paused clock, retained diagnostics, abort/timeout, and runtime integrity publication");
    $finish;
  end
  initial begin
    repeat (30000) @(posedge clk);
    $fatal(1, "integrated watchdog core=%0d prbs=%0d quad=%0d", core.state, pstate, quad.state);
  end
endmodule
