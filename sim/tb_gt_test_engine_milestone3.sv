`timescale 1ns/1ps

module tb_gt_test_engine_milestone3;
  localparam int LANES = 112;
  localparam logic [LANES-1:0] MANAGED_MASK = {96'd0, 4'hf, 12'd0};

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
  tri1 i2c_scl, i2c_sda;
  logic [LANES-1:0] synthetic_lock = {LANES{1'b1}};
  logic [LANES*16-1:0] synthetic_errors = 0;

  gt_test_hardware_shell #(
    .LANES(LANES), .MANAGED_LANE_MASK(MANAGED_MASK),
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
    .i2c_scl(i2c_scl), .i2c_sda(i2c_sda),
    .synthetic_lock(synthetic_lock), .synthetic_errors(synthetic_errors)
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

  logic [31:0] value;
  int cycles;
  initial begin
    repeat (10) @(posedge clk);
    resetn <= 1;
    repeat (6) @(posedge clk);

    axi_read(12'h074, value);
    if (value != 32'h0000_f000) $fatal(1, "Managed mask mismatch");

    // Lane zero remains under IBERT and must be rejected by hardware.
    axi_write(12'h02c, 32'h1);
    axi_write(12'h024, 32'd10);
    axi_write(12'h00c, 32'h1);
    if (!interrupt || !status_fault) $fatal(1, "Unmanaged lane accepted");
    axi_read(12'h018, value);
    if (value != 0) $fatal(1, "Rejected job consumed run ID");
    axi_write(12'h00c, 32'h4);

    // W1-toggle injection writes are also masked to managed lanes.
    axi_write(12'h060, 32'h0000_1001);
    axi_read(12'h060, value);
    if (value != 32'h0000_1000) $fatal(1, "Injection mask mismatch");

    // PRBS31, near-end PMA loopback (mode 2), one millisecond.  This covers
    // the long-soak timebase and all four XPM snapshot handshakes.
    axi_write(12'h020, 32'h0001_1501);
    axi_write(12'h024, 32'd1);
    axi_write(12'h028, 32'd0);
    axi_write(12'h02c, 32'h0000_f000);
    axi_write(12'h030, 32'd0);
    axi_write(12'h034, 32'd0);
    axi_write(12'h038, 32'd0);
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
    if (value != 32'h0004_0401)
      $fatal(1, "Four-lane summary mismatch: %08x", value);

    axi_write(12'h00c, 32'h4);

    // A fatal quad condition may stop RXUSRCLK. Hardware must publish failed
    // records without waiting for a lane-domain stop acknowledgement.
    axi_write(12'h020, 32'h0000_0501);
    axi_write(12'h024, 32'd1000);
    axi_write(12'h00c, 32'h1);
    while (!status_engine_busy) @(posedge clk);
    repeat (10) @(posedge clk);
    platform_fault = 1;
    cycles = 0;
    while (!interrupt && cycles < 1000) begin
      @(posedge clk);
      cycles++;
    end
    if (!interrupt) $fatal(1, "Platform fault did not terminate job");
    axi_read(12'h01c, value);
    if (value != 32'h0400_0404)
      $fatal(1, "Platform-fault summary mismatch: %08x", value);
    axi_write(12'h03c, 32'd12);
    repeat (2) @(posedge clk);
    axi_read(12'h040, value);
    if (!value[11] || value[12] || !value[13])
      $fatal(1, "Platform-fault lane record mismatch: %08x", value);

    $display("PASS: milestone-3 mask, 1-ms timebase, XPM snapshots, platform fault");
    $finish;
  end
endmodule
