`timescale 1ns/1ps

module tb_gt_quad_controller;
  logic clk = 0;
  logic resetn = 0;
  logic [3:0] powergood = 0;
  logic qpll_lock = 0;
  logic tx_active = 0, rx_active = 0;
  logic runtime_reset = 0;
  logic [3:0] txdone = 0, rxdone = 0;
  wire reset_all, ready, fault;
  wire [7:0] fault_reason;
  wire [2:0] state;

  always #2.5 clk = ~clk;

  gt_quad_controller #(
    .RESET_HOLD_CYCLES(4), .INIT_TIMEOUT_CYCLES(12)
  ) dut (
    .mgmt_clk(clk), .resetn(resetn),
    .gtpowergood_async(powergood), .qpll0lock_async(qpll_lock),
    .tx_userclk_active_async(tx_active),
    .rx_userclk_active_async(rx_active),
    .txresetdone_async(txdone), .rxresetdone_async(rxdone),
    .runtime_rx_reset_active(runtime_reset),
    .gtwiz_reset_all(reset_all), .quad_ready(ready),
    .quad_fault(fault), .fault_reason(fault_reason), .state(state)
  );

  initial begin
    repeat (3) @(posedge clk);
    resetn <= 1;
    repeat (5) @(posedge clk);
    if (reset_all) $fatal(1, "reset hold did not release");

    powergood <= 4'hf;
    repeat (4) @(posedge clk);
    qpll_lock <= 1;
    repeat (4) @(posedge clk);
    txdone <= 4'hf;
    rxdone <= 4'hf;
    tx_active <= 1;
    rx_active <= 1;
    repeat (5) @(posedge clk);
    if (!ready || fault || state != 3'd4)
      $fatal(1, "quad did not reach READY");

    // An intentional RX reset may finish in a different synchronizer cycle
    // than RX user-clock-active/reset-done. Keep the lane domain released
    // while the supervisor waits for those status bits to catch up.
    runtime_reset <= 1;
    rx_active <= 0;
    rxdone <= 0;
    repeat (5) @(posedge clk);
    runtime_reset <= 0;
    repeat (5) @(posedge clk);
    if (!ready || fault || reset_all || state != 3'd6)
      $fatal(1, "post-reset RX skew was treated as a fatal loss");
    rx_active <= 1;
    rxdone <= 4'hf;
    repeat (5) @(posedge clk);
    if (!ready || fault || state != 3'd4)
      $fatal(1, "RX status did not requalify after intentional reset");

    // The same RX loss outside an intentional reset remains immediately
    // fatal and records the exact failed qualification.
    rx_active <= 0;
    repeat (5) @(posedge clk);
    if (ready || !fault || !reset_all || state != 3'd5 ||
        fault_reason != 8'h10)
      $fatal(1, "unexpected RX user-clock loss did not latch cause");

    resetn <= 0;
    repeat (2) @(posedge clk);
    if (ready || fault || !reset_all || state != 3'd0 || fault_reason != 0)
      $fatal(1, "system reset did not clear RX fault state");

    rx_active <= 1;
    resetn <= 1;
    repeat (16) @(posedge clk);
    if (!ready || fault || state != 3'd4)
      $fatal(1, "quad did not reinitialize for QPLL-loss test");

    qpll_lock <= 0;
    repeat (6) @(posedge clk);
    if (ready || !fault || !reset_all || state != 3'd5 ||
        fault_reason != 8'h02)
      $fatal(1, "QPLL loss did not latch fatal reset");

    resetn <= 0;
    repeat (2) @(posedge clk);
    if (ready || fault || !reset_all || state != 3'd0 || fault_reason != 0)
      $fatal(1, "system reset did not clear latched fault");

    $display("PASS: quad reset, RX requalification, and fatal-cause latching");
    $finish;
  end
endmodule
