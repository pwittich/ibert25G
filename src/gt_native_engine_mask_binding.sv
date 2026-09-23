`timescale 1ns/1ps

// Explicit native-engine mask contract.  A versioned engine wrapper feeds its
// editable descriptor mask while IDLE and its frozen execution mask while
// RUN; no historical engine interface is changed by this proof-stage block.
module gt_native_engine_mask_binding #(
  parameter int unsigned LANES = 112
) (
  input wire engine_busy,
  input wire [LANES-1:0] descriptor_lane_mask,
  input wire [LANES-1:0] frozen_active_lane_mask,
  output wire [LANES-1:0] selected_lanes
);
  assign selected_lanes = engine_busy ? frozen_active_lane_mask : descriptor_lane_mask;
endmodule
