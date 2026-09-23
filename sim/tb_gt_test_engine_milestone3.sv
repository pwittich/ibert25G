`timescale 1ns/1ps

module tb_gt_test_engine_milestone3 #(
  parameter logic [111:0] MANAGED_MASK = {96'd0, 4'hf, 12'd0},
  parameter logic [31:0] EXPECT_MASK0 = 32'h0000_f000,
  parameter logic [31:0] EXPECT_MASK1 = 32'd0,
  parameter logic [31:0] EXPECT_MASK2 = 32'd0,
  parameter logic [15:0] EXPECT_MASK3 = 16'd0,
  parameter logic [31:0] EXPECT_INJECTION0 = 32'h0000_1000,
  parameter logic [31:0] EXPECT_NORMAL_SUMMARY = 32'h0004_0401,
  parameter logic [31:0] EXPECT_FAULT_SUMMARY = 32'h0400_0404,
  parameter bit LOCALIZE_DESCRIPTOR_CONTROLS = 1'b0,
  parameter bit FULLY_MANAGED = 1'b0,
  parameter bit STOP_AFTER_NORMAL = 1'b0,
  parameter logic [31:0] REQUEST_MASK0 = EXPECT_MASK0,
  parameter logic [31:0] REQUEST_MASK1 = EXPECT_MASK1,
  parameter logic [31:0] REQUEST_MASK2 = EXPECT_MASK2,
  parameter logic [15:0] REQUEST_MASK3 = EXPECT_MASK3,
  parameter logic [31:0] SECOND_MASK0 = EXPECT_MASK0,
  parameter logic [31:0] SECOND_MASK1 = EXPECT_MASK1,
  parameter logic [31:0] SECOND_MASK2 = EXPECT_MASK2,
  parameter logic [15:0] SECOND_MASK3 = EXPECT_MASK3,
  parameter bit SECOND_NORMAL = 1'b0,
  parameter logic [31:0] EXPECT_SECOND_SUMMARY = EXPECT_NORMAL_SUMMARY,
  parameter int unsigned FIRST_MANAGED_LANE = 12
);
  localparam int LANES = 112;
  localparam logic [111:0] SECOND_MASK = {
    SECOND_MASK3, SECOND_MASK2, SECOND_MASK1, SECOND_MASK0
  };

  logic clk = 0;
  logic resetn = 0;
  logic [11:0] awaddr = 0;
  logic awvalid = 0;
  wire awready;
  logic [31:0] wdata = 0;
  logic [3:0] wstrb = 4'hf;
  logic wvalid = 0;
  wire wready;
  wire [1:0] bresp;
  wire bvalid;
  logic bready = 0;
  logic [11:0] araddr = 0;
  logic arvalid = 0;
  wire arready;
  wire [31:0] rdata;
  wire [1:0] rresp;
  wire rvalid;
  logic rready = 0;
  wire interrupt;
  wire status_firmware_alive, status_engine_busy, status_fault;
  logic platform_ready = 1;
  logic platform_fault = 0;
  logic [31:0] platform_status = 0;
  logic [223:0] platform_diagnostics = {
    32'h8000_1234, 32'h6655_4433, 32'h2211_00ff, 32'hdead_beef,
    32'h7654_3210, 32'h89ab_cdef, 32'h1357_9bdf
  };
  tri1 i2c_scl, i2c_sda;
  logic [LANES-1:0] synthetic_lock = {LANES{1'b1}};
  logic [LANES-1:0] synthetic_cdr_lock = {LANES{1'b1}};
  logic [LANES*16-1:0] synthetic_errors = 0;

  gt_test_hardware_shell #(
    .LANES(LANES), .LOCALIZE_DESCRIPTOR_CONTROLS(LOCALIZE_DESCRIPTOR_CONTROLS),
    .MANAGED_LANE_MASK(MANAGED_MASK),
    .ASYNC_SNAPSHOT_MASK(MANAGED_MASK)
  ) dut (
    .clk_200(clk), .resetn(resetn),
    .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid),
    .s_axi_awready(awready), .s_axi_wdata(wdata),
    .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid),
    .s_axi_wready(wready), .s_axi_bresp(bresp),
    .s_axi_bvalid(bvalid), .s_axi_bready(bready),
    .s_axi_araddr(araddr), .s_axi_arvalid(arvalid),
    .s_axi_arready(arready), .s_axi_rdata(rdata),
    .s_axi_rresp(rresp), .s_axi_rvalid(rvalid),
    .s_axi_rready(rready), .interrupt(interrupt),
    .status_firmware_alive(status_firmware_alive),
    .status_engine_busy(status_engine_busy), .status_fault(status_fault),
    .platform_ready(platform_ready), .platform_fault(platform_fault),
    .platform_status(platform_status),
    .platform_diagnostics(platform_diagnostics),
    .i2c_scl(i2c_scl), .i2c_sda(i2c_sda),
    .synthetic_lock(synthetic_lock),
    .synthetic_cdr_lock(synthetic_cdr_lock),
    .synthetic_errors(synthetic_errors)
  );

  always #2.5 clk = ~clk;

  task automatic axi_write(input logic [11:0] address,
                           input logic [31:0] value);
    begin
      @(negedge clk);
      awaddr <= address;
      awvalid <= 1;
      wdata <= value;
      wvalid <= 1;
      bready <= 1;
      while (!(awready && wready)) @(negedge clk);
      @(posedge clk);
      #1;
      awvalid = 0;
      wvalid = 0;
      while (!bvalid) @(negedge clk);
      if (bresp != 0) $fatal(1, "AXI write error at %03x", address);
      bready <= 0;
    end
  endtask

  task automatic axi_read(input logic [11:0] address,
                          output logic [31:0] value);
    begin
      @(negedge clk);
      araddr <= address;
      arvalid <= 1;
      rready <= 1;
      while (!arready) @(negedge clk);
      @(posedge clk);
      #1;
      arvalid = 0;
      while (!rvalid) @(negedge clk);
      if (rresp != 0) $fatal(1, "AXI read error at %03x", address);
      value = rdata;
      rready <= 0;
    end
  endtask

  logic [31:0] value, old_managed_status;
  int cycles;
  initial begin
    repeat (10) @(posedge clk);
    resetn <= 1;
    repeat (6) @(posedge clk);

    axi_read(12'h074, value);
    if (value != EXPECT_MASK0) $fatal(1, "Managed mask word 0 mismatch");
    axi_read(12'h078, value);
    if (value != EXPECT_MASK1) $fatal(1, "Managed mask word 1 mismatch");
    axi_read(12'h07c, value);
    if (value != EXPECT_MASK2) $fatal(1, "Managed mask word 2 mismatch");
    axi_read(12'h080, value);
    if (value[15:0] != EXPECT_MASK3) $fatal(1, "Managed mask word 3 mismatch");
    axi_read(12'h084, value);
    if (value != 32'h1357_9bdf) $fatal(1, "Live diagnostic mismatch");
    axi_write(12'h03c, 32'hfe);
    axi_read(12'h03c, value);
    if (value != 32'hfe) $fatal(1, "Diagnostic selector mismatch");
    axi_read(12'h040, value);
    if (value != platform_status) $fatal(1, "Diagnostic page status mismatch");
    axi_read(12'h05c, value);
    if (value != 32'h8000_1234) $fatal(1, "Diagnostic page tail mismatch");
    axi_write(12'h03c, 32'd0);

    // Reject either an unmanaged lane or bit 112, which is outside the fixed
    // 112-lane ABI even when every represented lane is managed.
    axi_write(12'h02c, FULLY_MANAGED ? 32'd0 : 32'h1);
    if (FULLY_MANAGED) begin
      axi_write(12'h030, 32'd0);
      axi_write(12'h034, 32'd0);
      axi_write(12'h038, 32'h0001_0000);
    end
    axi_write(12'h024, 32'd10);
    axi_write(12'h00c, 32'h1);
    if (!interrupt || !status_fault) $fatal(1, "Unmanaged lane accepted");
    axi_read(12'h018, value);
    if (value != 0) $fatal(1, "Rejected job consumed run ID");
    axi_write(12'h00c, 32'h4);

    // W1-toggle injection writes are also masked to managed lanes.
    axi_write(12'h060, 32'h0000_1001);
    axi_read(12'h060, value);
    if (value != EXPECT_INJECTION0) $fatal(1, "Injection mask mismatch");

    // PRBS31, near-end PMA loopback (mode 2), one millisecond.  This covers
    // the long-soak timebase and all four XPM snapshot handshakes.
    axi_write(12'h020, 32'h0001_1501);
    axi_write(12'h024, 32'd1);
    axi_write(12'h028, 32'd0);
    axi_write(12'h02c, REQUEST_MASK0);
    axi_write(12'h030, REQUEST_MASK1);
    axi_write(12'h034, REQUEST_MASK2);
    axi_write(12'h038, {16'd0, REQUEST_MASK3});
    axi_write(12'h00c, 32'h1);
    cycles = 0;
    while (!interrupt && cycles < 201000) begin
      @(posedge clk);
      cycles++;
    end
    if (!interrupt) $fatal(1, "One-millisecond job did not complete");
    axi_read(12'h018, value);
    if (value != 1) $fatal(1, "Run ID mismatch");
    axi_read(12'h01c, value);
    if (value != EXPECT_NORMAL_SUMMARY)
      $fatal(1, "Managed-lane summary mismatch: %08x", value);
    if (STOP_AFTER_NORMAL) begin
      $display("PASS: milestone-3 mask, out-of-range rejection, and normal engine run");
      $finish;
    end
    axi_write(12'h03c, FIRST_MANAGED_LANE);
    repeat (2) @(posedge clk);
    axi_read(12'h040, old_managed_status);

    // An IBERT-owned lane is represented by a compile-time protocol stub.
    // Its published record retains the lane ID but cannot claim selection,
    // lock, errors, or acquired data.
    if (!FULLY_MANAGED) begin
      axi_write(12'h03c, 32'd1);
      repeat (2) @(posedge clk);
      axi_read(12'h040, value);
      if (value != 32'h0000_0001)
        $fatal(1, "Unmanaged lane status mismatch: %08x", value);
      axi_read(12'h044, value);
      if (value != 0) $fatal(1, "Unmanaged lane published errors");
      axi_read(12'h04c, value);
      if (value != 0) $fatal(1, "Unmanaged lane published tested bits");
    end

    axi_write(12'h00c, 32'h4);
    repeat (3) @(posedge clk);

    // A fatal quad condition may stop RXUSRCLK. Hardware must publish failed
    // records without waiting for a lane-domain stop acknowledgement.
    axi_write(12'h020, 32'h0000_0501);
    axi_write(12'h024, SECOND_NORMAL ? 32'd40 : 32'd1000);
    axi_write(12'h02c, SECOND_MASK0);
    axi_write(12'h030, SECOND_MASK1);
    axi_write(12'h034, SECOND_MASK2);
    axi_write(12'h038, {16'd0, SECOND_MASK3});
    axi_read(12'h02c, value);
    if (value != SECOND_MASK0) $fatal(1, "Second mask0 write did not apply: %08x", value);
    axi_read(12'h030, value);
    if (value != SECOND_MASK1) $fatal(1, "Second mask1 write did not apply: %08x", value);
    axi_read(12'h034, value);
    if (value != SECOND_MASK2) $fatal(1, "Second mask2 write did not apply: %08x", value);
    axi_read(12'h038, value);
    if (value[15:0] != SECOND_MASK3) $fatal(1, "Second mask3 write did not apply: %08x", value);
    // LOCALIZE_DESCRIPTOR_CONTROLS intentionally pipelines source descriptors
    // before the stable-mask acceptance edge.
    repeat (3) @(posedge clk);
    axi_write(12'h00c, 32'h1);
    while (!status_engine_busy) @(posedge clk);
    if (SECOND_NORMAL) begin
      // The same live instance must accept the opposite request-toggle phase
      // with a changed mask.  This is the descriptor re-arm case that fresh
      // one-request instances cannot exercise.
      cycles = 0;
      while (!interrupt && cycles < 5000) begin
        @(posedge clk);
        cycles++;
      end
      if (!interrupt) $fatal(1, "Changed-mask second job did not complete");
      axi_read(12'h018, value);
      if (value != 2) $fatal(1, "Changed-mask run ID mismatch: %0d", value);
      axi_read(12'h01c, value);
      if (value != EXPECT_SECOND_SUMMARY)
        $fatal(1, "Changed-mask summary mismatch: %08x", value);
      if (dut.u_engine_shell.u_engine.u_core.start_req_toggle != 1'b0)
        $fatal(1, "Second request did not cover opposite toggle phase");
      if (dut.u_engine_shell.u_engine.u_core.active_lane_mask != SECOND_MASK)
        $fatal(1, "Accepted active mask differs from second descriptor");
      for (int lane = 0; lane < LANES; lane++) begin
        axi_write(12'h03c, lane);
        repeat (2) @(posedge clk);
        axi_read(12'h040, value);
        axi_read(12'h040, value);
        if (value[7:0] != lane || value[11] != SECOND_MASK[lane])
          $fatal(1, "Lane %0d publication differs from accepted mask: %08x", lane, value);
      end
      $display("PASS: same-instance all112-to-subset descriptor re-arm on both toggle phases");
      $finish;
    end
    repeat (10) @(posedge clk);
    axi_write(12'h03c, FIRST_MANAGED_LANE);
    repeat (2) @(posedge clk);
    axi_read(12'h040, value);
    if (value != old_managed_status)
      $fatal(1, "Published record changed during consecutive managed job");
    platform_fault = 1;
    cycles = 0;
    while (!interrupt && cycles < 1000) begin
      @(posedge clk);
      cycles++;
    end
    if (!interrupt) $fatal(1, "Platform fault did not terminate job");
    axi_read(12'h018, value);
    if (value != 2) $fatal(1, "Consecutive run ID mismatch: %0d", value);
    axi_read(12'h01c, value);
    if (value != EXPECT_FAULT_SUMMARY)
      $fatal(1, "Platform-fault summary mismatch: %08x", value);
    axi_write(12'h03c, FIRST_MANAGED_LANE);
    repeat (2) @(posedge clk);
    axi_read(12'h040, value);
    if (!value[11] || value[12] || !value[13])
      $fatal(1, "Platform-fault lane record mismatch: %08x", value);

    $display("PASS: milestone-3 mask, unmanaged stubs, 1-ms timebase, XPM snapshots, platform fault");
    $finish;
  end
endmodule

module tb_direct_all_v7_engine;
  tb_gt_test_engine_milestone3 #(
    .LOCALIZE_DESCRIPTOR_CONTROLS(1'b1),
    .MANAGED_MASK({16'hffff, 32'hffff_ffff, 32'hff00_0000, 32'd0}),
    .EXPECT_MASK0(32'd0),
    .EXPECT_MASK1(32'hff00_0000),
    .EXPECT_MASK2(32'hffff_ffff),
    .EXPECT_MASK3(16'hffff),
    .EXPECT_INJECTION0(32'd0),
    .EXPECT_NORMAL_SUMMARY(32'h0038_3801),
    .EXPECT_FAULT_SUMMARY(32'h3800_3804),
    .FIRST_MANAGED_LANE(56)
  ) tb();
endmodule

module tb_all_links_v1_engine;
  tb_gt_test_engine_milestone3 #(
    .LOCALIZE_DESCRIPTOR_CONTROLS(1'b1), .FULLY_MANAGED(1'b1),
    .MANAGED_MASK(112'hffffffffffffffffffffffffffff),
    .EXPECT_MASK0(32'hffff_ffff), .EXPECT_MASK1(32'hffff_ffff),
    .EXPECT_MASK2(32'hffff_ffff), .EXPECT_MASK3(16'hffff),
    .EXPECT_INJECTION0(32'h0000_1001),
    .EXPECT_NORMAL_SUMMARY(32'h0070_7001),
    .STOP_AFTER_NORMAL(1'b1),
    .FIRST_MANAGED_LANE(0)
  ) tb();
endmodule

module tb_all_links_v1_subset_engine;
  tb_gt_test_engine_milestone3 #(
    .LOCALIZE_DESCRIPTOR_CONTROLS(1'b1), .FULLY_MANAGED(1'b1),
    .MANAGED_MASK(112'hffffffffffffffffffffffffffff),
    .EXPECT_MASK0(32'hffff_ffff), .EXPECT_MASK1(32'hffff_ffff),
    .EXPECT_MASK2(32'hffff_ffff), .EXPECT_MASK3(16'hffff),
    .REQUEST_MASK0(32'h0000_000f), .REQUEST_MASK1(32'd0),
    .REQUEST_MASK2(32'd0), .REQUEST_MASK3(16'd0),
    .EXPECT_INJECTION0(32'h0000_1001),
    .EXPECT_NORMAL_SUMMARY(32'h0004_0401),
    .STOP_AFTER_NORMAL(1'b1), .FIRST_MANAGED_LANE(0)
  ) tb();
endmodule

module tb_all_links_v1_rearm_engine;
  tb_gt_test_engine_milestone3 #(
    .LOCALIZE_DESCRIPTOR_CONTROLS(1'b1), .FULLY_MANAGED(1'b1),
    .MANAGED_MASK(112'hffffffffffffffffffffffffffff),
    .EXPECT_MASK0(32'hffff_ffff), .EXPECT_MASK1(32'hffff_ffff),
    .EXPECT_MASK2(32'hffff_ffff), .EXPECT_MASK3(16'hffff),
    .EXPECT_INJECTION0(32'h0000_1001),
    .EXPECT_NORMAL_SUMMARY(32'h0070_7001),
    .SECOND_MASK0(32'h8000_0001), .SECOND_MASK1(32'h0000_0003),
    .SECOND_MASK2(32'h0000_000c), .SECOND_MASK3(16'h8001),
    .SECOND_NORMAL(1'b1), .EXPECT_SECOND_SUMMARY(32'h0008_0801),
    .FIRST_MANAGED_LANE(0)
  ) tb();
endmodule
