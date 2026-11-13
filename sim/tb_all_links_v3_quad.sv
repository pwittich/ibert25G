`timescale 1ns/1ps
module tb_all_links_v3_quad;
  logic clk=0, refclk=0, resetn=0, tx_enable=0, rx_enable=0, session=0;
  logic [1:0] tag=0;
  wire [1:0] ack_tag;
  logic [11:0] tx_prbs=12'd0;
  wire applied,session_applied,ready,fault,config_idle;
  always #2.5 clk=~clk;
  always #1.55 refclk=~refclk;
  managed_all_links_v3_quad_wrapper #(.QUAD(121),.ALL_LINKS_LEFT_V1(1)) dut(
    .mgmt_clk(clk),.resetn(resetn),.session_tag(tag),.session_tag_ack(ack_tag),.tx_enable(tx_enable),.rx_enable(rx_enable),
    .tx_enable_applied(applied),.config_idle(config_idle),.tx_session_active(session),.tx_session_applied(session_applied),
    .refclk(refclk),.refclk_odiv2(refclk),.rx_p(4'd0),.rx_n(4'd0),
    .tx_prbs_select(tx_prbs),.rx_prbs_select(12'd0),.prbs_counter_reset(4'd0),
    .lane_running(4'd0),.loopback_mode(3'd0),.acquisition_active(1'b0),
    .measurement_enable(1'b0),.result_capture_request(1'b0),.tx_error_inject_toggle(4'd0),
    .quad_ready(ready),.quad_fault(fault));
  always @(negedge clk) if(resetn && ack_tag==tag && tag!=0) begin
    if(session && dut.txprbssel!={4{4'd5}}) $fatal(1,"tag acknowledged before PRBS output stage");
    if(!session && dut.txprbssel!=0) $fatal(1,"tag acknowledged before generator removal");
  end
  task wait_clocks;
    repeat(25) @(negedge clk);
  endtask
  initial begin
    repeat(6) @(negedge clk);resetn=1;repeat(300) @(negedge clk);
    if(dut.g_all_links_q121.u_gt.txelecidle_in!==4'hf || applied || fault || !ready)
      $fatal(1,"unsafe startup or TX-only infrastructure not ready");
    tx_enable=1;session=1;tag=1;wait_clocks();
    if(!applied||!session_applied||dut.txprbssel!={4{4'd5}}||
        dut.g_all_links_q121.u_gt.txelecidle_in!=0) $fatal(1,"TX enable/session not applied");
    // RX-only status failure must not reset a TX-only quad.
    dut.g_all_links_q121.u_gt.force_rx_fault=1;wait_clocks();
    if(fault||!ready) $fatal(1,"disabled RX fault contaminated TX-only operation");
    tx_enable=0;session=0;tag=3;wait_clocks();
    if(applied||session_applied||dut.txprbssel!=0||dut.g_all_links_q121.u_gt.txelecidle_in!=15)
      $fatal(1,"disabled TX emitted data or stale session remained");
    dut.g_all_links_q121.u_gt.force_rx_fault=0;
    rx_enable=1;wait_clocks();
    if(fault||!ready||dut.g_all_links_q121.u_gt.txelecidle_in!=15)
      $fatal(1,"RX-only operation requires electrical TX enable");
    force dut.u_prbs_test_controller.state = dut.u_prbs_test_controller.ST_POST_CAPTURE_RX_REQUAL;
    #1;if(config_idle) $fatal(1,"RX cleanup was eligible for configuration");
    force dut.u_prbs_test_controller.state = dut.u_prbs_test_controller.ST_FAULT;
    #1;if(!config_idle || !fault) $fatal(1,"terminal fault not safely configurable or evidence erased");
    release dut.u_prbs_test_controller.state;
    $display("PASS: v3 quad startup electrical idle, TX-only, RX-only and session removal");
    $finish;
  end
endmodule
