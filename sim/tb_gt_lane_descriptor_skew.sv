`timescale 1ns/1ps
// Diagnostic reproducer, NOT a passing CDC qualification regression.
// Model a single extra first-stage capture cycle for descriptor_selected.
// RTL simulation does not model analog metastability; this tests its logical
// consequence when independently synchronized control/data arrive differently.
module tb_gt_lane_descriptor_skew;
  logic clk = 0, reset = 1, selected = 0, start = 0;
  wire ack, running;
  wire [2:0] tx_select, rx_select;
  always #1.5 clk = ~clk;
  gt_lane_engine #(.LANE_ID(12)) dut (
    .rx_clk(clk), .protocol_reset(reset), .rx_reset(1'b0),
    .start_req_toggle(start), .stop_req_toggle(1'b0),
    .descriptor_selected(selected), .descriptor_prbs_mode(3'd5),
    .measurement_enable(1'b0), .controls_enable(1'b1),
    .start_ack_toggle(ack), .stop_ack_toggle(), .snapshot_send(),
    .snapshot_rcv(1'b0), .rx_prbs_locked(1'b1), .rx_cdr_locked(1'b1),
    .rx_prbs_errors(16'd0), .tx_prbs_select(tx_select),
    .rx_prbs_select(rx_select), .prbs_counter_reset(), .running(running),
    .snapshot_id_status(), .snapshot_errors(), .snapshot_tested_bits(),
    .snapshot_lock_losses(), .snapshot_valid_cycles()
  );
  task automatic prepare;
    @(negedge clk); reset = 1; selected = 0; start = 0;
    repeat (4) @(negedge clk);
    reset = 0;
    repeat (5) @(negedge clk);
  endtask
  initial begin
    prepare();
    selected = 1; start = 1;
    repeat (8) @(negedge clk);
    if (!ack || !running || tx_select != 5) $fatal(1, "zero-skew control failed");
    $display("CONTROL: zero-skew descriptor selected lane 12");
    prepare();
    selected = 1; start = 1;
    force dut.selected_meta = 1'b0;
    @(negedge clk);
    release dut.selected_meta;
    repeat (8) @(negedge clk);
    if (!ack || running || tx_select != 0 || rx_select != 0 || !dut.selected_sync)
      $fatal(1, "expected stale-selection signature was not reproduced");
    $display("REPRODUCED: start acknowledged while lane remains unselected after one-cycle descriptor skew");
    $finish;
  end
  initial begin #1000; $fatal(1, "watchdog"); end
endmodule
