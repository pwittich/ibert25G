`timescale 1ns/1ps
// Existing v5 engine and three real PRBS/quad/reset-policy controllers.
// Wiring mirrors managed_firefly1_group_wrapper (AND ready/capture, OR fault,
// scalar reset broadcast). Only GT analog behavior, DRP data, and CPU are modeled.
// Keep the real 200000-cycle acquisition observation; shorten reset/timeout only.
module tb_firefly1_v5_subset;
  logic clk=0, resetn=0;
  always #2.5 clk=~clk;
  logic [2:0] rxclk=0;
  always #1.551 rxclk[0]=~rxclk[0];
  always #1.553 rxclk[1]=~rxclk[1];
  always #1.557 rxclk[2]=~rxclk[2];
  wire [2:0] ready,idle,qfault,pfault,acqready,capdone,reset_all,lane_reset;
  wire acquire,measure,controls,capture,session,irq;
  wire [111:0] running,counter_reset;
  wire [335:0] txsel,rxsel;
  wire [2:0] loopback;
  wire [11:0] locked;
  logic [11:0] missing_lock=12'h200, error_mask=12'h200;
  logic physical_missing_reset=0;
  wire [1791:0] errors;
  wire [111:0] clocks,resets;
  wire [383:0] exact_counts;
  wire [11:0] exact_valid,exact_saturated;
  for (genvar l=0;l<112;l++) begin : lane_wiring
    if (l<12) begin
      assign clocks[l]=rxclk[l/4];
      assign resets[l]=lane_reset[l/4];
      assign errors[l*16+:16]={15'd0,error_mask[l]};
    end else begin
      assign clocks[l]=clk; assign resets[l]=0;
      assign errors[l*16+:16]=0;
    end
  end
  for (genvar q=0;q<3;q++) begin : quad
    logic gt_done=0,previous_reset=1;
    integer delay_count=0;
    wire checker_enable,runtime_reset,restart;
    wire [3:0] drpen;
    logic [3:0] drprdy=0;
    wire [3:0] rx_done={4{gt_done}} &
      ((q==2 && physical_missing_reset) ? 4'hd : 4'hf);
    always @(posedge clk) begin
      previous_reset<=reset_all[q]; drprdy<=drpen;
      if (!resetn || reset_all[q]) begin gt_done<=0;delay_count<=8;end
      else if (delay_count!=0) begin
        delay_count<=delay_count-1;
        if(delay_count==1) gt_done<=1;
      end
    end
    for(genvar l=0;l<4;l++) begin
      assign locked[q*4+l]=gt_done && checker_enable && !missing_lock[q*4+l] &&
        rxsel[(q*4+l)*3+:3]==5;
    end
    gt_quad_controller #(.RESET_HOLD_CYCLES(8),.INIT_TIMEOUT_CYCLES(200)) supervisor (
      .mgmt_clk(clk),.resetn(resetn),.gtpowergood_async(4'hf),
      .qpll0lock_async(gt_done),.tx_userclk_active_async(gt_done),
      .rx_userclk_active_async(gt_done),.txresetdone_async({4{gt_done}}),
      .rxresetdone_async(rx_done),.runtime_rx_reset_active(runtime_reset),
      .runtime_quad_restart_request(restart),.gtwiz_reset_all(reset_all[q]),
      .quad_ready(ready[q]),.quad_fault(qfault[q]),.fault_reason(),.state(),.diagnostic_live());
    managed_quad124_lane_reset_policy policy (
      .rx_clk(rxclk[q]),.resetn(resetn),.quad_ready(ready[q]),
      .acquisition_active(acquire),.lane_rx_reset(lane_reset[q]));
    gt_prbs_test_controller #(.STAGED_RX_ACQUISITION(1),
      .REQUIRE_ERROR_FREE_QUALIFICATION(0),.OPERATION_TIMEOUT_CYCLES(300000)) prbs (
      .mgmt_clk(clk),.resetn(resetn),.lane_running_async(running[q*4+:4]),
      .rx_prbs_locked_async(locked[q*4+:4]),.rx_prbs_error_async(error_mask[q*4+:4]),
      .requested_loopback(loopback),.acquisition_active(acquire),
      .measurement_enable(measure),.rx_clock_heartbeat_async(rxclk[q]),
      .result_capture_request(capture),.gtwiz_reset_rx_done_async(gt_done),
      .rxresetdone_async(rx_done),.rxpmaresetdone_async({4{gt_done}}),.quad_ready(ready[q]),
      .applied_loopback(),.gtwiz_reset_rx_datapath(),.rxpmareset(),
      .sequenced_prbs_counter_reset(),.rx_checker_enable(checker_enable),
      .acquisition_ready(acqready[q]),.runtime_rx_reset_active(runtime_reset),
      .quad_restart_request(restart),.controller_idle(idle[q]),.controller_fault(pfault[q]),
      .diagnostic_state(),.diagnostic_live(),.diagnostic_rx(),.diagnostic_counter(),
      .recovery_diagnostics(),.drpaddr(),.drpclk(),.drpdi(),.drpen(drpen),.drpwe(),
      .drpdo(64'd0),.drprdy(drprdy),.result_capture_done(capdone[q]),
      .exact_error_counts(exact_counts[q*128+:128]),.exact_error_valid(exact_valid[q*4+:4]),
      .exact_error_saturated(exact_saturated[q*4+:4]));
  end
  logic write=0;
  logic [11:0] wa=0;
  logic [31:0] wd=0;
  gt_test_engine_core #(.ENABLE_TX_SESSION(1),.HARDWARE_VERSION(32'h00020304),
    .MANAGED_LANE_MASK(112'hfff)) core (
    .mgmt_clk(clk),.mgmt_resetn(resetn),.reg_write(write),.reg_write_address(wa),
    .reg_write_data(wd),.reg_write_strobe(4'hf),.reg_read_address(12'd0),.reg_read_data(),
    .interrupt(irq),.status_firmware_alive(),.status_engine_busy(),.status_fault(),
    .platform_ready((&ready)&&(&idle)),.platform_fault((|qfault)||(|pfault)),
    .platform_status(32'd0),.platform_diagnostics(224'd0),.recovery_diagnostics(256'd0),
    .diagnostic_record(256'd0),.diagnostic_selector(),.diagnostic_bank(),.engine_protocol_debug(),
    .acquisition_ready(&acqready),.result_capture_done(&capdone),
    .exact_error_counts({3200'd0,exact_counts}),.exact_error_valid({100'd0,exact_valid}),
    .exact_error_saturated({100'd0,exact_saturated}),.mailbox_i2c_address(8'd0),
    .mailbox_i2c_write(1'b0),.mailbox_i2c_write_data(8'd0),.mailbox_i2c_read_data(),
    .mailbox_i2c_read_data_next(),.rx_clk(clocks),.rx_reset(resets),
    .rx_prbs_locked({100'd0,locked}),.rx_cdr_locked({112{1'b1}}),.rx_prbs_errors(errors),
    .tx_prbs_select(txsel),.rx_prbs_select(rxsel),.prbs_counter_reset(counter_reset),
    .lane_running(running),.loopback_mode(loopback),.measurement_enable(measure),
    .measurement_run_toggle(),.controls_enable(controls),.acquisition_active(acquire),
    .result_capture_request(capture),.tx_error_inject_toggle(),.tx_session_active(session),
    .tx_session_ready(session));
  task automatic wr(input logic [11:0] a,input logic [31:0] d);
    @(negedge clk);wa=a;wd=d;write=1;
    @(negedge clk);write=0;
  endtask
  task automatic fresh;
    resetn=0;repeat(8) @(negedge clk);resetn=1;
    wait((&ready)&&(&idle));repeat(10) @(negedge clk);
  endtask
  task automatic descriptor;
    wr(12'h00c,4);wr(12'h020,32'h501);wr(12'h024,1000);wr(12'h02c,32'hdff);
  endtask
  task automatic start_session;
    wr(12'h10c,10000);wr(12'h100,1);
    if(!session) $fatal(1,"session failed to start");
  endtask
  logic [255:0] record_value;
  task automatic check_clean(input integer expected_run);
    wait(irq);repeat(8) @(negedge clk);
    if(core.run_id!=expected_run || core.aggregate_summary!=32'h000b0b01)
      $fatal(1,"subset summary/run %h/%d",core.aggregate_summary,core.run_id);
    for(integer l=0;l<12;l++) begin
      record_value=core.published_bank?core.result_bank_1[l]:core.result_bank_0[l];
      if(l==9) begin
        if(record_value!={224'd0,32'd9}) $fatal(1,"excluded lane9 record %h",record_value);
      end else if(record_value[31:0]!=(32'h1800|l) || record_value[95:32]!=0 ||
                  record_value[159:96]==0 || record_value[191:160]!=0 ||
                  record_value[255:192]==0)
        $fatal(1,"selected lane%0d record %h",l,record_value);
    end
    wait((&idle)&&(&ready));repeat(16) @(negedge clk);
    if(qfault || pfault || running || !session) $fatal(1,"unclean subset publication/cleanup");
    $display("PASS: subset run%0d all3quads mask0DFF lane9 permanently unlocked/error-active, atomic11lane publication/cleanup",expected_run);
  endtask
  initial begin
    fresh();descriptor();wr(12'h00c,1);repeat(8) @(negedge clk);
    if(!core.bad_command || core.state!=0 || core.run_id!=0)
      $fatal(1,"external request without session accepted");
    descriptor();start_session();wr(12'h00c,1);check_clean(1);
    descriptor();wr(12'h00c,1);check_clean(2);
    wr(12'h100,2);if(session) $fatal(1,"idle explicit stop failed");
    // A selected unlocked lane must still fail, not shrink the accepted mask.
    fresh();missing_lock=12'h201;descriptor();start_session();wr(12'h00c,1);
    wait(irq);repeat(8) @(negedge clk);
    if(core.run_id!=1 || core.aggregate_summary!=32'h0b000b04 || pfault!=3'b001 || session)
      $fatal(1,"selected lane missing lock must fault all11 requested records: %h fault%h",core.aggregate_summary,pfault);
    $display("PASS: selected lane0 missing lock times out, exact11lane failure publication, TX fault policy unchanged");
    // PRBS masking never bypasses physical reset readiness of excluded lane9.
    missing_lock=12'h200;fresh();physical_missing_reset=1;
    wait(qfault[2]);repeat(8) @(negedge clk);
    if(ready[2]) $fatal(1,"excluded lane physical reset failure ignored");
    $display("PASS: excluded lane9 physical reset loss still faults quad123");
    $display("PASS: v5 three-quad subset suite");$finish;
  end
  initial begin
    repeat(1200000) @(posedge clk);
    $fatal(1,"subset watchdog core%0d ready%h idle%h acquire%h fault%h",core.state,ready,idle,acqready,pfault);
  end
endmodule
