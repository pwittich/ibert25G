`timescale 1ns/1ps

module tb_gt_test_hardware_shell;
  localparam int LANES = 112;

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
  wire status_firmware_alive;
  wire status_engine_busy;
  wire status_fault;
  logic platform_ready = 1;
  logic platform_fault = 0;
  logic [31:0] platform_status = 0;
  logic [223:0] platform_diagnostics = 0;
  tri1 i2c_scl, i2c_sda;
  logic i2c_scl_drive_low = 0, i2c_sda_drive_low = 0;
  assign i2c_scl = i2c_scl_drive_low ? 1'b0 : 1'bz;
  assign i2c_sda = i2c_sda_drive_low ? 1'b0 : 1'bz;
  logic [LANES-1:0] synthetic_lock = {LANES{1'b1}};
  logic [LANES-1:0] synthetic_cdr_lock = {LANES{1'b1}};
  logic [LANES*16-1:0] synthetic_errors = 0;

  // Exercise the same four 256-bit XPM snapshot handshakes used by the
  // managed quad-124 target.  The synthetic clocks are phase-aligned here;
  // XPM's protocol assertions still check the full request/return sequence.
  gt_test_hardware_shell #(
    .LANES(LANES),
    .ASYNC_SNAPSHOT_MASK({96'd0, 4'hf, 12'd0})
  ) dut (.*,
    .clk_200(clk),
    .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid),
    .s_axi_awready(awready), .s_axi_wdata(wdata),
    .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid),
    .s_axi_wready(wready), .s_axi_bresp(bresp),
    .s_axi_bvalid(bvalid), .s_axi_bready(bready),
    .s_axi_araddr(araddr), .s_axi_arvalid(arvalid),
    .s_axi_arready(arready), .s_axi_rdata(rdata),
    .s_axi_rresp(rresp), .s_axi_rvalid(rvalid),
    .s_axi_rready(rready)
  );

  always #2.5 clk = ~clk;

  task automatic axi_write(input logic [11:0] address,
                           input logic [31:0] value);
    begin
      @(negedge clk);
      awaddr <= address;
      awvalid <= 1;
      wdata <= value;
      wstrb <= 4'hf;
      wvalid <= 1;
      bready <= 1;
      while (!(awready && wready)) @(negedge clk);
      @(posedge clk);
      #1;
      awvalid = 0;
      wvalid = 0;
      while (!bvalid) @(negedge clk);
      if (bresp != 2'b00) $fatal(1, "AXI write error at %03x", address);
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
      if (rresp != 2'b00) $fatal(1, "AXI read error at %03x", address);
      value = rdata;
      rready <= 0;
    end
  endtask

  task automatic wait_for_interrupt;
    int cycles;
    begin
      cycles = 0;
      while (!interrupt && cycles < 2000) begin
        @(posedge clk);
        cycles++;
      end
      if (!interrupt) $fatal(1, "Timed out waiting for engine interrupt");
    end
  endtask

  task automatic wait_for_state(input logic [3:0] expected);
    logic [31:0] value;
    int attempts;
    begin
      value = 0;
      attempts = 0;
      while (value[3:0] != expected && attempts < 40) begin
        axi_read(12'h010, value);
        attempts++;
      end
      if (value[3:0] != expected)
        $fatal(1, "State %0d not reached (state=%0d)", expected, value[3:0]);
    end
  endtask

  task automatic select_lane(input logic [7:0] lane);
    begin
      axi_write(12'h03c, lane);
    end
  endtask

  task automatic i2c_start;
    begin
      i2c_sda_drive_low = 0;
      i2c_scl_drive_low = 0;
      #100;
      i2c_sda_drive_low = 1;
      #100;
      i2c_scl_drive_low = 1;
    end
  endtask

  task automatic i2c_stop;
    begin
      i2c_sda_drive_low = 1;
      i2c_scl_drive_low = 1;
      #100;
      i2c_scl_drive_low = 0;
      #100;
      i2c_sda_drive_low = 0;
      #100;
    end
  endtask

  task automatic i2c_write_byte(input logic [7:0] byte_value);
    begin
      for (int bit_index = 7; bit_index >= 0; bit_index--) begin
        i2c_scl_drive_low = 1;
        #50;
        i2c_sda_drive_low = !byte_value[bit_index];
        #100;
        i2c_scl_drive_low = 0;
        #100;
      end
      i2c_scl_drive_low = 1;
      #50;
      i2c_sda_drive_low = 0;
      #100;
      i2c_scl_drive_low = 0;
      #100;
      if (i2c_sda !== 1'b0)
        $fatal(1, "I2C byte %02x was not acknowledged (state=%0d match=%0d)",
               byte_value, dut.u_engine_shell.u_mailbox_i2c.state,
               dut.u_engine_shell.u_mailbox_i2c.address_match);
      i2c_scl_drive_low = 1;
    end
  endtask

  logic [31:0] value, old_lane0_status, old_lane0_error;

  initial begin
    repeat (10) @(posedge clk);
    resetn <= 1;
    repeat (6) @(posedge clk);

    axi_read(12'h000, value);
    if (value != 32'h4754_5354) $fatal(1, "Hardware ID mismatch");
    if (status_firmware_alive || status_engine_busy || status_fault)
      $fatal(1, "Unexpected status immediately after reset");

    // In the integrated target this write is executed by MicroBlaze during
    // boot.  It is the source of the board's green CPU proof-of-life LED.
    axi_write(12'h0c0, 32'h0001_0002);
    if (!status_firmware_alive)
      $fatal(1, "Firmware-alive status did not follow AXI version write");

    // Exercise the reserved MCU mailbox through the actual 0x2B I2C slave.
    i2c_start();
    i2c_write_byte(8'h56); // 7-bit address 0x2B, write
    i2c_write_byte(8'ha0);
    i2c_write_byte(8'h78);
    i2c_write_byte(8'h56);
    i2c_write_byte(8'h34);
    i2c_write_byte(8'h12);
    i2c_stop();
    axi_read(12'h0a0, value);
    if (value != 32'h1234_5678)
      $fatal(1, "I2C/AXI mailbox mapping mismatch: %08x", value);

    // Full 112-lane job.  No AXI access occurs between the doorbell and the
    // interrupt: this models a MicroBlaze halted immediately after launch.
    axi_write(12'h024, 32'd20);
    axi_write(12'h028, 32'd0);
    axi_write(12'h00c, 32'h1);
    wait_for_state(4'd2);
    if (!status_engine_busy) $fatal(1, "Busy status missing during job");
    wait_for_interrupt();
    axi_read(12'h018, value);
    if (value != 1) $fatal(1, "First run ID mismatch: %0d", value);
    axi_read(12'h01c, value);
    if (value != 32'h0070_7001)
      $fatal(1, "All-lane summary mismatch: %08x", value);
    if (status_engine_busy || status_fault)
      $fatal(1, "Normal job did not return healthy idle status");
    select_lane(8'd111);
    axi_read(12'h040, value);
    if (value[7:0] != 8'd111 || !value[11] || !value[12])
      $fatal(1, "Lane 111 status mismatch: %08x", value);
    axi_read(12'h04c, value);
    if (value == 0) $fatal(1, "Lane 111 tested-bit count is zero");
    select_lane(8'd0);
    axi_read(12'h040, old_lane0_status);
    axi_read(12'h044, old_lane0_error);
    axi_write(12'h00c, 32'h4);

    // Two-lane job with an error only on lane 7 and a lock-loss event only on
    // lane 3.  The previously published bank must remain readable while busy.
    axi_write(12'h02c, 32'h0000_0088);
    axi_write(12'h030, 32'h0);
    axi_write(12'h034, 32'h0);
    axi_write(12'h038, 32'h0);
    axi_write(12'h024, 32'd40);
    synthetic_errors[7*16 +: 16] = 16'd1;
    axi_write(12'h00c, 32'h1);
    wait_for_state(4'd2);
    axi_read(12'h040, value);
    if (value != old_lane0_status)
      $fatal(1, "Published result changed during active job");
    // Match the v11 hardware finding: PRBS lock can remain high while the
    // FireFly and native GT CDR lose lock. V12 must still record the event.
    synthetic_cdr_lock[3] = 0;
    repeat (5) @(posedge clk);
    synthetic_cdr_lock[3] = 1;
    wait_for_interrupt();
    synthetic_errors[7*16 +: 16] = 0;
    axi_read(12'h01c, value);
    if (value != 32'h0200_0201)
      $fatal(1, "Injected-fault summary mismatch: %08x", value);
    if (!status_fault) $fatal(1, "Failed lanes did not assert fault status");
    select_lane(8'd7);
    axi_read(12'h044, value);
    if (value == 0) $fatal(1, "Lane 7 did not accumulate injected errors");
    select_lane(8'd3);
    axi_read(12'h054, value);
    if (value == 0) $fatal(1, "Lane 3 did not record lock loss");
    select_lane(8'd0);
    axi_read(12'h044, value);
    if (value != 0) $fatal(1, "Corruption leaked into lane 0");
    axi_write(12'h00c, 32'h4);

    // Abort publishes a partial, atomic result and reports reason 2.
    axi_write(12'h02c, 32'h1);
    axi_write(12'h024, 32'd1000);
    axi_write(12'h028, 32'd0);
    axi_write(12'h00c, 32'h1);
    wait_for_state(4'd2);
    repeat (8) @(posedge clk);
    axi_write(12'h00c, 32'h2);
    wait_for_interrupt();
    axi_read(12'h01c, value);
    if (value[7:0] != 8'd2) $fatal(1, "Abort reason mismatch");
    if (!status_fault) $fatal(1, "Abort did not assert fault status");
    axi_write(12'h00c, 32'h4);

    // Timeout is independent of CPU activity and also publishes partial data.
    axi_write(12'h024, 32'd100);
    axi_write(12'h028, 32'd10);
    axi_write(12'h00c, 32'h1);
    wait_for_interrupt();
    axi_read(12'h01c, value);
    if (value[7:0] != 8'd3) $fatal(1, "Timeout reason mismatch");
    if (!status_fault) $fatal(1, "Timeout did not assert fault status");
    axi_read(12'h018, value);
    if (value != 4) $fatal(1, "Final run ID mismatch: %0d", value);
    axi_write(12'h00c, 32'h4);

    // Invalid PRBS encoding is rejected and does not consume a run ID.
    axi_write(12'h020, 32'h0000_0001);
    axi_write(12'h00c, 32'h1);
    wait_for_interrupt();
    axi_read(12'h014, value);
    if (value[1:0] != 2'b11) $fatal(1, "Bad command not reported");
    if (!status_fault) $fatal(1, "Bad command did not assert fault status");
    axi_read(12'h018, value);
    if (value != 4) $fatal(1, "Rejected job changed run ID");

    $display("PASS: 112-lane synthetic job, CPU/status outputs, I2C mailbox, atomic banks, faults, abort, timeout");
    $finish;
  end
endmodule
