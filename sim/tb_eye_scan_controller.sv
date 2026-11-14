`timescale 1ns/1ps
module tb_eye_scan_controller;
  logic clk=0,resetn=0,write=0;
  always #2.5 clk=~clk;
  logic [11:0] address=0,read_address=12'h158;
  logic [31:0] data=0;
  logic [3:0] strobe=15;
  wire [31:0] read_data;
  logic eligible=1,local_tx=0,link_fatal=0;
  logic [31:0] session_ms=2000;
  logic [27:0] rx_mask='1;
  wire [68:0] controls;
  wire locked,fatal;
  wire [255:0] progress,page;
  logic [255:0] packet=0;
  logic phase_seen=0,pending=0;
  integer delay_left=0,launches=0,cases=0;
  logic [68:0] accepted=0;
  logic [7:0] fake_status=0;
  logic fake_fatal=0,wrong_tag=0,stall=0;
  eye_scan_controller #(.CYCLES_PER_MS(20),.MAX_POINTS(16),.PRELOAD_CYCLES(4)) dut (
    .clk(clk),.resetn(resetn),.write(write),.address(address),.read_address(read_address),
    .data(data),.strobe(strobe),.read_data(read_data),.eligible(eligible),
    .local_tx_required(local_tx),.local_session_remaining_ms(session_ms),.rx_mask(rx_mask),
    .link_fatal(link_fatal),.point_packet(packet),.controls(controls),.lock(locked),
    .fatal(fatal),.progress_record(progress),.page_record(page));
  always @(posedge clk) begin : point_model
    logic [31:0] metadata;
    if(!resetn) begin packet<=0;phase_seen<=0;pending<=0;launches=0; end
    else begin
      if(controls[64]!=phase_seen) begin
        if(pending || packet[0]) $fatal(1,"second point before prior ACK");
        phase_seen<=controls[64];accepted<=controls;pending<=1;delay_left<=30;
        launches=launches+1;
      end
      if(pending && !stall) begin
        if(delay_left==0 || controls[66]) begin
          metadata=0;metadata[0]=1;metadata[1]=accepted[64]^wrong_tag;
          metadata[2]=fake_fatal;metadata[3]=!fake_fatal;metadata[5:4]=1;
          metadata[13:6]=controls[66]?8'h2:fake_status;metadata[14]=1;
          metadata[19:15]=accepted[31:27];metadata[26:20]=accepted[6:0];
          packet<={64'd0,32'h50020101,32'd30,32'd0,32'h12340003,
            12'd0,accepted[26:18],accepted[17:7],metadata};pending<=0;
        end else delay_left<=delay_left-1;
      end
      if(controls[65] && packet[0]) packet[0]<=0;
    end
  end
  task tick(input integer n);repeat(n)@(negedge clk);endtask
  task wr(input logic[11:0] a,input logic[31:0] d);
    address=a;data=d;write=1;tick(1);write=0;tick(1);
  endtask
  function automatic [31:0] hword(input integer hf,hl,hs,lane);
    hword=lane|((hf&127)<<7)|((hl&127)<<14)|(hs<<21);
  endfunction
  function automatic [31:0] vword(input integer vf,vl,vs);
    vword=(vf&255)|((vl&255)<<8)|(vs<<16);
  endfunction
  task configure(input integer hf,hl,hs,vf,vl,vs,budget);
    wr('h140,hword(hf,hl,hs,60));wr('h144,vword(vf,vl,vs));
    wr('h148,4);wr('h14c,budget);wr('h150,10000);
  endtask
  task defaults;
    resetn=0;write=0;eligible=1;local_tx=0;link_fatal=0;session_ms=2000;
    rx_mask='1;fake_status=0;fake_fatal=0;wrong_tag=0;stall=0;strobe=15;
    read_address='h158;tick(4);resetn=1;tick(2);
  endtask
  task finish_job;
    integer age;
    age=0;read_address='h158;
    while((read_data[0] || !read_data[1]) && age<5000)begin tick(1);age++;end
    if(age>=5000 || !read_data[1] || read_data[0])$fatal(1,"scan did not finish");
    cases++;
  endtask
  task select_page(input integer n);
    wr('h15c,n);tick(3);
    if(page[31:0]!=32'h45594401)$fatal(1,"missing page schema");
  endtask
  initial begin
    defaults();configure(-2,2,2,-1,1,2,1000);wr('h154,1);
    if(!locked)$fatal(1,"scan did not lock BER/config");
    wait(dut.count==1);@(negedge clk);
    select_page(0);
    if($signed(page[106:96])!=-2 || $signed(page[115:107])!=-1)
      $fatal(1,"first point offsets wrong");
    wr('h140,0); // competing shadow write must be rejected without changing job
    finish_job();
    if(dut.count!=6 || dut.planned!=6 || launches!=6 || fatal || locked || dut.reason)
      $fatal(1,"normal grid count/state incorrect");
    for(integer n=0;n<6;n++) begin
      select_page(n);
      if(page[63:32]!=1 || $signed(page[106:96])!=-2+(n%3)*2 ||
         $signed(page[115:107])!=-1+(n/3)*2 || page[159:128]!=32'h12340003)
        $fatal(1,"grid ordering/raw record changed at %0d",n);
    end
    wr('h154,1);tick(10);
    if(dut.job_id!=1 || dut.count!=6 || launches!=6)$fatal(1,"unread matrix overwritten");
    wr('h154,4);tick(3);
    if(dut.available || dut.count || page!=0)$fatal(1,"explicit ACK did not hide old BRAM");
    configure(0,0,1,0,0,1,1000);wr('h154,1);finish_job();
    if(dut.job_id!=2 || dut.count!=1 || launches!=7)$fatal(1,"same-instance next scan failed");

    defaults();configure(-4,4,1,-1,1,1,1000);wr('h154,1);finish_job();
    if(!dut.reason[0] || launches || dut.count || fatal)$fatal(1,"oversized matrix was sampled");
    defaults();configure(0,0,1,0,0,1,1000);local_tx=1;session_ms=1005;wr('h154,1);
    if(locked || !dut.rejected || launches)$fatal(1,"insufficient TX budget admitted");cases++;
    defaults();configure(0,0,1,0,0,1,1000);rx_mask=0;wr('h154,1);
    if(locked || !dut.rejected || launches)$fatal(1,"disabled RX admitted");cases++;
    defaults();configure(0,0,1,0,0,1,1000);eligible=0;wr('h154,1);
    if(locked || !dut.rejected)$fatal(1,"ineligible scan admitted");cases++;
    defaults();configure(0,0,1,0,0,1,1000);strobe=1;wr('h154,1);strobe=15;
    if(locked || !dut.rejected)$fatal(1,"partial doorbell admitted");cases++;

    defaults();configure(-4,4,1,-1,1,1,1000);wr('h154,1);wr('h154,2);finish_job();
    if(!dut.reason[1] || launches || fatal)$fatal(1,"validation cancellation sampled GT");
    defaults();configure(-2,2,1,0,0,1,1000);wr('h154,1);
    wait(launches==1);@(negedge clk);wr('h154,2);finish_job();
    if(!dut.reason[1] || dut.count!=1 || launches!=1 || fatal)$fatal(1,"active cancel lost cleanup/result");
    defaults();fake_status=8'h08;configure(-2,2,1,0,0,1,1000);wr('h154,1);finish_job();
    if(dut.count!=1 || launches!=1 || dut.reason[15:8]!=8 || fatal)$fatal(1,"failed point retried");
    defaults();fake_fatal=1;configure(0,0,1,0,0,1,1000);wr('h154,1);finish_job();
    if(!fatal || !locked || controls[65] || dut.count!=1)$fatal(1,"fatal point released owner");
    wr('h154,4);configure(0,0,1,0,0,1,1000);wr('h154,1);
    if(!locked || launches!=1 || dut.job_id!=1)$fatal(1,"fatal scan rearmed");
    defaults();wrong_tag=1;configure(0,0,1,0,0,1,1000);wr('h154,1);finish_job();
    if(!fatal || !dut.reason[7] || dut.count)$fatal(1,"stale tagged result accepted");
    defaults();stall=1;configure(0,0,1,0,0,1,11);wr('h154,1);finish_job();
    if(!fatal || !dut.reason[3] || !dut.reason[7] || !controls[66] || controls[67])
      $fatal(1,"expired job did not retain cancel/lock");
    $display("PASS: eye scan global controller (%0d cases, grid/storage/budgets/cancel/fatal)",cases);
    $finish;
  end
  initial begin #1000000;$fatal(1,"global eye controller watchdog");end
endmodule
