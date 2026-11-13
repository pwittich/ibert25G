`timescale 1ns/1ps

// V3-specific implementation; historical modules remain unchanged at 34c73bb.

// Atomic management-domain configuration. Requested masks are stable for the
// entire application epoch. Completion includes local CDC/re-arm acknowledgements.
module all_links_v3_config #(
  parameter integer APPLY_TIMEOUT_CYCLES = 200000000
) (
  input wire clk, resetn, eligible, barrier_clear,
  input wire write,
  input wire [11:0] address,
  input wire [31:0] data,
  input wire [3:0] strobe,
  input wire [27:0] tx_observed, rx_observed,
  input wire [27:0] epoch_ack,
  input wire application_settled,
  output logic [27:0] tx_mask = 0, rx_mask = 0,
  output logic epoch = 0,
  output wire busy, usable,
  output wire [255:0] record
);
  logic [31:0] staged_tx = 0, staged_rx = 0;
  logic [31:0] generation = 0, counter = 0, error = 0;
  // 0=boot, 1=re-arm, 2=applied, 3=failed, 4=drain, 5=release.
  (* fsm_encoding = "none" *) logic [2:0] state = 0;
  assign busy = state == 1 || state == 4 || state == 5;
  assign usable = state == 2;
  wire settled = application_settled && barrier_clear;
  assign record = {error, {23'd0,eligible,5'd0,state}, generation,
                   {4'd0,rx_observed}, {4'd0,tx_observed},
                   {4'd0,rx_mask}, {4'd0,tx_mask}, 32'h51430001};
  always_ff @(posedge clk) begin
    if (!resetn) begin
      staged_tx <= 0; staged_rx <= 0;
      tx_mask <= 0; rx_mask <= 0; epoch <= 0;
      state <= 0; counter <= 0; generation <= 0; error <= 0;
    end else begin
      if (busy) begin
        // Require bank distribution and return synchronizers to advance before
        // accepting equality, including an all-zero configuration.
        if (counter >= 16 && settled) begin
          if (state == 4) begin state <= 1; epoch <= 1; end
          else if (state == 1) begin state <= 5; epoch <= 0; end
          else begin state <= 2; generation <= generation + 1'b1; error <= 0; end
        end else if (counter == APPLY_TIMEOUT_CYCLES-1) begin
          state <= 3; tx_mask <= 0; rx_mask <= 0; epoch <= 0; error <= 2;
        end else counter <= counter + 1'b1;
      end
      if (write && address >= 12'h120 && address <= 12'h128) begin
        if (strobe != 4'hf || !eligible || busy) error <= 1;
        else case (address)
          12'h120: staged_tx <= data;
          12'h124: staged_rx <= data;
          12'h128: begin
            if (data != 1 || staged_tx[31:28] != 0 || staged_rx[31:28] != 0)
              error <= 1;
            else begin
              tx_mask <= staged_tx[27:0]; rx_mask <= staged_rx[27:0];
              epoch <= 0; state <= 4; counter <= 0; error <= 0;
            end
          end
          default: ;
        endcase
      end
    end
  end
endmodule
