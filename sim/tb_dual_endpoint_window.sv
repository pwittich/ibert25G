`timescale 1ns/1ps
// Actual v4 engine/lane RTL, modeled acquisition readiness and optical errors.
// Not a GT analog/CDR model. One managed lane per 112-lane ABI endpoint.
module tb_dual_endpoint_window #(parameter bit SESSIONS=0);
  logic clk=0, resetn=0;
  always #2.5 clk=~clk;
  logic [1:0] wr=0, ready=0;
  logic [11:0] address[2];
  logic [31:0] data[2];
  wire [335:0] tx[2];
  wire [335:0] lane_tx[2];
  wire [1:0] session_active;
  logic rx_clock_enabled=1;
  wire rx_clock = clk && rx_clock_enabled;
  logic platform_fault=0;
  wire [1:0] measure, busy, irq;
  logic uncovered=0;
  for (genvar i=0; i<2; i++) begin : endpoint
    wire [1791:0] errors = tx[1-i][2:0] == 3'd5 ? 1792'd0 : 1792'd1;
    assign tx[i] = SESSIONS && endpoint[i].dut.active_loopback_mode == 0 ?
      {333'd0, (session_active[i] ? 3'd5 : 3'd0)} : lane_tx[i];
    gt_test_engine_core #(.ENABLE_TX_SESSION(SESSIONS), .SESSION_CYCLES_PER_MS(20),
      .MANAGED_LANE_MASK(112'd1), .ASYNC_SNAPSHOT_MASK(112'd0)) dut (
      .mgmt_clk(clk), .mgmt_resetn(resetn), .reg_write(wr[i]),
      .reg_write_address(address[i]), .reg_write_data(data[i]), .reg_write_strobe(4'hf),
      .reg_read_address(12'd0), .reg_read_data(), .interrupt(irq[i]),
      .status_firmware_alive(), .status_engine_busy(busy[i]), .status_fault(),
      .platform_ready(!platform_fault), .platform_fault(platform_fault), .platform_status(32'd0),
      .platform_diagnostics(224'd0), .recovery_diagnostics(256'd0),
      .diagnostic_record(256'd0), .diagnostic_selector(), .diagnostic_bank(),
      .engine_protocol_debug(), .acquisition_ready(ready[i]), .result_capture_done(1'b1),
      .exact_error_counts(3584'd0), .exact_error_valid(112'd0), .exact_error_saturated(112'd0),
      .mailbox_i2c_address(8'd0), .mailbox_i2c_write(1'b0), .mailbox_i2c_write_data(8'd0),
      .mailbox_i2c_read_data(), .mailbox_i2c_read_data_next(),
      .rx_clk({112{rx_clock}}), .rx_reset(112'd0), .rx_prbs_locked({112{1'b1}}),
      .rx_cdr_locked({112{1'b1}}), .rx_prbs_errors(errors), .tx_prbs_select(lane_tx[i]),
      .tx_session_active(session_active[i]), .tx_session_ready(session_active[i]),
      .rx_prbs_select(), .prbs_counter_reset(), .lane_running(), .loopback_mode(),
      .measurement_enable(measure[i]), .measurement_run_toggle(), .controls_enable(),
      .acquisition_active(), .result_capture_request(), .tx_error_inject_toggle());
  end
  always @(posedge clk)
    if (resetn && measure[1] && tx[0][2:0] != 5) uncovered <= 1;
  task automatic write_both(input logic [11:0] a, input logic [31:0] d);
    @(negedge clk);
    address[0]=a; address[1]=a; data[0]=d; data[1]=d; wr=3;
    @(negedge clk); wr=0;
  endtask
  initial begin
    address[0]=0; address[1]=0; data[0]=0; data[1]=0;
    repeat(8) @(negedge clk); resetn=1;
    repeat(8) @(negedge clk);
    if (SESSIONS) begin
      write_both(12'h10c,32'd1000);
      write_both(12'h100,32'd1);
      if (session_active != 3) $fatal(1,"session did not start before any RX request");
      write_both(12'h100,32'd1);
      if (!endpoint[0].dut.session_rejected) $fatal(1,"duplicate session accepted");
    end
    write_both(12'h020,32'h501); // PRBS31 external, cycle timebase for speed.
    write_both(12'h024,32'd1000);
    write_both(12'h02c,32'd1);
    write_both(12'h00c,32'd1);
    wait(tx[0][2:0]==5 && tx[1][2:0]==5);
    @(negedge clk); ready[0]=1;
    if (SESSIONS) begin
      write_both(12'h100,32'd2);
      if (session_active != 3 || !endpoint[0].dut.session_rejected)
        $fatal(1,"busy stop must be rejected without interrupting peer TX");
    end
    repeat(400) @(negedge clk); ready[1]=1;
    wait(&irq);
    repeat(8) @(negedge clk);
    if (SESSIONS && uncovered) $fatal(1,"session did not cover both receive windows");
    if (!SESSIONS && !uncovered) $fatal(1,"Expected uncovered late receiver window not reproduced");
    if (endpoint[0].dut.aggregate_summary != 32'h00010101)
      $fatal(1,"Early receiver should be clean");
    if (endpoint[1].dut.aggregate_summary != (SESSIONS ? 32'h00010101 : 32'h01000101))
      $fatal(1,"Late receiver should report modeled source-off errors: %h",endpoint[1].dut.aggregate_summary);
    if (SESSIONS) begin
      if (session_active != 3) $fatal(1,"publication stopped TX session");
      write_both(12'h100,32'd2);
      if (session_active != 0) $fatal(1,"explicit idle stop failed");
      write_both(12'h10c,32'd1);
      write_both(12'h100,32'd1);
      repeat(25) @(negedge clk);
      if (session_active != 0 || !endpoint[0].dut.session_expired)
        $fatal(1,"watchdog did not expire");
      if (endpoint[0].dut.aggregate_summary != 32'h00010101 || endpoint[0].dut.run_id != 1)
        $fatal(1,"session controls modified frozen receive results");
      write_both(12'h00c,32'd4);
      write_both(12'h00c,32'd1);
      if (busy || !endpoint[0].dut.bad_command) $fatal(1,"external run without lease accepted");
      // A missing RX clock cannot prevent lease expiry or failed publication.
      write_both(12'h00c,32'd4);
      ready=0;
      write_both(12'h10c,32'd2);
      write_both(12'h100,32'd1);
      rx_clock_enabled=0;
      write_both(12'h00c,32'd1);
      wait(&irq);
      if (session_active || endpoint[0].dut.run_id != 2 ||
          endpoint[0].dut.aggregate_summary != 32'h01000104)
        $fatal(1,"missing-clock lease expiry must publish one failed run");
      rx_clock_enabled=1;
      repeat(10) @(negedge clk);
      write_both(12'h00c,32'd4);
      write_both(12'h10c,32'd1000);
      write_both(12'h100,32'd1);
      platform_fault=1;
      repeat(3) @(negedge clk);
      if (session_active || !endpoint[0].dut.session_expired)
        $fatal(1,"platform fault did not terminate session");
      platform_fault=0;
      write_both(12'h100,32'd1);
      resetn=0;
      repeat(3) @(negedge clk);
      if (session_active) $fatal(1,"management reset did not disable TX");
      resetn=1; ready=3;
      repeat(10) @(negedge clk);
      write_both(12'h020,32'h1501); // PMA retains legacy per-run TX.
      write_both(12'h024,32'd1000);
      write_both(12'h02c,32'd1);
      write_both(12'h00c,32'd1);
      wait(&irq);
      if (endpoint[0].dut.aggregate_summary != 32'h00010101 ||
          endpoint[1].dut.aggregate_summary != 32'h00010101 || session_active)
        $fatal(1,"v5 PMA measurement changed historical semantics");
      write_both(12'h00c,32'd4);
      write_both(12'h020,32'h501);
      write_both(12'h10c,32'd1000);
      write_both(12'h100,32'd1);
      write_both(12'h00c,32'd1);
      wait(&measure);
      repeat(10) @(negedge clk);
      write_both(12'h00c,32'd2); // Receive abort must not stop peer's source.
      wait(&irq);
      if (session_active != 3 || endpoint[0].dut.aggregate_summary[7:0] != 2)
        $fatal(1,"receive abort incorrectly stopped independent TX");
      write_both(12'h100,32'd2);
      if (session_active) $fatal(1,"post-abort TX stop failed");
      write_both(12'h10c,32'd0);
      write_both(12'h100,32'd1);
      if (session_active || !endpoint[0].dut.session_rejected) $fatal(1,"zero lease accepted");
      write_both(12'h10c,32'd86400001);
      write_both(12'h100,32'd1);
      if (session_active || !endpoint[0].dut.session_rejected) $fatal(1,"over-limit lease accepted");
      $display("PASS: v5 independent sessions cover staggered RX, reject busy stop/renewal, expire, preserve results");
      $display("PASS: missing RX clock expiry publishes failure; platform fault and reset stop TX");
      $display("PASS: v5 PMA compatibility and receive-abort/TX-session independence");
    end else
      $display("PASS: v4 dual-endpoint stop race reproduced; early receiver clean, late receiver errors");
    $finish;
  end
  initial begin #20000; $fatal(1,"dual endpoint simulation timeout"); end
endmodule
