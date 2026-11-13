`timescale 1ns/1ps
module tb_all_links_v3_config;
  logic clk=0, resetn=0, eligible=1, write=0;
  logic [11:0] address=0;
  logic [31:0] data=0;
  logic [3:0] strobe=15;
  wire [27:0] tx,rx;
  wire epoch,busy,usable;
  wire [255:0] record;
  logic return_enabled=1;
  logic [27:0] seen_tx=0,seen_rx=0,seen_epoch=0;
  always #2.5 clk=~clk;
  always @(posedge clk) if(return_enabled) begin
    seen_tx<=tx;seen_rx<=rx;seen_epoch<={28{epoch}};
  end
  all_links_v3_config #(.APPLY_TIMEOUT_CYCLES(100)) dut(
    .clk(clk),.resetn(resetn),.eligible(eligible),.barrier_clear(1'b1),
    .application_settled(seen_tx==tx && seen_rx==rx && seen_epoch=={28{epoch}}),.write(write),
    .address(address),.data(data),.strobe(strobe),
    .tx_observed(seen_tx),.rx_observed(seen_rx),.epoch_ack(seen_epoch),
    .tx_mask(tx),.rx_mask(rx),.epoch(epoch),.busy(busy),.usable(usable),.record(record));
  task wr(input [11:0] a,input [31:0] d);
    @(negedge clk);address=a;data=d;write=1;
    @(negedge clk);write=0;
  endtask
  task apply_masks(input [27:0] t,input [27:0] r);
    wr('h120,t);wr('h124,r);wr('h128,1);
    repeat(80) @(negedge clk);
    if(!usable || busy || tx!=t || rx!=r || record[255:224]!=0)
      $fatal(1,"configuration did not complete");
  endtask
  initial begin
    repeat(4) @(negedge clk);resetn=1;
    if(tx!=0||rx!=0||usable) $fatal(1,"unsafe startup");
    apply_masks(0,0);apply_masks('hfffffff,'hfffffff);
    eligible=0;wr('h120,0);wr('h128,1);
    if(tx!='hfffffff || record[255:224]!=1) $fatal(1,"busy write accepted");
    eligible=1;wr('h120,'hf0000000);wr('h128,1);
    if(tx!='hfffffff) $fatal(1,"reserved bits accepted");
    strobe=1;wr('h120,0);strobe=15;
    if(tx!='hfffffff || record[255:224]!=1) $fatal(1,"partial write accepted");
    apply_masks('h0123456,0);apply_masks(0,'h0654321);
    apply_masks(1,1);apply_masks(0,0);apply_masks('h8000000,'h8000000);
    return_enabled=0;wr('h120,0);wr('h124,0);wr('h128,1);
    repeat(110) @(negedge clk);
    if(usable||busy||tx!=0||rx!=0||record[255:224]!=2)
      $fatal(1,"application timeout did not fail closed");
    return_enabled=1;apply_masks(0,0);
    $display("PASS: v3 config startup, masks, atomic apply, rejection, timeout and recovery");
    $finish;
  end
endmodule
