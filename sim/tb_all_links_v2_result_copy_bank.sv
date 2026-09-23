`timescale 1ns/1ps

module tb_all_links_v2_result_copy_bank;
  logic clk = 0;
  logic load_selector = 0, capture_record = 0;
  logic [6:0] global_lane = 0;
  logic platform_failed = 0;
  logic [111:0] active = '1, exact_valid = '0, exact_saturated = '0;
  logic [112*32-1:0] exact_counts = '0;
  logic [112*256-1:0] snapshots = '0;
  wire [1023:0] records;
  wire [3:0] mismatches;

  always #1 clk = ~clk;

`define BANK(NAME, P_FIRST, P_COUNT, P_INDEX) \
  all_links_v2_result_copy_bank #(.FIRST(P_FIRST), .COUNT(P_COUNT)) NAME ( \
    .clk(clk), .load_selector(load_selector), \
    .capture_record(capture_record), .global_lane(global_lane), \
    .platform_failed(platform_failed), \
    .left_active(active[P_FIRST +: P_COUNT]), \
    .right_active(active[56+P_FIRST +: P_COUNT]), \
    .left_exact_valid(exact_valid[P_FIRST +: P_COUNT]), \
    .right_exact_valid(exact_valid[56+P_FIRST +: P_COUNT]), \
    .left_exact_saturated(exact_saturated[P_FIRST +: P_COUNT]), \
    .right_exact_saturated(exact_saturated[56+P_FIRST +: P_COUNT]), \
    .left_exact_counts(exact_counts[P_FIRST*32 +: P_COUNT*32]), \
    .right_exact_counts(exact_counts[(56+P_FIRST)*32 +: P_COUNT*32]), \
    .left_snapshot(snapshots[P_FIRST*256 +: P_COUNT*256]), \
    .right_snapshot(snapshots[(56+P_FIRST)*256 +: P_COUNT*256]), \
    .record_stage(records[P_INDEX*256 +: 256]), \
    .mismatch_stage(mismatches[P_INDEX]));
  `BANK(b0, 0, 12, 0)
  `BANK(b1, 12, 16, 1)
  `BANK(b2, 28, 16, 2)
  `BANK(b3, 44, 12, 3)
`undef BANK

  function automatic integer bank_for_lane(input integer lane);
    integer local_lane;
    begin
      local_lane = lane >= 56 ? lane - 56 : lane;
      bank_for_lane = local_lane < 12 ? 0 : local_lane < 28 ? 1 :
                      local_lane < 44 ? 2 : 3;
    end
  endfunction

  task automatic capture(input integer lane);
    begin
      @(negedge clk); global_lane = lane; load_selector = 1;
      @(posedge clk); #0.1;
      @(negedge clk); load_selector = 0;
      @(posedge clk); #0.1;
      @(negedge clk); capture_record = 1;
      @(posedge clk); #0.1;
      @(negedge clk); capture_record = 0;
    end
  endtask

  integer lane, bank;
  logic [255:0] expected;
  initial begin
    for (lane = 0; lane < 112; lane = lane + 1) begin
      snapshots[lane*256 +: 256] = {64'hfeed_0000_0000_0000,
                                    64'hdead_0000_0000_0000,
                                    32'hcafe_0000,
                                    64'(lane + 1000),
                                    (32'h0000_1800 | lane)};
    end

    // Exercise every lane, including all seven left/right bank boundaries.
    for (lane = 0; lane < 112; lane = lane + 1) begin
      capture(lane);
      bank = bank_for_lane(lane);
      expected = snapshots[lane*256 +: 256];
      if (records[bank*256 +: 256] !== expected || mismatches[bank] !== 1'b0)
        $fatal(1, "lane %0d copied incorrectly from bank %0d", lane, bank);
    end

    // Exact-error replacement and saturation retain the established ABI.
    lane = 83;
    exact_valid[lane] = 1;
    exact_saturated[lane] = 1;
    exact_counts[lane*32 +: 32] = 32'h1234_5678;
    capture(lane);
    bank = bank_for_lane(lane);
    expected = snapshots[lane*256 +: 256];
    expected[95:32] = 64'h0000_0000_1234_5678;
    expected[31:0] = (expected[31:0] & 32'hffff_bfff) | 32'h0000_4000;
    if (records[bank*256 +: 256] !== expected)
      $fatal(1, "exact-error overlay changed");
    exact_valid[lane] = 0;
    exact_saturated[lane] = 0;

    // One forced descriptor mismatch in each SLR bank must publish the same
    // deterministic failed-platform record and raise the staged mismatch.
    for (bank = 0; bank < 4; bank = bank + 1) begin
      case (bank)
        0: lane = 11;
        1: lane = 27;
        2: lane = 43;
        default: lane = 55;
      endcase
      snapshots[lane*256 + 11] = 0;
      capture(lane);
      if (mismatches[bank] !== 1'b1 ||
          records[bank*256 +: 32] !== (32'h0000_2800 | lane))
        $fatal(1, "bank %0d mismatch publication changed", bank);
      snapshots[lane*256 + 11] = 1;
    end

    // A platform failure uses the same record but is not a descriptor error.
    platform_failed = 1;
    lane = 100;
    capture(lane);
    bank = bank_for_lane(lane);
    if (mismatches[bank] !== 1'b0 ||
        records[bank*256 +: 32] !== (32'h0000_2800 | lane))
      $fatal(1, "platform-failure publication changed");

    $display("PASS: all 112 result-copy lanes, bank boundaries, exact errors, and failure semantics");
    $finish;
  end
endmodule
