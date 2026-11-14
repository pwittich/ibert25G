`timescale 1ns/1ps
module tb_eye_scan_drp_arbiter;
  localparam integer DEADLINE = 8;
  logic clk = 0, resetn = 0;
  always #2.5 clk = ~clk;
  logic prbs_idle = 1, eligible = 1;
  logic [39:0] prbs_addr = 0;
  logic [63:0] prbs_di = 0, gt_do = 0;
  logic [3:0] prbs_en = 0, prbs_we = 0, gt_rdy = 0;
  wire [63:0] prbs_do;
  wire [3:0] prbs_rdy;
  logic request = 0, release_scan = 0;
  logic [1:0] lane = 0;
  wire granted, blocked;
  wire [2:0] fault;
  logic valid = 0, cmd_we = 0, rsp_ready = 0;
  logic [9:0] cmd_addr = 0;
  logic [15:0] cmd_di = 0;
  wire ready, rsp_valid, rsp_error;
  wire [15:0] rsp_do;
  wire [39:0] gt_addr;
  wire [63:0] gt_di;
  wire [3:0] gt_en, gt_we;
  integer issued = 0, cases = 0;

  eye_scan_drp_arbiter #(.DRP_TIMEOUT_CYCLES(DEADLINE)) dut (
    .mgmt_clk(clk), .resetn(resetn), .prbs_idle(prbs_idle), .scan_eligible(eligible),
    .prbs_addr(prbs_addr), .prbs_di(prbs_di), .prbs_en(prbs_en), .prbs_we(prbs_we),
    .prbs_do(prbs_do), .prbs_rdy(prbs_rdy),
    .scan_request(request), .scan_lane(lane), .scan_release(release_scan),
    .scan_granted(granted), .blocked(blocked), .fault(fault),
    .cmd_valid(valid), .cmd_ready(ready), .cmd_addr(cmd_addr), .cmd_di(cmd_di),
    .cmd_we(cmd_we), .rsp_valid(rsp_valid), .rsp_ready(rsp_ready),
    .rsp_do(rsp_do), .rsp_error(rsp_error),
    .gt_addr(gt_addr), .gt_di(gt_di), .gt_en(gt_en), .gt_we(gt_we),
    .gt_do(gt_do), .gt_rdy(gt_rdy));

  always @(posedge clk) if (resetn && granted && |gt_en) begin
    issued = issued + 1;
    if (gt_en != (4'b1 << dut.lane)) $fatal(1, "DRP escaped leased lane");
  end
  always @(negedge clk) if (resetn && blocked && (|prbs_rdy || |prbs_do))
    $fatal(1, "scan completion leaked to PRBS client");

  task tick(input integer count);
    repeat (count) @(negedge clk);
  endtask
  task reset_all;
    resetn = 0; prbs_en = 0; prbs_we = 0; gt_rdy = 0;
    request = 0; release_scan = 0; valid = 0; rsp_ready = 0;
    prbs_idle = 1; eligible = 1;
    tick(3); resetn = 1; tick(2);
    if (blocked || fault || rsp_valid || gt_en) $fatal(1, "reset did not clear ownership");
  endtask
  task acquire(input integer selected_lane);
    lane = selected_lane; request = 1;
    tick(1);
    if (!granted || !blocked) $fatal(1, "eligible lease not granted");
    request = 0;
    // A later selector write must never retarget an existing lease.
    lane = (selected_lane + 1) % 4;
  endtask
  task release_clean;
    release_scan = 1; tick(1); release_scan = 0; tick(1);
    if (granted || blocked || fault) $fatal(1, "clean lease not released");
  endtask
  task launch(input bit write_op, input logic [9:0] address, input logic [15:0] data);
    integer prior;
    prior = issued;
    valid = 1; cmd_addr = address; cmd_di = data; cmd_we = write_op;
    #0.1;
    if (!ready || gt_en ||
        gt_addr[dut.lane*10 +: 10] != address ||
        gt_di[dut.lane*16 +: 16] != data || gt_we[dut.lane] != write_op)
      $fatal(1, "scan command was not offered correctly");
    tick(1); valid = 0; cmd_addr = ~address; cmd_di = ~data; cmd_we = !write_op;
    #0.1;
    if (issued != prior || ready || gt_en != (4'b1 << dut.lane))
      $fatal(1, "accepted command did not wait for its registered launch");
    tick(1);
    #0.1;
    if (issued != prior + 1 || ready || gt_en ||
        gt_addr[dut.lane*10 +: 10] != address ||
        gt_di[dut.lane*16 +: 16] != data || gt_we[dut.lane] != write_op)
      $fatal(1, "accepted DRP command changed or issued more than once");
  endtask
  task complete(input integer selected_lane, input logic [15:0] data);
    gt_do[selected_lane*16 +: 16] = data; gt_rdy = 4'b1 << selected_lane;
    tick(1); gt_rdy = 0;
    if (!rsp_valid || rsp_error || rsp_do != data) $fatal(1, "wrong scan response");
  endtask
  task consume;
    rsp_ready = 1; tick(1); rsp_ready = 0; tick(1);
    if (rsp_valid) $fatal(1, "response was not consumed");
  endtask

  initial begin
    reset_all();
    // PRBS requests have no backpressure; replies are registered one cycle.
    prbs_idle = 0; request = 1;
    prbs_addr = 40'h123456789a; prbs_di = 64'h0123456789abcdef;
    prbs_en = 4'b0101; prbs_we = 4'b0100;
    #0.1;
    if (gt_en != prbs_en || gt_we != prbs_we || gt_addr != prbs_addr || gt_di != prbs_di)
      $fatal(1, "normal DRP path altered");
    tick(1); prbs_en = 0; prbs_we = 0; prbs_idle = 1;
    tick(2);
    if (granted) $fatal(1, "lease stole an outstanding normal transaction");
    gt_do = 64'hdeadbeef11223344; gt_rdy = 1;
    #0.1;
    if (prbs_rdy) $fatal(1, "normal reply bypassed its register");
    tick(1);
    if (prbs_rdy != gt_rdy || prbs_do != gt_do) $fatal(1, "normal reply not registered correctly");
    gt_rdy = 0; tick(1);
    if (granted) $fatal(1, "lease ignored second pending lane");
    gt_rdy = 4; tick(1);
    if (granted) $fatal(1, "lease switched on same cycle as completion");
    gt_rdy = 0; tick(1);
    if (granted) $fatal(1, "lease discarded the registered normal reply");
    tick(1);
    if (!granted) $fatal(1, "drained normal transaction did not release lease");
    request = 0; release_clean(); cases++;

    eligible = 0; request = 1; tick(3);
    if (granted) $fatal(1, "ineligible lease granted");
    request = 0; eligible = 1; cases++;

    for (integer l = 0; l < 4; l++) begin
      acquire(l);
      for (integer op = 0; op < 2; op++) begin
        launch(op != 0, 10'h151 + op, 16'h1234 + l);
        // A reply from an unselected lane must not complete this command.
        gt_rdy = 4'b1 << ((l+1)%4); tick(1); gt_rdy = 0;
        if (rsp_valid || ready) $fatal(1, "unselected response completed scan command");
        tick(l);
        complete(l, 16'hd000 + l*16 + op);
        valid = 1; tick(3);
        if (ready || !rsp_valid || rsp_do != 16'hd000 + l*16 + op)
          $fatal(1, "response backpressure lost data or accepted another command");
        valid = 0; consume(); cases++;
      end
      release_clean();
    end

    // A held old RDY may delay launch, but must never be accepted as the
    // queued command's response. The queued bundle is independent of the
    // caller immediately after acceptance.
    acquire(1); gt_rdy=2; valid=1; cmd_addr=10'h04f; cmd_di=16'h8120; cmd_we=1;
    begin
      integer prior;
      prior=issued;
      tick(1); valid=0; cmd_addr=0; cmd_di=0; cmd_we=0; tick(2);
      if(issued!=prior || gt_en || rsp_valid || ready)
        $fatal(1,"queued operation consumed an old RDY or launched before quiet");
      gt_rdy=0; tick(1);
      if(issued!=prior+1 || gt_addr[10+:10]!=10'h04f || gt_di[16+:16]!=16'h8120)
        $fatal(1,"queued operation lost its held descriptor");
    end
    complete(1,16'habcd); consume(); release_clean(); cases++;

    // A port that never becomes quiet has a bounded queued-command timeout.
    acquire(0); gt_rdy=1; valid=1; tick(1); valid=0; tick(DEADLINE);
    if(fault!=4 || !rsp_valid || !rsp_error || gt_en || granted)
      $fatal(1,"queued launch wait was not bounded/quarantined");
    gt_rdy=0; consume(); cases++; reset_all();

    // Cancellation is implemented by the upper scan sequencer restoring
    // registers, then releasing. Defer release across transaction AND result.
    acquire(2); launch(1, 10'h03c, 16'h0123);
    release_scan = 1; tick(2);
    if (!granted || gt_en || ready) $fatal(1, "early release reassigned live port");
    complete(2, 16'h4567); tick(2);
    if (!granted || !rsp_valid) $fatal(1, "release discarded unread response");
    consume(); release_scan = 0; tick(2);
    if (blocked) $fatal(1, "deferred release did not finish");
    cases++;

    // A simultaneous normal request is blocked, retained as a fault, and
    // scan cleanup remains possible before permanent quarantine.
    acquire(1); prbs_en = 4'b1000; tick(1); prbs_en = 0;
    if (fault != 1 || gt_en || prbs_rdy) $fatal(1, "ownership conflict not contained");
    launch(1, 10'h03c, 16'hbeef); complete(1, 0); consume();
    release_scan = 1; tick(1); release_scan = 0;
    if (!blocked || granted || fault != 1) $fatal(1, "conflicted lease escaped quarantine");
    prbs_en = 1; valid = 1; request = 1; tick(2);
    if (gt_en || ready || granted) $fatal(1, "quarantine allowed another transaction");
    cases++; reset_all();

    acquire(0); eligible = 0; tick(1); eligible = 1;
    if (fault != 2) $fatal(1, "eligibility violation lost");
    launch(1, 10'h03d, 16'h4321); complete(0, 0); consume();
    release_scan = 1; tick(1); release_scan = 0;
    if (!blocked || granted || fault != 2) $fatal(1, "eligibility fault did not quarantine");
    cases++; reset_all();

    // Last permitted DRPRDY wins over timeout on the deadline edge.
    acquire(3); launch(0, 10'h251, 0); tick(DEADLINE-1);
    complete(3, 16'h5555); consume(); release_clean(); cases++;

    // Missing completion produces one bounded error result; late DRPRDY and
    // repeated acquire/release cannot alias into PRBS or a second scan.
    acquire(3); launch(0, 10'h252, 0); tick(DEADLINE);
    if (fault != 4 || !rsp_valid || !rsp_error || granted || !blocked || gt_en)
      $fatal(1, "scan timeout not bounded/quarantined");
    gt_rdy = 8; gt_do = '1; tick(2); gt_rdy = 0;
    if (!rsp_error || rsp_do != 0) $fatal(1, "late response changed timeout result");
    consume(); request = 1; release_scan = 1; prbs_en = 1; valid = 1; tick(4);
    if (granted || gt_en || ready || prbs_rdy) $fatal(1, "timed-out port reused");
    cases++; reset_all();
    // Reset masks DRP immediately, even with an offered command.
    acquire(0); valid = 1; resetn = 0; #0.1;
    if (gt_en || ready || granted || prbs_rdy) $fatal(1, "reset emitted DRP operation");
    $display("PASS: eye scan DRP ownership (%0d scenarios, %0d scan operations)", cases, issued);
    $finish;
  end
  initial begin #100000; $fatal(1, "testbench watchdog"); end
endmodule
