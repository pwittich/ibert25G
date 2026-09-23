`timescale 1ns/1ps
module tb_all_links_v1_quad_aggregate;
  logic clk=0, resetn=0;
  logic [3:0] ready, fault, idle, acquire, capture, session_applied;
  logic [31:0] reasons;
  logic [895:0] diagnostics;
  wire all_ready, any_fault, all_idle, all_acquire, all_capture, all_session;
  wire [7:0] reason;
  wire [223:0] diagnostic;
  all_links_v1_quad_aggregate dut (
    .clk(clk), .resetn(resetn), .group_ready(ready), .group_fault(fault),
    .group_idle(idle), .group_acquire(acquire),
    .group_capture(capture), .group_session_applied(session_applied),
    .group_reason(reasons), .group_diagnostics(diagnostics),
    .quad_ready(all_ready), .quad_fault(any_fault), .controller_idle(all_idle),
    .acquisition_ready(all_acquire), .capture_done(all_capture),
    .tx_session_applied(all_session), .fault_reason(reason),
    .diagnostics(diagnostic));
  always #1 clk=~clk;
  task settle; repeat (3) @(posedge clk); #0.1; endtask
  initial begin
    ready='1; fault='0; idle='1; acquire='1; capture='1; session_applied='1;
    reasons='0; diagnostics='0; diagnostics[0 +: 224]=224'h121;
    repeat (2) @(posedge clk); resetn=1; settle();
    if (!all_ready || any_fault || !all_idle || !all_acquire ||
        !all_capture || !all_session || diagnostic!=224'h121)
      $fatal(1,"clean 28-quad aggregate failed");
    foreach (session_applied[q]) begin
      session_applied[q]=0; settle();
      if (all_session) $fatal(1,"session barrier missed quad %0d",q);
      session_applied[q]=1; settle();
      if (!all_session) $fatal(1,"session barrier did not recover quad %0d",q);
    end
    fault[2]=1; reasons[2*8 +: 8]=8'h20;
    diagnostics[2*224 +: 224]=224'h130; settle();
    if (!any_fault || reason!=8'h20 || diagnostic!=224'h130)
      $fatal(1,"SLR2/right fault selection failed");
    $display("PASS: final four-bank aggregation, priority, and all-session acknowledgement barrier");
    $finish;
  end
endmodule
