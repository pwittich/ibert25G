`timescale 1ns/1ps

module tb_gt_lane_engine_restart;
  logic clk = 0;
  logic rx_reset = 1;
  logic protocol_reset = 1;
  logic start_req = 0;
  logic stop_req = 0;
  logic selected = 1;
  logic [2:0] prbs_mode = 3'd5;
  logic controls_enable = 0;
  logic snapshot_rcv = 0;
  logic clock_enabled = 1;
  wire start_ack, stop_ack, snapshot_send;
  wire [2:0] tx_select, rx_select;
  wire counter_reset, running;

  always #1.5 if (clock_enabled) clk = ~clk;

  gt_lane_engine #(.LANE_ID(12)) dut (
    .start_req_toggle(start_req), .stop_req_toggle(stop_req),
    .descriptor_selected(selected), .descriptor_prbs_mode(prbs_mode),
    .measurement_enable(1'b0), .controls_enable(controls_enable),
    .start_ack_toggle(start_ack), .stop_ack_toggle(stop_ack),
    .snapshot_send(snapshot_send), .snapshot_rcv(snapshot_rcv),
    .rx_clk(clk), .protocol_reset(protocol_reset),
    .rx_reset(rx_reset), .rx_prbs_locked(1'b1),
    .rx_cdr_locked(1'b1), .rx_prbs_errors(16'd0),
    .tx_prbs_select(tx_select), .rx_prbs_select(rx_select),
    .prbs_counter_reset(counter_reset), .running(running),
    .snapshot_id_status(), .snapshot_errors(), .snapshot_tested_bits(),
    .snapshot_lock_losses(), .snapshot_valid_cycles()
  );

  task automatic wait_for_start(input logic phase);
    repeat (12) begin
      @(posedge clk);
      #0.1;
      if (start_ack == phase && running && tx_select == 3'd5 &&
          rx_select == 3'd5)
        return;
    end
    $fatal(1, "start phase %0d was not accepted", phase);
  endtask

  task automatic verify_restart_rearm(input logic phase);
    rx_reset = 1;
    repeat (3) @(posedge clk);
    #0.1;
    if (!running || start_ack != phase || tx_select != 0 || rx_select != 0 ||
        !counter_reset)
      $fatal(1, "restart did not clear controls while preserving phase %0d",
             phase);
    rx_reset = 0;
    repeat (2) @(posedge clk);
    #0.1;
    if (!running || start_ack != phase || tx_select != 3'd5 ||
        rx_select != 3'd5)
      $fatal(1, "restart did not rearm phase %0d", phase);
  endtask

  task automatic stop_phase(input logic phase);
    stop_req = phase;
    wait (snapshot_send);
    @(negedge clk);
    // Recovery during a pending snapshot must retain the payload/handshake
    // even though running has already gone low.
    rx_reset = 1;
    repeat (3) @(negedge clk);
    if (!snapshot_send || start_ack != phase)
      $fatal(1, "stopped-lane recovery destroyed snapshot or start phase");
    clock_enabled = 0;
    #30;
    rx_reset = 0;
    #12;
    clock_enabled = 1;
    repeat (3) @(negedge clk);
    snapshot_rcv = 1;
    @(posedge clk);
    #0.1;
    snapshot_rcv = 0;
    wait (stop_ack == phase);
    if (running)
      $fatal(1, "lane remained running after stop phase %0d", phase);
  endtask

  initial begin
    repeat (3) @(posedge clk);
    @(negedge clk);
    protocol_reset = 0;
    rx_reset = 0;
    controls_enable = 1;

    start_req = 1;
    wait_for_start(1);
    verify_restart_rearm(1);
    stop_phase(1);

    // The second request returns the toggle to zero. This was the exact phase
    // that v2.5.16 lost when acquisition recovery reset start_seen to zero.
    start_req = 0;
    wait_for_start(0);
    verify_restart_rearm(0);
    stop_phase(0);

    // Unselected lanes still participate in both handshake phases.
    selected = 0;
    start_req = 1;
    repeat (8) @(negedge clk);
    rx_reset = 1;
    repeat (3) @(negedge clk);
    rx_reset = 0;
    repeat (4) @(negedge clk);
    if (start_ack != 1 || running || tx_select != 0)
      $fatal(1, "unselected recovery lost protocol phase");
    stop_phase(1);
    selected = 1;
    start_req = 0;
    wait_for_start(0);
    stop_phase(0);

    $display("PASS: lane restart rearm preserves odd and even toggle phases");
    $finish;
  end

  initial begin
    repeat (300) @(posedge clk);
    $fatal(1, "lane restart-rearm testbench watchdog expired");
  end
endmodule
