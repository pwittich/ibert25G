`timescale 1ns/1ps
// Vendor-SVA reproduction, independent of all v3 RTL. The same valid source
// request drives four handshakes. Procedural monitors independently check the
// two transitions asserted by the vendor S-1/S-2 properties.
module tb_all_links_v3_xpm_repro;
  logic srcclk=0,dstclk=0,send=0;
  wire [3:0] rcv;
  always #1.55 srcclk=~srcclk;
  always #2.5 dstclk=~dstclk;
  for(genvar c=0;c<4;c++) begin : g
    logic previous=0;
    always @(posedge srcclk) begin
      if(send&&!previous&&rcv[c]) $fatal(1,"procedural rising-send violation");
      if(!send&&previous&&!rcv[c]) $fatal(1,"procedural falling-send violation");
      previous<=send;
    end
    xpm_cdc_handshake #(.WIDTH(64),.DEST_EXT_HSK(0),.DEST_SYNC_FF(2),
      .SRC_SYNC_FF(2),.SIM_ASSERT_CHK(1)) x(
      .src_clk(srcclk),.dest_clk(dstclk),.src_in(64'(c)),.src_send(send),
      .src_rcv(rcv[c]),.dest_out(),.dest_req(),.dest_ack(1'b0));
  end
  initial begin
    #200;@(negedge srcclk);send=1;
    wait(&rcv);@(negedge srcclk);send=0;
    wait(rcv==0);repeat(20) @(negedge srcclk);
    $display("PASS: independent procedural XPM handshake transition checks");$finish;
  end
endmodule
