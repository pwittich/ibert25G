`timescale 1ns/1ps

// Management-domain transition recorder. Samples must already be synchronized.
// Freeze after fault or after a run and its cleanup both reach IDLE. The next
// acquisition starts a fresh epoch; software must dump before the next command.
module gt_transition_trace #(parameter integer ADDR_WIDTH = 6) (
  input wire clk, resetn, acquisition_active, engine_busy, controller_idle, fault,
  input wire [191:0] sample,
  input wire [ADDR_WIDTH-1:0] read_index,
  output wire [255:0] record,
  output wire [255:0] metadata
);
  localparam integer DEPTH = 1 << ADDR_WIDTH;
  (* ram_style = "distributed" *) logic [255:0] entries [0:DEPTH-1];
  logic [191:0] previous_sample = 0;
  logic [63:0] timestamp = 0;
  logic [31:0] epoch = 0, events = 0;
  logic [ADDR_WIDTH-1:0] next_index = 0;
  logic [ADDR_WIDTH:0] count = 0;
  logic active = 0, previous_acquire = 0, seen_busy = 0;
  wire begin_epoch = acquisition_active && !previous_acquire;
  wire finish_epoch = fault || (seen_busy && !engine_busy && controller_idle);
  wire write_entry = resetn && (begin_epoch ||
                    (active && (sample != previous_sample || finish_epoch)));
  wire [ADDR_WIDTH-1:0] write_index = begin_epoch ? 0 : next_index;
  wire [8:0] meta_count = count;
  wire [7:0] meta_next = next_index;
  // One write port with a selected address permits actual LUTRAM inference.
  always_ff @(posedge clk)
    if (write_entry) entries[write_index] <= {sample, begin_epoch ? 64'd0 : timestamp};
  assign record = (count == DEPTH || read_index < count) ? entries[read_index] : 256'd0;
  assign metadata = ADDR_WIDTH == 6 ? {128'd0, events, epoch,
    16'd0, active, (events > DEPTH), count[6:0], next_index[5:0], 1'b0, 32'h5452_0001} :
    {128'd0, events, epoch, 12'd0, active, (events > DEPTH), meta_count, meta_next,
      1'b0, 32'h5452_0002};
  always_ff @(posedge clk) begin
    if (!resetn) begin
      previous_sample <= 0; timestamp <= 0; epoch <= 0; events <= 0;
      next_index <= 0; count <= 0; active <= 0;
      previous_acquire <= 0; seen_busy <= 0;
    end else begin
      previous_acquire <= acquisition_active;
      if (begin_epoch) begin
        epoch <= epoch + 1'b1; timestamp <= 1;
        previous_sample <= sample;
        events <= 1; count <= 1; next_index <= 1; active <= 1; seen_busy <= 1;
      end else if (active) begin
        timestamp <= timestamp + 1'b1;
        if (sample != previous_sample || fault ||
            (seen_busy && !engine_busy && controller_idle)) begin
          next_index <= next_index + 1'b1;
          if (count < DEPTH) count <= count + 1'b1;
          if (!(&events)) events <= events + 1'b1;
          previous_sample <= sample;
        end
        if (fault || (seen_busy && !engine_busy && controller_idle)) active <= 0;
      end
    end
  end
endmodule
