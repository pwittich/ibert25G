`timescale 1ns/1ps
// Compare the new matched bank-status transport against the preserved v3
// reduction delayed by two clocks. Session tags/config retain exact latency.
module tb_eye_scan_v1_status;
  logic clk=0, resetn=0, session=0;
  always #2.5 clk=~clk;
  logic [1:0] tag=0;
  logic [7:0] ack_tags=0;
  logic [3:0] on_ack=0,off_ack=15,config_idle=15;
  logic [3:0] ready=15,fault=0,idle=15,acquire=15,capture=15;
  logic [31:0] reason=0;
  logic [895:0] diagnostics=0;
  wire [236:0] actual,reference;
  wire actual_session,reference_session,actual_config,reference_config;
  logic [236:0] delay0=0,delay1=0;
`define PORTS(BUNDLE,SESSION,CONFIG) \
    .clk(clk),.resetn(resetn),.session_requested(session),.session_tag(tag), \
    .group_session_ack_tag(ack_tags),.group_session_on_ack(on_ack),.group_session_off_ack(off_ack), \
    .group_config_idle(config_idle),.config_idle(CONFIG), \
    .group_ready(ready),.group_fault(fault),.group_idle(idle),.group_acquire(acquire), \
    .group_capture(capture),.group_session_applied(4'd0),.group_reason(reason),.group_diagnostics(diagnostics), \
    .quad_ready(BUNDLE[0]),.quad_fault(BUNDLE[1]),.controller_idle(BUNDLE[2]), \
    .acquisition_ready(BUNDLE[3]),.capture_done(BUNDLE[4]), \
    .fault_reason(BUNDLE[12:5]),.diagnostics(BUNDLE[236:13]),.tx_session_applied(SESSION)
  eye_scan_v1_quad_aggregate dut(`PORTS(actual,actual_session,actual_config));
  all_links_v3_quad_aggregate baseline(`PORTS(reference,reference_session,reference_config));
`undef PORTS
  always @(posedge clk) begin delay0<=reference;delay1<=delay0;end
  initial begin
    repeat(3) @(negedge clk);resetn=1;
    repeat(10) @(negedge clk);
    for(integer cycle=0;cycle<160;cycle++) begin
      fault=cycle%16;ready=~(cycle%16);idle=(cycle*3)%16;
      acquire=(cycle*5)%16;capture=(cycle*7)%16;
      reason=32'h80402010 ^ cycle;
      for(integer bank=0;bank<4;bank++) diagnostics[bank*224+:224]={7{32'(cycle*16+bank)}};
      if(cycle%11==0) begin tag=tag+1'b1;session=~session;end
      for(integer bank=0;bank<4;bank++) begin
        if(cycle%(bank+2)==0) begin
          ack_tags[bank*2+:2]=tag;on_ack[bank]=session;off_ack[bank]=!session;
        end
      end
      config_idle=cycle%16;
      @(negedge clk);
      if(actual!==delay1) $fatal(1,"bank status/reason/diagnostics latency mismatch at %0d",cycle);
      if(actual_session!==reference_session || actual_config!==reference_config)
        $fatal(1,"tagged session/config barrier latency changed at %0d",cycle);
    end
    $display("PASS: eye v1 matched status/diagnostic returns, all-bank priority, exact session/config latency");
    $finish;
  end
endmodule
