`timescale 1ns/1ps
module tb_direct_all_v7_quad_aggregate;
  logic clk=0, resetn=0;
  logic [13:0] ready, fault, idle, acquire, capture, session_applied;
  logic [111:0] reasons;
  logic [3135:0] diagnostics;
  wire all_ready, any_fault, all_idle, all_acquire, all_capture, all_session_applied;
  wire [7:0] reason;
  wire [223:0] diagnostic;
  logic [6:0] controls_in = 0;
  wire [6:0] controls_out [0:3];
  for (genvar slr = 0; slr < 4; slr++) begin : g_control
    direct_all_v7_control_pipeline u_control (
      .clk(clk), .controls_in(controls_in), .controls_out(controls_out[slr]));
  end
  direct_all_v7_quad_aggregate dut (
    .clk(clk), .resetn(resetn),
    .quad_ready_in(ready), .quad_fault_in(fault), .controller_idle_in(idle),
    .acquisition_ready_in(acquire), .capture_done_in(capture),
    .tx_session_applied_in(session_applied),
    .fault_reason_in(reasons), .diagnostics_in(diagnostics),
    .quad_ready(all_ready), .quad_fault(any_fault), .controller_idle(all_idle),
    .acquisition_ready(all_acquire), .capture_done(all_capture),
    .tx_session_applied(all_session_applied),
    .fault_reason(reason), .diagnostics(diagnostic));
  always #1 clk = ~clk;
  task settle; repeat (3) @(posedge clk); #0.1; endtask
  initial begin
    ready='1; fault='0; idle='1; acquire='1; capture='1; session_applied='1;
    reasons='0; diagnostics='0;
    diagnostics[0 +: 224]=224'h221;
    repeat (2) @(posedge clk); resetn=1; settle();
    if (!all_ready || any_fault || !all_idle || !all_acquire || !all_capture ||
        !all_session_applied || diagnostic!=224'h221)
      $fatal(1,"clean fourteen-quad aggregate failed");
    controls_in=7'b1011011;
    #0.1;
    for (int slr=0; slr<4; slr++)
      if (controls_out[slr] != 0) $fatal(1,"control bank changed before its clock edge");
    @(posedge clk); #0.1;
    for (int slr=0; slr<4; slr++)
      if (controls_out[slr] != controls_in)
        $fatal(1,"parallel SLR control pipeline latency/value mismatch");
    ready[9]=0; idle[7]=0; acquire[5]=0; capture[13]=0;
    session_applied[11]=0;
    settle();
    if (all_ready || all_idle || all_acquire || all_capture || all_session_applied)
      $fatal(1,"AND cleanup/readiness/session aggregation failed");
    ready='1; idle='1; acquire='1; capture='1; session_applied='1;
    fault[9]=1; reasons[9*8 +: 8]=8'h20; diagnostics[9*224 +: 224]=224'h230;
    settle();
    if (!any_fault || reason!=8'h20 || diagnostic!=224'h230) $fatal(1,"single non-q221 fault was not exposed");
    fault[3]=1; reasons[3*8 +: 8]=8'h80; diagnostics[3*224 +: 224]=224'h224;
    settle();
    if (reason!=8'ha0 || diagnostic!=224'h224) $fatal(1,"simultaneous fault priority/reason OR failed");
    fault[3]=0; reasons[3*8 +: 8]=0;
    settle();
    if (diagnostic!=224'h230) $fatal(1,"retained failing-quad diagnostic selection failed");
    $display("PASS: fourteen-quad readiness/cleanup aggregation and deterministic retained fault selection");
    $finish;
  end
endmodule
