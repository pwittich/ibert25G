`timescale 1ns/1ps

// Characterization only: native RX-clock pulse statistics with an atomic XPM
// handoff at measurement end. No event threshold or automatic recovery here.
module gt_rx_error_profile (
  input wire mgmt_clk, resetn, rx_clk, measurement_enable,
  input wire measurement_run_toggle, rx_error,
  output wire [255:0] diagnostics
);
  (* ASYNC_REG = "TRUE" *) logic [1:0] reset_pipe = 3;
  (* ASYNC_REG = "TRUE" *) logic measure_meta = 0, measure_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic run_meta = 0, run_sync = 0;
  logic measure_previous = 0, error_q = 0;
  logic active = 0, active_epoch = 0, completed_epoch = 0;
  logic [31:0] elapsed = 0, errors = 0, streak = 0, maximum = 0;
  logic [31:0] first_error = 0, last_error = 0;
  logic [191:0] snapshot = 0;
  logic send = 0;
  wire received, valid_pulse;
  wire [191:0] captured;
  logic valid = 0, mgmt_run_previous = 0;
  function automatic [31:0] inc(input [31:0] n);
    inc = (&n) ? n : n + 1'b1;
  endfunction
  always_ff @(posedge rx_clk or negedge resetn) begin
    if (!resetn) reset_pipe <= 3;
    else reset_pipe <= {reset_pipe[0], 1'b0};
  end
  always_ff @(posedge rx_clk) begin
    if (reset_pipe[1]) begin
      measure_meta <= 0; measure_sync <= 0; measure_previous <= 0;
      run_meta <= 0; run_sync <= 0;
      active <= 0; active_epoch <= 0; completed_epoch <= 0;
      error_q <= 0; elapsed <= 0; errors <= 0; streak <= 0; maximum <= 0;
      first_error <= 0; last_error <= 0; send <= 0; snapshot <= 0;
    end else begin
      measure_meta <= measurement_enable; measure_sync <= measure_meta;
      run_meta <= measurement_run_toggle; run_sync <= run_meta;
      measure_previous <= measure_sync; error_q <= rx_error;
      // A fresh accepted-request epoch arms exactly one profile. A later
      // measurement pulse in the same epoch cannot clear or replace it.
      if (measure_sync && !measure_previous && !active &&
          run_sync != completed_epoch) begin
        active <= 1;
        active_epoch <= run_sync;
        elapsed <= 0; errors <= 0; streak <= 0; maximum <= 0;
        first_error <= 0; last_error <= 0;
      end else if (measure_sync && active) begin
        elapsed <= inc(elapsed);
        if (error_q) begin
          errors <= inc(errors); streak <= inc(streak);
          if (inc(streak) > maximum) maximum <= inc(streak);
          if (errors == 0) first_error <= elapsed;
          last_error <= elapsed;
        end else streak <= 0;
      end
      if (!measure_sync && measure_previous && active) begin
        snapshot <= {last_error, first_error, maximum, errors, elapsed, 32'h4552_0001};
        send <= 1;
        active <= 0;
        completed_epoch <= active_epoch;
      end else if (send && received) send <= 0;
    end
  end
  xpm_cdc_handshake #(.DEST_EXT_HSK(0), .DEST_SYNC_FF(2), .SRC_SYNC_FF(2),
    .INIT_SYNC_FF(0), .SIM_ASSERT_CHK(1), .WIDTH(192)) transfer (
    .src_clk(rx_clk), .src_in(snapshot), .src_send(send), .src_rcv(received),
    .dest_clk(mgmt_clk), .dest_out(captured), .dest_req(valid_pulse), .dest_ack(1'b0)
  );
  always_ff @(posedge mgmt_clk) begin
    if (!resetn) begin valid <= 0; mgmt_run_previous <= 0; end
    else begin
      mgmt_run_previous <= measurement_run_toggle;
      if (measurement_run_toggle != mgmt_run_previous) valid <= 0;
      else if (valid_pulse) valid <= 1;
    end
  end
  assign diagnostics = {32'd0, 31'd0, valid, captured};
endmodule
