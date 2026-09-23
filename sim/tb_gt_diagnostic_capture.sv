`timescale 1ns/1ps
module tb_gt_diagnostic_capture;
  logic clk = 0, rxclk = 0, resetn = 0;
  logic rxclk_enable = 1;
  always #2.5 clk = ~clk;
  always #1.551 if (rxclk_enable) rxclk = ~rxclk;
  logic acquire = 0, busy = 0, idle = 1, fault = 0;
  logic measure = 0, error_input = 0;
  logic measurement_run_toggle = 0;
  logic [191:0] sample = 0;
  logic [5:0] index = 0;
  wire [255:0] record, metadata, profile;
  logic [7:0] large_index = 0;
  wire [255:0] large_record, large_metadata;
  logic [255:0] saved_record;
  gt_transition_trace trace (
    .clk(clk), .resetn(resetn), .acquisition_active(acquire),
    .engine_busy(busy), .controller_idle(idle), .fault(fault),
    .sample(sample), .read_index(index), .record(record), .metadata(metadata)
  );
  gt_rx_error_profile stats (
    .mgmt_clk(clk), .resetn(resetn), .rx_clk(rxclk),
    .measurement_enable(measure),
    .measurement_run_toggle(measurement_run_toggle),
    .rx_error(error_input), .diagnostics(profile)
  );
  gt_transition_trace #(.ADDR_WIDTH(8)) large_trace (
    .clk(clk), .resetn(resetn), .acquisition_active(acquire),
    .engine_busy(busy), .controller_idle(idle), .fault(fault),
    .sample(sample), .read_index(large_index), .record(large_record), .metadata(large_metadata)
  );
  initial begin
    repeat (5) @(negedge clk); resetn = 1;
    acquire = 1; busy = 1; idle = 0;
    repeat (4) @(negedge clk); acquire = 0;
    for (integer i = 1; i < 80; i++) begin
      sample = i; @(negedge clk);
    end
    if (metadata[127:96] != 80 || !metadata[46]) $fatal(1, "trace ring did not wrap");
    fault = 1; @(negedge clk); fault = 0;
    saved_record = record;
    sample = 1000; repeat (4) @(negedge clk);
    if (record !== saved_record || metadata[47]) $fatal(1, "fault did not freeze trace");
    acquire = 1; @(negedge clk); acquire = 0;
    if (metadata[95:64] != 2 || metadata[127:96] != 1)
      $fatal(1, "trace epoch did not rearm");
    busy = 0; idle = 1; @(negedge clk);
    if (metadata[47]) $fatal(1, "idle did not freeze trace");
    busy = 1; idle = 0; acquire = 1; sample = 0;
    @(negedge clk); acquire = 0;
    for (integer n = 1; n < 180; n++) begin
      sample = n; @(negedge clk);
    end
    if (large_metadata[31:0] != 32'h54520002 || large_metadata[127:96] != 180 ||
        large_metadata[50]) $fatal(1, "expanded trace lost pre-overflow history");
    for (integer n = 0; n < 180; n++) begin
      large_index = n; #1;
      if (large_record[255:64] !== n) $fatal(1, "expanded trace slot %0d mismatch", n);
    end
    // Also prove overflow remains explicit and wrap retains the correct data.
    @(negedge clk);
    for (integer n = 180; n < 300; n++) begin
      sample = n; @(negedge clk);
    end
    if (!large_metadata[50] || large_metadata[127:96] != 300)
      $fatal(1, "expanded trace overflow not reported");
    large_index = 43; #1;
    if (large_record[255:64] != 299) $fatal(1, "expanded ring wrap mismatch");
    busy = 0; idle = 1; @(negedge clk);
    if (large_metadata[51]) $fatal(1, "expanded trace did not freeze");
    measurement_run_toggle = ~measurement_run_toggle;
    measure = 1; repeat (12) @(negedge rxclk);
    error_input = 1; repeat (3) @(negedge rxclk);
    error_input = 0; repeat (6) @(negedge rxclk);
    error_input = 1; repeat (4) @(negedge rxclk);
    error_input = 0; repeat (8) @(negedge rxclk);
    measure = 0;
    wait (profile[192]); #1;
    if (profile[31:0] != 32'h45520001 || profile[95:64] != 7 ||
        profile[127:96] != 4 || profile[191:160] <= profile[159:128])
      $fatal(1, "RX-domain burst statistics mismatch %h", profile);
    saved_record = profile;
    repeat (10) @(negedge clk);
    if (profile !== saved_record) $fatal(1, "RX profile was not retained");
    // Reproduce the observed post-run failure mechanism: a short pulse can be
    // sampled by one RX clock, but without a new accepted-request epoch it
    // must neither clear validity nor publish a zero-elapsed replacement.
    @(negedge rxclk);
    #1.3 measure = 1;
    #0.4 measure = 0;
    wait (stats.measure_sync);
    wait (!stats.measure_sync);
    repeat (20) @(negedge clk);
    if (profile !== saved_record)
      $fatal(1, "same-run measurement pulse replaced retained profile");
    measurement_run_toggle = ~measurement_run_toggle;
    rxclk_enable = 0;
    measure = 1;
    repeat (8) @(negedge clk);
    if (profile[192]) $fatal(1, "new epoch did not clear profile validity");
    rxclk_enable = 1;
    repeat (24) @(negedge rxclk);
    if (profile[192]) $fatal(1, "stale profile was marked valid during new run");
    measure = 0; wait (profile[192]); #1;
    if (profile[95:64] != 0 || profile[127:96] != 0)
      $fatal(1, "new clean run retained old error statistics");
    $display("PASS: transition trace wrap/freeze/rearm and atomic native RX burst profile");
    $finish;
  end
  initial begin #100000; $fatal(1, "diagnostic capture watchdog"); end
endmodule
