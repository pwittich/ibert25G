`timescale 1ns/1ps
module tb_eye_scan_v1_quad;
  logic clk=0,refclk=0,resetn=0;
  always #2.5 clk=~clk;
  always #1.55 refclk=~refclk;
  logic [68:0] controls=0;
  wire [255:0] packet;
  wire fatal,ready,quad_fault;
  managed_eye_scan_v1_quad_wrapper #(.QUAD(121),.ALL_LINKS_LEFT_V1(1)) dut (
    .mgmt_clk(clk),.resetn(resetn),.eye_controls(controls),.eye_packet(packet),.eye_fatal(fatal),
    .session_tag(2'd0),.tx_enable(1'b0),.rx_enable(1'b1),.tx_session_active(1'b0),
    .refclk(refclk),.refclk_odiv2(refclk),.rx_p(4'd0),.rx_n(4'd0),
    .tx_prbs_select(12'd0),.rx_prbs_select(12'd0),.prbs_counter_reset(4'd0),
    .lane_running(4'd0),.loopback_mode(3'd0),.acquisition_active(1'b0),
    .measurement_enable(1'b0),.result_capture_request(1'b0),.tx_error_inject_toggle(4'd0),
    .quad_ready(ready),.quad_fault(quad_fault));
  task tick(input integer n);repeat(n)@(negedge clk);endtask
  task setup_point(input integer l,h,v);
    controls[6:0]=l;controls[17:7]=h;controls[26:18]=v;
    controls[31:27]=2;controls[63:32]=10000;controls[65]=0;
    controls[66]=0;controls[67]=1;controls[68]=1;tick(16);
  endtask
  task finish_point(input logic[7:0] expected_status);
    integer age;
    age=0;while(!packet[0] && age<4000)begin tick(1);age++;end
    if(!packet[0] || packet[13:6]!=expected_status || !packet[3] || fatal || quad_fault)
      $fatal(1,"quad eye result failed packet=%h port=%h state=%0d",packet,dut.eye_port_fault,dut.u_eye_point.state);
    if(dut.g_all_links_q121.u_gt.txelecidle_in!=15 || dut.gtwiz_reset_rx_datapath || dut.gtwiz_reset_all)
      $fatal(1,"scan changed TX enable or normal reset policy");
    controls[65]=1;tick(16);controls[65]=0;tick(16);
    if(packet[0])$fatal(1,"point result ACK did not clear");
  endtask
  initial begin
    tick(6);resetn=1;tick(350);
    if(!ready || quad_fault)$fatal(1,"quad not ready");
    setup_point(0,-32,-127);controls[64]=1;finish_point(0);
    if(packet[26:20]!=0 || $signed(packet[42:32])!=-32 || $signed(packet[51:43])!=-127 ||
       packet[95:64]!=32'h12340003 || packet[28:27]!=3)
      $fatal(1,"quad raw metadata/range incorrect");
    setup_point(3,32,127);controls[64]=0;finish_point(0);
    if(packet[26:20]!=3 || packet[1]!=0)$fatal(1,"changed lane/phase not retained");
    setup_point(4,0,0);controls[64]=1;tick(100);
    if(dut.g_all_links_q121.u_gt.eye_model.starts!=2 || packet[0])
      $fatal(1,"unselected quad started scan");
    setup_point(1,0,0);tick(30);
    if(dut.g_all_links_q121.u_gt.eye_model.starts!=2)$fatal(1,"descriptor change replayed phase");
    controls[64]=0;wait(dut.g_all_links_q121.u_gt.eye_model.starts==3);@(negedge clk);
    controls[66]=1;finish_point(2);
    $display("PASS: eye v1 quad real point/DRP integration, lane/phase selection and cancel restoration");
    $finish;
  end
  initial begin #1000000;$fatal(1,"eye quad watchdog");end
endmodule
