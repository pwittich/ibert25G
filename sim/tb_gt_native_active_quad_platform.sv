`timescale 1ns/1ps

// Proves the native scalar-platform binding against the unmodified engine's
// descriptor/active-mask behavior.  Hierarchical observation is intentional:
// this is a proof that does not add a port to the stable historical engine.
module tb_gt_native_active_quad_platform;
  localparam int LANES = 112;
  logic clk = 0, resetn = 0;
  logic [11:0] awaddr = 0; logic awvalid = 0;
  logic [31:0] wdata = 0; logic [3:0] wstrb = 4'hf; logic wvalid = 0;
  wire awready, wready, bvalid; wire [1:0] bresp;
  logic bready = 0;
  logic [11:0] araddr = 0; logic arvalid = 0; wire arready;
  wire [31:0] rdata; wire [1:0] rresp; wire rvalid; logic rready = 0;
  wire interrupt, firmware_alive, busy, status_fault;
  tri1 i2c_scl, i2c_sda;
  logic [27:0] quad_ready = {28{1'b1}};
  logic [27:0] quad_idle = {28{1'b1}};
  logic [27:0] quad_fault = 0;
  wire [111:0] engine_mask = busy
    ? dut.u_engine_shell.u_engine.u_core.active_lane_mask
    : dut.u_engine_shell.u_engine.u_core.descriptor_lane_mask;
  wire [27:0] active_quads, active_restart;
  wire platform_ready, platform_fault;

  gt_native_active_quad_platform u_platform (
    .selected_lanes(engine_mask), .quad_ready(quad_ready), .quad_idle(quad_idle),
    .quad_fault(quad_fault), .quad_restart_request(1'b1),
    .active_quads(active_quads), .platform_ready(platform_ready),
    .platform_fault(platform_fault), .active_quad_restart(active_restart)
  );
  gt_test_hardware_shell #(.LANES(LANES), .MANAGED_LANE_MASK({LANES{1'b1}})) dut (
    .clk_200(clk), .resetn(resetn), .s_axi_awaddr(awaddr),
    .s_axi_awvalid(awvalid), .s_axi_awready(awready), .s_axi_wdata(wdata),
    .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
    .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
    .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
    .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid),
    .s_axi_rready(rready), .interrupt(interrupt),
    .status_firmware_alive(firmware_alive), .status_engine_busy(busy),
    .status_fault(status_fault), .platform_ready(platform_ready),
    .platform_fault(platform_fault), .platform_status(32'd0),
    .platform_diagnostics(224'd0), .i2c_scl(i2c_scl), .i2c_sda(i2c_sda),
    .synthetic_lock({LANES{1'b1}}), .synthetic_cdr_lock({LANES{1'b1}}),
    .synthetic_errors({LANES*16{1'b0}})
  );
  always #2.5 clk = ~clk;
  task automatic axi_write(input logic [11:0] address, input logic [31:0] value);
    begin
      @(negedge clk); awaddr <= address; awvalid <= 1; wdata <= value;
      wvalid <= 1; bready <= 1;
      while (!(awready && wready)) @(negedge clk);
      @(posedge clk); #1; awvalid = 0; wvalid = 0;
      while (!bvalid) @(negedge clk);
      if (bresp != 0) $fatal(1, "AXI write failure");
      bready <= 0;
    end
  endtask
  initial begin
    repeat (8) @(posedge clk); resetn <= 1; repeat (4) @(posedge clk);
    // q221 is both unready and faulted, but q222 (lanes 60..63) is selected.
    quad_ready[14] <= 0; quad_fault[14] <= 1;
    axi_write(12'h02c, 0); axi_write(12'h030, 32'h1000_0000);
    axi_write(12'h034, 0); axi_write(12'h038, 0);
    if (!platform_ready || platform_fault || active_quads != 28'h0000_8000 ||
        active_restart != 28'h0000_8000)
      $fatal(1, "inactive q221 blocked/faulted/reset active q222");
    axi_write(12'h020, 32'h0000_0501); axi_write(12'h024, 32'd1000);
    axi_write(12'h00c, 32'h1);
    repeat (8) @(posedge clk);
    if (!busy || status_fault || interrupt || active_quads != 28'h0000_8000)
      $fatal(1, "inactive q221 fault affected active-q222 engine run");
    // Wait for the real engine's lane-toggle ARM handshake.  The native
    // platform must not be faulted until the engine actually owns its frozen
    // active mask and has entered RUN.
    begin : wait_for_run
      for (int attempt = 0; attempt < 200; attempt++) begin
        @(posedge clk);
        if (dut.u_engine_shell.u_engine.u_core.state == 4'd2)
          disable wait_for_run;
      end
      $fatal(1, "engine did not enter RUN with inactive q221 fault");
    end
    quad_fault[15] <= 1;
    // The engine publishes atomically through its 112-lane COPY/PUBLISH
    // sequence, so allow that bounded management-domain completion latency.
    begin : wait_for_platform_fault
      for (int attempt = 0; attempt < 200; attempt++) begin
        @(posedge clk);
        if (interrupt) disable wait_for_platform_fault;
      end
    end
    if (!interrupt || !status_fault)
      $fatal(1, "active-q222 fault did not terminate engine run");
    $display("PASS: native active-quad contract isolates inactive ready/fault/restart and faults active engine run");
    $finish;
  end
endmodule
