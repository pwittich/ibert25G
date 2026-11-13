`timescale 1ns/1ps
module tb_all_links_v3_engine #(parameter integer EXTRA_ACK_DELAY=0);
  logic clk=0, raw_rxclk=0, resetn=0, write=0;
  logic [11:0] wa=0,ra=0;
  logic [31:0] wd=0;
  wire [31:0] rd;
  wire [27:0] tx,rx;
  wire epoch,session,irq;
  wire [1:0] session_tag;
  logic force_pending_stop=0, controllers_idle=1;
  logic [27:0] clocks='1;
  logic [111:0] native_valid=0;
  wire [3583:0] native_counts={112{32'd7}};
  wire [111:0] rxclks;
  always #2.5 clk=~clk;
  always #1.55 raw_rxclk=~raw_rxclk;
  for(genvar q=0;q<28;q++) begin
    assign rxclks[q*4+:4]={4{raw_rxclk&&clocks[q]}};
  end
  all_links_v3_engine_core #(.ENABLE_TX_SESSION(1),
    .CONFIG_TIMEOUT_CYCLES(2000),.SNAPSHOT_VENDOR_ASSERTIONS(0),.SESSION_CYCLES_PER_MS(200),
    .LOCALIZE_DESCRIPTOR_CONTROLS(1),.HARDWARE_VERSION(32'h00020502),
    .ASYNC_SNAPSHOT_MASK({112{1'b1}})) dut(
    .mgmt_clk(clk),.mgmt_resetn(resetn),.reg_write(write),
    .reg_write_address(wa),.reg_write_data(wd),.reg_write_strobe(4'hf),
    .reg_read_address(ra),.reg_read_data(rd),.interrupt(irq),
    .platform_ready(1'b1),.config_controllers_idle(controllers_idle),.platform_fault(1'b0),.platform_status(32'd0),
    .platform_diagnostics(224'd0),.recovery_diagnostics(256'd0),
    .diagnostic_record(256'd0),.acquisition_ready(1'b1),.result_capture_done(1'b1),
    .exact_error_counts(native_counts),.exact_error_valid(native_valid),.exact_error_saturated(112'd0),
    .mailbox_i2c_address(8'd0),.mailbox_i2c_write(1'b0),.mailbox_i2c_write_data(8'd0),
    .rx_clk(rxclks),.rx_reset(112'd0),.rx_prbs_locked({112{1'b1}}),
    .rx_cdr_locked({112{1'b1}}),.rx_prbs_errors(1792'd0),
    .tx_session_active(session),.session_tag(session_tag),.tx_session_ready(session||force_pending_stop),
    .config_tx_mask(tx),.config_rx_mask(rx),.config_epoch(epoch),
    .config_tx_observed(tx),.config_bank_epoch_ack({28{epoch}}));
  // Model independently delayed return data/phase, as allowed by the
  // guarded management transfer's physical timing contract.
  if(EXTRA_ACK_DELAY) begin : g_delayed_ack
    wire [3:0] raw_ok={dut.u_config_ack_slr3.group_ok,dut.u_config_ack_slr2.group_ok,
      dut.u_config_ack_slr1.group_ok,dut.u_config_ack_slr0.group_ok};
    wire [3:0] raw_phase={dut.u_config_ack_slr3.group_phase,dut.u_config_ack_slr2.group_phase,
      dut.u_config_ack_slr1.group_phase,dut.u_config_ack_slr0.group_phase};
    logic [3:0] ok_first=0,ok_second=0,phase_first=0;
    always @(posedge clk) begin
      ok_first<=raw_ok;ok_second<=ok_first;phase_first<=raw_phase;
    end
    initial begin
      force dut.config_group_ok=ok_second;
      force dut.config_group_phase=phase_first;
    end
  end
  // Equivalent transition checks to XPM S-1/S-2, with separate history
  // per instance; also prove the entire payload stays stable while sent.
  for(genvar l=0;l<112;l++) begin : g_monitor_lane
    logic previous_send=0;
    logic [255:0] previous_payload=0;
    always @(posedge rxclks[l]) begin
      if(dut.snapshot_send[l] && previous_send &&
         dut.snapshot_payload_raw[l*256+:256] !== previous_payload)
        $fatal(1,"snapshot changed while pending, lane %d",l);
      previous_send <= dut.snapshot_send[l];
      previous_payload <= dut.snapshot_payload_raw[l*256+:256];
    end
    for(genvar c=0;c<4;c++) begin : g_monitor_chunk
      logic previous=0;
      wire rcv=dut.g_lane[l].g_managed.g_snapshot_cdc.g_split_snapshot.chunk_rcv[c];
      always @(posedge rxclks[l]) begin
        if(dut.snapshot_send[l] && !previous && rcv)
          $fatal(1,"new snapshot before previous handshake cleared, lane/chunk %d/%d",l,c);
        if(!dut.snapshot_send[l] && previous && !rcv)
          $fatal(1,"snapshot removed before capture acknowledgement, lane/chunk %d/%d",l,c);
        previous <= dut.snapshot_send[l];
      end
    end
  end
  task wr(input [11:0] a,input [31:0] d);
    @(negedge clk);wa=a;wd=d;write=1;
    @(negedge clk);write=0;
  endtask
  task config_masks(input [27:0] t,input [27:0] r);
    wr('h120,t);wr('h124,r);wr('h128,1);
    ra='h12c;
    repeat(180) @(negedge clk);
    if(rd!=9) $fatal(1,"config failed %h tx=%h rx=%h",rd,t,r);
  endtask
  task descriptor(input [111:0] mask,input [31:0] control);
    wr('hc,4);wr('h20,control);wr('h24,120);wr('h28,15000);
    wr('h2c,mask[31:0]);wr('h30,mask[63:32]);
    wr('h34,mask[95:64]);wr('h38,{16'd0,mask[111:96]});
    wr('hc,1);
  endtask
  task expect_reject(input [111:0] mask,input [31:0] ctrl);
    descriptor(mask,ctrl);repeat(5) @(negedge clk);
    if(!irq || !dut.bad_command || dut.state!=0) $fatal(1,"descriptor accepted unexpectedly");
  endtask
  task run_rx(input [111:0] mask);
    descriptor(mask,'h501);
    for(integer i=0;i<18000 && !irq;i++) @(negedge clk);
    if(!irq||dut.bad_command||dut.aggregate_summary[7:0]!=1)
      $fatal(1,"run failed summary=%h state=%d",dut.aggregate_summary,dut.state);
    if(dut.selected_count!=dut.passed_count || dut.failed_count!=0)
      $fatal(1,"bad lane counts");
    // Inspect the entire published bank: disabled lanes must never retain
    // selected flags, exposures, errors, or old-run payloads.
    for(integer l=0;l<112;l++) begin
      wr('h3c,l);repeat(3) @(negedge clk);ra='h40;#1;
      if(rd[11]!==mask[l] || rd[7:0]!=l) $fatal(1,"stale selection lane %d status=%h",l,rd);
      if(!mask[l]) begin
        ra='h4c;#1;if(rd!=0) $fatal(1,"disabled lane exposure");
        if(!rx[l/4]) begin
          ra='h44;#1;if(rd!=0) $fatal(1,"disabled lane retained native errors");
        end
      end
    end
  endtask
  initial begin
    repeat(8) @(negedge clk);resetn=1;repeat(8) @(negedge clk);
    expect_reject(112'd1,'h501);
    controllers_idle=0;
    wr('h120,1);wr('h124,1);wr('h128,1);ra='h120;#1;
    if(rd!=0) $fatal(1,"configuration changed during post-capture cleanup");
    controllers_idle=1;config_masks(0,1);
    // Unselected and RX-disabled quads have no clocks at all.
    clocks=1;
    run_rx(112'd15);
    // Two skipped config transactions return the request level to the same
    // value. Re-enable a stopped clock and prove old toggle phases are rebased.
    config_masks(0,0);config_masks(0,0);
    clocks=0;native_valid=112'd15;
    wr('h120,0);wr('h124,'h8000000);wr('h128,1);ra='h12c;
    repeat(180) @(negedge clk);
    if(!rd[1] || rd[0]) $fatal(1,"missing enabled RX clock acknowledged configuration");
    clocks='h8000000;repeat(180) @(negedge clk);
    if(rd!=9) $fatal(1,"returned RX clock did not complete rearm");
    run_rx(112'hf000000000000000000000000000);
    expect_reject(112'd1,'h501);
    expect_reject(112'hf000000000000000000000000000,'h1501);
    native_valid=0;clocks='1;config_masks('hfffffff,'hfffffff);
    wr('h10c,100);wr('h100,1);repeat(4) @(negedge clk);
    wr('h120,0);ra='h120;#1;if(rd!='hfffffff) $fatal(1,"changed config under session");
    force_pending_stop=1;wr('h100,2);repeat(4) @(negedge clk);
    if(session || session_tag!=3) $fatal(1,"stop tag missing");
    wr('h100,1);repeat(4) @(negedge clk);
    if(session || session_tag!=3) $fatal(1,"new start accepted with stop still pending");
    wr('h120,0);wr('h124,0);wr('h128,1);ra='h120;#1;
    if(rd!='hfffffff) $fatal(1,"config changed before stop acknowledgement");
    force_pending_stop=0;
    config_masks(0,'hfffffff);
    run_rx({112{1'b1}});
    config_masks(1,1);
    wr('h10c,1);wr('h100,1);repeat(4) @(negedge clk);
    if(!session || session_tag!=2) $fatal(1,"next start Gray tag wrong");
    repeat(230) @(negedge clk);
    if(session || session_tag!=0 || !dut.session_expired) $fatal(1,"lease expiry tag missing");
    repeat(20) @(negedge clk);
    if(session_tag!=0) $fatal(1,"lease expiry tag changed repeatedly");
    $display("PASS: v3 engine disabled clocks, RX-only, all112, epochs, selection and session guards");
    $finish;
  end
endmodule
