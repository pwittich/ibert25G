`timescale 1ns/1ps
module tb_eye_scan_v1_banks;
  logic clk=0,resetn=0,session=0,acquire=0,capture=0;
  logic [27:0] tx=0,rx=0,selected=0;
  logic [1:0] tag=0;
  wire [7:0] ack_tags;
  wire [3:0] on_ack,off_ack,config_idle;
  wire [3:0] gr,gf,gi,ga,gc,gs;
  wire [31:0] reason;
  wire [895:0] diag;
  wire [1023:0] raw_records,eye_records,eye_returns;
  wire [3:0] eye_fatals;
  logic [68:0] eye_controls=0;
  for(genvar e=0;e<4;e++)begin:g_eye_return
    all_links_v3_return_pipeline #(.WIDTH(256)) p(.clk(clk),.data(eye_records[e*256+:256]),.stage_two(eye_returns[e*256+:256]));
  end
  wire ready,fault,idle,acquired,captured,applied,final_config_idle;
  always #2.5 clk=~clk;
`define BANK(NAME,OFFSET,NQ,IDX) \
  eye_scan_v1_slr_bank #(.LEFT_FIRST(OFFSET),.COUNT(NQ),.LOCALIZE_QUAD_RESET(1)) NAME ( \
    .clk_200(clk),.resetn(resetn),.controls_in({session,3'd0,acquire,1'b0,capture}), \
    .left_tx_enable_in(tx[OFFSET+:NQ]),.right_tx_enable_in(tx[14+OFFSET+:NQ]), \
    .left_rx_enable_in(rx[OFFSET+:NQ]),.right_rx_enable_in(rx[14+OFFSET+:NQ]), \
    .session_tag_in(tag),.group_session_ack_tag(ack_tags[IDX*2+:2]), \
    .group_config_idle(config_idle[IDX]),.group_session_on_ack(on_ack[IDX]),.group_session_off_ack(off_ack[IDX]), \
    .config_epoch_in(1'b0), .diagnostic_selector_in(8'h87), \
    .eye_controls_in(eye_controls),.eye_bank_packet(eye_records[IDX*256+:256]),.eye_bank_fatal(eye_fatals[IDX]), \
    .quad_diagnostic_record(raw_records[IDX*256+:256]), \
    .left_quad_selected_in(selected[OFFSET+:NQ]),.right_quad_selected_in(selected[14+OFFSET+:NQ]), \
    .group_ready(gr[IDX]),.group_fault(gf[IDX]),.group_idle(gi[IDX]), \
    .group_acquire(ga[IDX]),.group_capture(gc[IDX]),.group_session_applied(gs[IDX]), \
    .group_fault_reason(reason[IDX*8+:8]),.group_diagnostics(diag[IDX*224+:224]));
  `BANK(b0,0,3,0)
  `BANK(b1,3,4,1)
  `BANK(b2,7,4,2)
  `BANK(b3,11,3,3)
`undef BANK
  eye_scan_v1_quad_aggregate final_reduce(.clk(clk),.resetn(resetn),.session_requested(session),
    .session_tag(tag),.group_session_ack_tag(ack_tags),
    .group_config_idle(config_idle),.config_idle(final_config_idle),.group_session_on_ack(on_ack),.group_session_off_ack(off_ack),
    .group_ready(gr),.group_fault(gf),.group_idle(gi),.group_acquire(ga),.group_capture(gc),
    .group_session_applied(gs),.group_reason(reason),.group_diagnostics(diag),
    .quad_ready(ready),.quad_fault(fault),.controller_idle(idle),
    .acquisition_ready(acquired),.capture_done(captured),.tx_session_applied(applied));
  always @(negedge clk) if(resetn && tx!=0) begin
    if(session && applied &&
       (!b0.g_left_quad[0].u_managed_left.session_seen ||
        !b3.g_right_quad[2].u_managed_right.session_seen))
      $fatal(1,"transient false startup acknowledgement");
    if(!session && !applied &&
       (b0.g_left_quad[0].u_managed_left.session_seen ||
        b3.g_right_quad[2].u_managed_right.session_seen))
      $fatal(1,"transient false removal acknowledgement");
  end
  task settle;repeat(12) @(negedge clk);endtask
  initial begin
    settle();resetn=1;settle();
    if(!ready||fault||!idle||applied) $fatal(1,"all-disabled barriers invalid");
    b2.g_left_quad[0].u_managed_left.force_fault=1;settle();
    if(fault) $fatal(1,"fully disabled fault leaked");
    rx[7]=1;settle();if(!fault) $fatal(1,"enabled RX fault was masked");
    rx=0;settle();if(fault) $fatal(1,"fault not isolated after disabling");
    if(!b2.g_left_quad[0].u_managed_left.force_fault) $fatal(1,"raw fault evidence erased");
    if(raw_records[512+:32]!==32'h515300c7)
      $fatal(1,"masked quad raw diagnostic unreadable: %h",raw_records[512+:32]);
    tx='h8000001;
    b3.g_right_quad[2].u_managed_right.hold_session=1;
    session=1;tag=1;settle();if(applied) $fatal(1,"start barrier ignored selected TX");
    b3.g_right_quad[2].u_managed_right.hold_session=0;tag=3;settle();
    if(!applied) $fatal(1,"disabled TXs blocked session start");
    b3.g_right_quad[2].u_managed_right.hold_session=1;
    session=0;tag=3;settle();if(!applied) $fatal(1,"stop acknowledged before every TX removed session");
    b3.g_right_quad[2].u_managed_right.hold_session=0;tag=3;settle();
    if(applied) $fatal(1,"stop barrier did not clear");
    // Cancel before either selected TX domain acknowledges a new start.
    // Old off levels must not acknowledge the newer stop generation.
    b0.g_left_quad[0].u_managed_left.hold_session=1;
    b3.g_right_quad[2].u_managed_right.hold_session=1;
    session=1;tag=2;@(negedge clk);session=0;tag=0;settle();
    if(!applied) $fatal(1,"old off level acknowledged cancelled start");
    b0.g_left_quad[0].u_managed_left.hold_session=0;settle();
    if(!applied) $fatal(1,"partial stop generation acknowledged globally");
    b3.g_right_quad[2].u_managed_right.hold_session=0;settle();
    if(applied) $fatal(1,"cancelled start did not finish its off handshake");
    selected=1;rx=1;settle();
    if(acquired||captured) $fatal(1,"early acquisition/capture acknowledgement");
    acquire=1;capture=1;settle();
    if(!acquired||!captured) $fatal(1,"unselected quad blocked acquisition/capture");
    if(final_config_idle) $fatal(1,"busy controller declared quiescent");
    acquire=0;capture=0;settle();
    if(!final_config_idle) $fatal(1,"idle healthy subset blocked configuration");
    b2.g_left_quad[0].u_managed_left.force_fault=0;rx='1;settle();
    for(integer q=0;q<28;q++)begin : scans
      integer relq,bank,physical,age;
      relq=q%14;bank=relq<3?0:relq<7?1:relq<11?2:3;
      physical=q<14?121+q:221+q-14;
      eye_controls[6:0]=q*4+(q%4);eye_controls[17:7]=q-14;
      eye_controls[26:18]=q-14;eye_controls[31:27]=2;
      eye_controls[63:32]=1000;eye_controls[67]=1;eye_controls[68]=1;
      repeat(16)@(negedge clk);eye_controls[64]=~eye_controls[64];
      age=0;while(!eye_returns[bank*256]&&age<100)begin @(negedge clk);age++;end
      if(age>=100 || eye_returns[bank*256+64+:32]!=physical ||
         eye_returns[bank*256+20+:7]!=(q*4+(q%4)) || eye_fatals)
        $fatal(1,"eye bank dispatch failed quad %0d bank %0d record %h",q,bank,eye_returns[bank*256+:256]);
      for(integer b=0;b<4;b++) if(b!=bank&&eye_returns[b*256])$fatal(1,"multiple eye banks active");
      eye_controls[65]=1;repeat(16)@(negedge clk);eye_controls[65]=0;repeat(16)@(negedge clk);
      if(eye_returns[bank*256])$fatal(1,"eye result ACK failed");
    end
    $display("PASS: eye v1 four-bank dispatch for all 28 quads plus preserved BER/session barriers");
    $finish;
  end
endmodule
