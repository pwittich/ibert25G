`timescale 1ns/1ps

// SLR-local configuration acknowledgement, tagged with the phase actually
// compared. The central controller never reduces raw remote-quad status.
module all_links_v3_config_ack_bank #(
  parameter integer QUADS = 3
) (
  input wire clk, epoch,
  input wire [QUADS-1:0] left_tx, right_tx, left_rx, right_rx,
  input wire [QUADS-1:0] left_tx_observed, right_tx_observed,
  input wire [QUADS*4-1:0] left_rx_ack, right_rx_ack,
  (* KEEP = "TRUE" *) output logic group_ok = 0, group_phase = 0,
  output wire [QUADS-1:0] left_rx_observed, right_rx_observed,
  output wire [QUADS-1:0] left_lane_enable, right_lane_enable,
  output wire [QUADS-1:0] left_lane_epoch, right_lane_epoch
);
  (* KEEP = "TRUE" *) logic [QUADS-1:0] left_expected_tx = 0, right_expected_tx = 0;
  (* KEEP = "TRUE" *) logic [QUADS-1:0] left_expected_rx = 0, right_expected_rx = 0;
  (* KEEP = "TRUE" *) logic [QUADS-1:0] left_expected_epoch = 0, right_expected_epoch = 0;
  assign left_lane_enable=left_expected_rx;assign right_lane_enable=right_expected_rx;
  assign left_lane_epoch=left_expected_epoch;assign right_lane_epoch=right_expected_epoch;
  logic [QUADS-1:0] left_rx_ok, right_rx_ok;
  always_comb begin
    for(integer q=0;q<QUADS;q=q+1) begin
      left_rx_ok[q] = !left_expected_rx[q] || left_rx_ack[q*4 +: 4] == {4{left_expected_epoch[q]}};
      right_rx_ok[q] = !right_expected_rx[q] || right_rx_ack[q*4 +: 4] == {4{right_expected_epoch[q]}};
    end
  end
  assign left_rx_observed = left_expected_rx & left_rx_ok;
  assign right_rx_observed = right_expected_rx & right_rx_ok;
  always_ff @(posedge clk) begin
    left_expected_tx <= left_tx; right_expected_tx <= right_tx;
    left_expected_rx <= left_rx; right_expected_rx <= right_rx;
    left_expected_epoch <= {QUADS{epoch}}; right_expected_epoch <= {QUADS{epoch}};
    group_phase <= left_expected_epoch[0];
    group_ok <= left_tx_observed == left_expected_tx &&
                right_tx_observed == right_expected_tx &&
                (&left_rx_ok) && (&right_rx_ok) &&
                left_expected_epoch == {QUADS{left_expected_epoch[0]}} &&
                right_expected_epoch == {QUADS{left_expected_epoch[0]}};
  end
endmodule
