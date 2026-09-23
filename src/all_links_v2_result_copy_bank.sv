`timescale 1ns/1ps

// V2-only SLR-local first stage for the 112-lane result-copy mux.  Each
// instance owns matching left/right lane ranges in one physical SLR.  The
// selector is registered before the local mux is sampled; a later central
// four-to-one stage preserves atomic hidden-bank publication.
module all_links_v2_result_copy_bank #(
  parameter integer FIRST = 0,
  parameter integer COUNT = 12
) (
  input  wire                   clk,
  input  wire                   load_selector,
  input  wire                   capture_record,
  input  wire [6:0]             global_lane,
  input  wire                   platform_failed,
  input  wire [COUNT-1:0]       left_active, right_active,
  input  wire [COUNT-1:0]       left_exact_valid, right_exact_valid,
  input  wire [COUNT-1:0]       left_exact_saturated, right_exact_saturated,
  input  wire [COUNT*32-1:0]    left_exact_counts, right_exact_counts,
  input  wire [COUNT*256-1:0]   left_snapshot, right_snapshot,
  output logic [255:0]          record_stage = 0,
  output logic                  mismatch_stage = 0
);
  logic select_right = 1'b0;
  logic [$clog2(COUNT)-1:0] local_lane = '0;
  logic [6:0] selected_global_lane = '0;

  always_ff @(posedge clk) begin
    if (load_selector) begin
      select_right <= global_lane >= 56;
      selected_global_lane <= global_lane;
      if (global_lane >= 56)
        local_lane <= global_lane - (56 + FIRST);
      else
        local_lane <= global_lane - FIRST;
    end
  end

  wire [255:0] selected_snapshot = select_right
    ? right_snapshot[local_lane*256 +: 256]
    : left_snapshot[local_lane*256 +: 256];
  wire selected_active = select_right
    ? right_active[local_lane] : left_active[local_lane];
  wire selected_exact_valid = select_right
    ? right_exact_valid[local_lane] : left_exact_valid[local_lane];
  wire selected_exact_saturated = select_right
    ? right_exact_saturated[local_lane] : left_exact_saturated[local_lane];
  wire [31:0] selected_exact_count = select_right
    ? right_exact_counts[local_lane*32 +: 32]
    : left_exact_counts[local_lane*32 +: 32];
  wire [31:0] measured_status = selected_exact_valid
    ? ((selected_snapshot[31:0] & 32'hffff_bfff) |
       {17'd0, selected_exact_saturated, 14'd0})
    : selected_snapshot[31:0];
  wire [63:0] measured_errors = selected_exact_valid
    ? {32'd0, selected_exact_count} : selected_snapshot[32 +: 64];
  wire [255:0] measured_record = {
    selected_snapshot[96 +: 160], measured_errors, measured_status
  };
  wire selected_mismatch = measured_record[11] != selected_active;
  wire [31:0] platform_failure_status =
    32'h0000_2800 | {24'd0, selected_global_lane};
  wire [255:0] platform_failure_record = {
    64'd0, 32'd1, 64'd0, 64'd0, platform_failure_status
  };
  wire [255:0] selected_record =
    ((platform_failed || selected_mismatch) && selected_active)
      ? platform_failure_record : measured_record;

  always_ff @(posedge clk) begin
    if (capture_record) begin
      record_stage <= selected_record;
      mismatch_stage <= !platform_failed && selected_mismatch;
    end
  end
endmodule
