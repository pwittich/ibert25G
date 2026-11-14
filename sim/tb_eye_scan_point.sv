`timescale 1ns/1ps
module tb_eye_scan_point;
  logic clk=0, resetn=0;
  always #2.5 clk=~clk;
  logic start=0, cancel=0, permit=1, healthy=1, profile=1, lpm=1;
  logic [1:0] lane=0;
  logic signed [10:0] horizontal=0;
  logic signed [8:0] vertical=0;
  logic [4:0] prescale=0;
  logic [31:0] timeout_cycles=1000;
  wire start_ready,busy,result_valid,cleanup,fatal;
  logic result_ready=0;
  wire [7:0] status;
  wire [1:0] measurements;
  wire [15:0] errors0,samples0,errors1,samples1;
  wire [63:0] bits0,bits1;
  wire result_lpm;
  wire signed [10:0] result_horizontal;
  wire signed [8:0] result_vertical;
  wire [4:0] result_prescale;
  wire request,release_scan,granted,blocked,cmd_valid,cmd_ready,cmd_we,rsp_valid,rsp_ready,rsp_error;
  wire [1:0] scan_lane;
  wire [2:0] fault;
  wire [9:0] cmd_addr;
  wire [15:0] cmd_di,rsp_do;
  wire [39:0] gt_addr;
  wire [63:0] gt_di,gt_do;
  wire [3:0] gt_en,gt_we,gt_rdy;
  logic prbs_idle=1;
  logic [15:0] initial_control=16'h01a0;
  logic hold_wait=0,hold_count=0,hold_stop=0,fast_end=0,initial_end=0,zero_samples=0;
  logic bad_config=0,bad_restore=0,stall=0;
  logic signed [10:0] expected_horizontal=0;
  logic signed [8:0] expected_vertical=0;
  logic [4:0] expected_prescale=0;
  integer cases=0;

  eye_scan_point #(.BUS_TIMEOUT_CYCLES(64),.LEASE_TIMEOUT_CYCLES(32)) dut (
    .mgmt_clk(clk),.resetn(resetn),.start(start),.cancel(cancel),.permit(permit),
    .rx_healthy(healthy),.profile_ok(profile),.lpm_mode(lpm),.lane(lane),
    .horizontal(horizontal),.vertical(vertical),.prescale(prescale),
    .sample_timeout_cycles(timeout_cycles),.start_ready(start_ready),.busy(busy),
    .result_valid(result_valid),.result_ready(result_ready),.result_status(status),
    .cleanup_verified(cleanup),.fatal(fatal),.result_measurements(measurements),
    .errors0(errors0),.samples0(samples0),.errors1(errors1),.samples1(samples1),
    .bits0(bits0),.bits1(bits1),.result_lpm(result_lpm),
    .result_horizontal(result_horizontal),.result_vertical(result_vertical),
    .result_prescale(result_prescale),.scan_request(request),.scan_lane(scan_lane),
    .scan_release(release_scan),.scan_granted(granted),.port_fault(fault),
    .cmd_valid(cmd_valid),.cmd_ready(cmd_ready),.cmd_addr(cmd_addr),.cmd_di(cmd_di),
    .cmd_we(cmd_we),.rsp_valid(rsp_valid),.rsp_ready(rsp_ready),
    .rsp_do(rsp_do),.rsp_error(rsp_error));
  eye_scan_drp_arbiter #(.DRP_TIMEOUT_CYCLES(16)) arb (
    .mgmt_clk(clk),.resetn(resetn),.prbs_idle(prbs_idle),.scan_eligible(1'b1),
    .prbs_addr(40'd0),.prbs_di(64'd0),.prbs_en(4'd0),.prbs_we(4'd0),
    .scan_request(request),.scan_lane(scan_lane),.scan_release(release_scan),
    .scan_granted(granted),.blocked(blocked),.fault(fault),
    .cmd_valid(cmd_valid),.cmd_ready(cmd_ready),.cmd_addr(cmd_addr),.cmd_di(cmd_di),
    .cmd_we(cmd_we),.rsp_valid(rsp_valid),.rsp_ready(rsp_ready),
    .rsp_do(rsp_do),.rsp_error(rsp_error),.gt_addr(gt_addr),.gt_di(gt_di),
    .gt_en(gt_en),.gt_we(gt_we),.gt_do(gt_do),.gt_rdy(gt_rdy));
  eye_scan_gt_model gt (.clk(clk),.resetn(resetn),.addr(gt_addr),.di(gt_di),
    .en(gt_en),.we(gt_we),.dout(gt_do),.rdy(gt_rdy),.initial_control(initial_control),
    .hold_wait(hold_wait),.hold_count(hold_count),.hold_stop(hold_stop),.fast_end(fast_end),
    .initial_end(initial_end),.zero_samples(zero_samples),.bad_config(bad_config),
    .bad_restore(bad_restore),.stall(stall),.expected_lane(scan_lane),
    .expected_horizontal(expected_horizontal),.expected_vertical(expected_vertical),
    .expected_prescale(expected_prescale));

  task tick(input integer n); repeat(n) @(negedge clk); endtask
  task defaults;
    resetn=0; start=0; cancel=0; result_ready=0;
    permit=1; healthy=1; profile=1; lpm=1; lane=0;
    horizontal=0; vertical=0; prescale=0; timeout_cycles=1000;
    prbs_idle=1; initial_control=16'h01a0;
    hold_wait=0; hold_count=0; hold_stop=0; fast_end=0; initial_end=0; zero_samples=0;
    bad_config=0; bad_restore=0; stall=0;
    tick(3); resetn=1; tick(2);
  endtask
  task launch;
    if (!start_ready) $fatal(1,"not ready for new point");
    expected_horizontal=horizontal; expected_vertical=vertical; expected_prescale=prescale;
    start=1; tick(1); start=0;
  endtask
  task await_result(input logic [7:0] expected_status, input bit expect_cleanup,expect_fatal);
    integer age;
    age=0;
    while (!result_valid && age<6000) begin tick(1); age++; end
    if (!result_valid || status !== expected_status || cleanup !== expect_cleanup || fatal !== expect_fatal)
      $fatal(1,"case %0d result status=%h expected=%h cleanup=%b fatal=%b state=%0d",
        cases,status,expected_status,cleanup,fatal,dut.state);
    if (busy || request || release_scan || cmd_valid) $fatal(1,"activity after result");
    if (!expect_fatal && (blocked || granted)) $fatal(1,"clean result still owns DRP");
    cases++;
  endtask
  task restored;
    for (integer l=0;l<4;l++) for(integer a=0;a<1024;a++)
      if (gt.mem[l][a] !== gt.original(l,a))
        $fatal(1,"restoration mismatch lane=%0d addr=%h actual=%h expected=%h",
          l,a,gt.mem[l][a],gt.original(l,a));
  endtask
  task acknowledge;
    result_ready=1; tick(1); result_ready=0; tick(1);
    if (result_valid || !start_ready) $fatal(1,"clean result did not rearm");
  endtask
  task cancel_now;
    cancel=1; tick(1); cancel=0;
  endtask

  initial begin
    defaults(); lane=2; horizontal=32; vertical=127; launch();
    await_result(0,1,0); restored();
    if(measurements!=1 || errors0!=3 || samples0!=16'h1234 || bits0!=64'd745600 ||
       gt.starts!=1 || result_horizontal!=32 || result_vertical!=127 || !result_lpm)
      $fatal(1,"LPM counters/metadata/scaling incorrect");
    // An unread result is immutable and blocks another start.
    start=1; horizontal=-32; vertical=-127; prescale=31; lpm=0;
    tick(15); start=0;
    if(start_ready || bits0!=64'd745600 || result_horizontal!=32 || gt.starts!=1)
      $fatal(1,"unread result overwritten");
    acknowledge();
    // Reuse the same instance with changed metadata and equalizer mode.
    launch(); await_result(0,1,0); restored();
    if(measurements!=3 || errors0!=3 || errors1!=9 || samples1!=16'h2345 ||
       bits0!=(64'd745600 << 31) || bits1!=((64'd80*16'h2345)<<32) ||
       result_horizontal!=-32 || result_vertical!=-127 || result_prescale!=31 ||
       result_lpm || gt.starts!=3)
      $fatal(1,"DFE raw passes or maximum-prescale scaling incorrect");
    acknowledge();

    defaults(); fast_end=1; lane=3; launch(); await_result(0,1,0); restored();
    if(measurements!=1) $fatal(1,"fast END was lost");
    defaults(); zero_samples=1; launch(); await_result(8'h20,1,0); restored();

    defaults(); horizontal=33; launch(); await_result(1,1,0); restored();
    if(gt.requests) $fatal(1,"invalid descriptor reached DRP");
    defaults(); profile=0; launch(); await_result(1,1,0); restored();
    if(gt.requests) $fatal(1,"unsupported profile reached DRP");
    defaults(); cancel=1; launch(); cancel=0; await_result(2,1,0); restored();
    if(gt.requests) $fatal(1,"simultaneously cancelled start reached DRP");
    defaults(); resetn=0; initial_control=16'h00a0; tick(2); resetn=1; tick(2);
    launch(); await_result(1,1,0); restored();
    if(gt.writes) $fatal(1,"powered-down sampler was enabled dynamically");
    defaults(); resetn=0; initial_control=16'h05a0; tick(2); resetn=1; tick(2);
    launch(); await_result(8'h40,1,0); restored();
    if(gt.writes) $fatal(1,"preexisting RUN was overwritten");
    defaults(); initial_end=1; launch(); await_result(8'h40,1,0); restored();
    if(gt.writes) $fatal(1,"preexisting END was treated as idle");

    defaults(); prbs_idle=0; launch(); tick(5); cancel_now();
    await_result(2,1,0); restored();
    if(gt.requests) $fatal(1,"cancelled acquisition reached DRP");
    defaults(); prbs_idle=0; launch(); await_result(8'h10,1,0); restored();
    if(gt.requests) $fatal(1,"lease timeout reached DRP");
    // Grant and cancel on the same edge; withdrawal must return the lease.
    defaults(); launch(); cancel_now(); await_result(2,1,0); restored();
    defaults(); launch();
    wait(gt.requests==8); @(negedge clk); cancel_now();
    await_result(2,1,0); restored();
    if(gt.writes) $fatal(1,"snapshot cancellation caused a write");

    // Cancel each individual configuration write after it has changed the
    // simulated GT, including writes whose response has not arrived yet.
    for(integer n=1;n<=23;n++) begin
      defaults(); lane=n%4; launch();
      wait(gt.writes==n); @(negedge clk); cancel_now();
      await_result(2,1,0); restored();
      if(gt.starts) $fatal(1,"cancelled configuration began sampling");
    end

    defaults(); launch(); wait(gt.starts==1); @(negedge clk); cancel_now();
    await_result(2,1,0); restored();
    defaults(); lpm=0; launch();
    wait(gt.starts==1 && !gt.active[0]); @(negedge clk); cancel_now();
    await_result(2,1,0); restored();
    if(gt.starts!=1) $fatal(1,"cancel during cleanup started second UT pass");
    defaults(); launch(); wait(gt.starts==1); @(negedge clk); healthy=0;
    await_result(4,1,0); restored();
    defaults(); lpm=0; launch(); wait(gt.starts==2); @(negedge clk); cancel_now();
    await_result(2,1,0); restored();
    if(measurements!=1) $fatal(1,"second-UT cancellation lost first raw result");
    defaults(); hold_wait=1; timeout_cycles=100; launch();
    await_result(8,1,0); restored();
    if(measurements) $fatal(1,"stale WAIT/DONE produced a measurement");
    defaults(); hold_count=1; timeout_cycles=100; launch();
    await_result(8,1,0); restored();
    defaults(); bad_config=1; launch(); await_result(8'h20,1,0); restored();

    defaults(); hold_stop=1; launch(); await_result(8'h90,0,1);
    if(!blocked || !granted) $fatal(1,"stuck stop state released ownership");

    defaults(); bad_restore=1; launch(); await_result(8'ha0,0,1);
    if(!blocked || !granted) $fatal(1,"failed restoration released ownership");
    result_ready=1; tick(5); result_ready=0;
    if(start_ready) $fatal(1,"fatal restoration failure rearmed automatically");

    defaults(); launch(); wait(gt.pending); @(negedge clk); stall=1;
    await_result(8'h10,0,1);
    if(fault!=4 || gt.writes) $fatal(1,"snapshot transport timeout misclassified");
    defaults(); launch(); wait(gt.starts==1); @(negedge clk); stall=1;
    await_result(8'h90,0,1);
    if(fault!=4 || !blocked || granted) $fatal(1,"write timeout was not quarantined");
    stall=0; tick(30);
    if(start_ready || !fatal || !result_valid || !blocked)
      $fatal(1,"late completion cleared fatal transport state");
    defaults(); launch(); wait(gt.writes==1); @(negedge clk); stall=1;
    await_result(8'h90,0,1);
    if(gt.starts || !blocked) $fatal(1,"configuration transport failure escaped quarantine");
    $display("PASS: eye scan point (%0d cases, 23 cancellation boundaries, LPM/DFE/restoration/timeout)",cases);
    $finish;
  end
  initial begin #10000000; $fatal(1,"eye point test watchdog"); end
endmodule
