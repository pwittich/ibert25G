`timescale 1ns/1ps
module tb_gt_lane_descriptor_transfer;
  logic clk = 0, clock_enabled = 1, reset = 1, rx_reset = 0;
  logic selected = 0, start = 0, stop = 0, rcv = 0;
  logic [2:0] mode = 2;
  logic held_selected;
  logic [2:0] held_mode;
  logic [2:0] skewed_mode;
  wire ack, stop_ack, running, send;
  wire [2:0] tx_select, rx_select;
  wire [31:0] status;
  always #1.5 if (clock_enabled) clk = ~clk;
  gt_lane_engine #(.LANE_ID(12)) dut (
    .rx_clk(clk), .protocol_reset(reset), .rx_reset(rx_reset),
    .start_req_toggle(start), .stop_req_toggle(stop),
    .descriptor_selected(selected), .descriptor_prbs_mode(mode),
    .measurement_enable(1'b0), .controls_enable(1'b1),
    .start_ack_toggle(ack), .stop_ack_toggle(stop_ack), .snapshot_send(send),
    .snapshot_rcv(rcv), .rx_prbs_locked(1'b1), .rx_cdr_locked(1'b1),
    .rx_prbs_errors(16'd0), .tx_prbs_select(tx_select),
    .rx_prbs_select(rx_select), .prbs_counter_reset(), .running(running),
    .snapshot_id_status(status), .snapshot_errors(), .snapshot_tested_bits(),
    .snapshot_lock_losses(), .snapshot_valid_cycles()
  );
  initial begin
    repeat (4) @(negedge clk); reset = 0;
    repeat (8) @(negedge clk);
    // Each bit gets 1- and 2-cycle delay, both phases and selection edges.
    for (integer n = 0; n < 16; n++) begin
      held_selected = selected; held_mode = mode;
      selected = !selected; mode = mode ^ 3'b111; start = !start;
      skewed_mode = mode;
      if ((n / 2) % 4 != 0)
        skewed_mode[((n / 2) % 4)-1] = held_mode[((n / 2) % 4)-1];
      case ((n / 2) % 4)
        0: force dut.selected_meta = held_selected;
        default: force dut.prbs_meta = skewed_mode;
      endcase
      if (n % 3 == 0) begin
        clock_enabled = 0; #30;
        if (ack == start) $fatal(1, "ack advanced without RX clock");
        clock_enabled = 1;
      end
      repeat (1 + n / 8) @(negedge clk);
      case ((n / 2) % 4)
        0: release dut.selected_meta;
        default: release dut.prbs_meta;
      endcase
      wait (ack == start); @(negedge clk);
      if (running != selected || dut.accepted_prbs_mode != mode ||
          tx_select != (selected ? mode : 0) || rx_select != tx_select)
        $fatal(1, "descriptor capture failed case %0d", n);
      // Recovery must retain the accepted descriptor and toggle phase.
      rx_reset = 1; repeat (3) @(negedge clk);
      clock_enabled = 0; #15; rx_reset = 0; #15; clock_enabled = 1;
      repeat (4) @(negedge clk);
      if (ack != start || running != selected || tx_select != (selected ? mode : 0))
        $fatal(1, "recovery changed descriptor case %0d", n);
      stop = !stop; wait (send); @(negedge clk);
      if (status[11] != selected) $fatal(1, "snapshot selected mismatch");
      rcv = 1; wait (stop_ack == stop); @(negedge clk); rcv = 0;
      repeat (8) @(negedge clk);
    end
    // Stop arriving before the start acknowledgement must still snapshot the
    // accepted descriptor, not an old selection or a second start event.
    selected = 1; mode = 5; start = !start;
    @(negedge clk); stop = !stop;
    wait (send); @(negedge clk);
    if (ack != start || !status[11] || running)
      $fatal(1, "early stop overtook descriptor capture");
    rcv = 1; wait (stop_ack == stop); @(negedge clk); rcv = 0;
    $display("PASS: descriptor per-bit skew, both phases, clock pause, recovery and early stop");
    $finish;
  end
  initial begin #20000; $fatal(1, "descriptor watchdog"); end
endmodule
