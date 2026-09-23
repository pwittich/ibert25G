`timescale 1ns/1ps

// Integrated management-domain proof for the all-links v2 participation
// repair.  Real engine/lane CDC logic and real two-level bank reducers are
// used; only GT/wrapper analog behavior is stubbed.
module tb_all_links_v2_participation;
  localparam logic [111:0] DIRECT_MASK =
    {16'hffff,32'hffff_ffff,32'hff00_0000,32'h0000_0000};
  localparam logic [111:0] SPARSE_MASK =
    {16'h000f,32'h0000_0000,32'h0f00_0000,32'h0000_000f};
  localparam logic [111:0] FULL_MASK = {112{1'b1}};
  logic clk=0, resetn=0, write=0;
  logic [11:0] wa=0;
  logic [31:0] wd=0;
  always #2.5 clk=~clk;

  wire [111:0] accepted_mask;
  wire [27:0] selected;
  wire [6:0] controls;
  wire [3:0] gr,gf,gi,ga,gc,gs;
  wire [31:0] reason;
  wire [895:0] diag;
  wire final_ready,final_fault,final_idle,final_acquire,final_capture,final_session;
  wire [7:0] final_reason;
  wire [223:0] final_diag;
  wire [335:0] txsel,rxsel;
  wire [111:0] counter_reset,running,inject;
  wire [2:0] loopback;
  wire measure,acquire,capture,session,irq;

  for(genvar q=0;q<14;q++) begin : quad_mask
    assign selected[q]=|accepted_mask[q*4+:4];
    assign selected[14+q]=|accepted_mask[56+q*4+:4];
  end
  assign controls={session,loopback,acquire,measure,capture};

`define BANK(NAME,OFFSET,NQ,IDX) \
  all_links_v1_slr_bank #(.LEFT_FIRST(OFFSET),.COUNT(NQ),.LOCALIZE_QUAD_RESET(1)) NAME ( \
    .clk_200(clk),.resetn(resetn),.controls_in(controls), \
    .left_quad_selected_in(selected[OFFSET+:NQ]), \
    .right_quad_selected_in(selected[14+OFFSET+:NQ]), \
    .group_ready(gr[IDX]),.group_fault(gf[IDX]),.group_idle(gi[IDX]), \
    .group_acquire(ga[IDX]),.group_capture(gc[IDX]), \
    .group_session_applied(gs[IDX]),.group_fault_reason(reason[IDX*8+:8]), \
    .group_diagnostics(diag[IDX*224+:224]));
  `BANK(b0,0,3,0)
  `BANK(b1,3,4,1)
  `BANK(b2,7,4,2)
  `BANK(b3,11,3,3)
`undef BANK

  all_links_v1_quad_aggregate final_reduce(
    .clk(clk),.resetn(resetn),.group_ready(gr),.group_fault(gf),
    .group_idle(gi),.group_acquire(ga),.group_capture(gc),
    .group_session_applied(gs),.group_reason(reason),.group_diagnostics(diag),
    .quad_ready(final_ready),.quad_fault(final_fault),.controller_idle(final_idle),
    .acquisition_ready(final_acquire),.capture_done(final_capture),
    .tx_session_applied(final_session),.fault_reason(final_reason),
    .diagnostics(final_diag));

  gt_test_engine_core #(.ENABLE_TX_SESSION(1),
    .LOCALIZE_DESCRIPTOR_CONTROLS(1),.HARDWARE_VERSION(32'h00020501),
    .MANAGED_LANE_MASK(FULL_MASK),.ASYNC_SNAPSHOT_MASK(112'd0)) core(
    .mgmt_clk(clk),.mgmt_resetn(resetn),.reg_write(write),
    .reg_write_address(wa),.reg_write_data(wd),.reg_write_strobe(4'hf),
    .reg_read_address(12'd0),.reg_read_data(),.interrupt(irq),
    .status_firmware_alive(),.status_engine_busy(),.status_fault(),
    .platform_ready(final_ready&&final_idle),.platform_fault(final_fault),
    .platform_status(32'd0),.platform_diagnostics(final_diag),
    .recovery_diagnostics(256'd0),.diagnostic_record(256'd0),
    .diagnostic_selector(),.diagnostic_bank(),.engine_protocol_debug(),
    .acquisition_ready(final_acquire),.result_capture_done(final_capture),
    .exact_error_counts(3584'd0),.exact_error_valid(112'd0),
    .exact_error_saturated(112'd0),.mailbox_i2c_address(8'd0),
    .mailbox_i2c_write(1'b0),.mailbox_i2c_write_data(8'd0),
    .mailbox_i2c_read_data(),.mailbox_i2c_read_data_next(),
    .rx_clk({112{clk}}),.rx_reset(112'd0),.rx_prbs_locked(FULL_MASK),
    .rx_cdr_locked(FULL_MASK),.rx_prbs_errors(1792'd0),
    .tx_prbs_select(txsel),.rx_prbs_select(rxsel),
    .prbs_counter_reset(counter_reset),.lane_running(running),
    .loopback_mode(loopback),.measurement_enable(measure),
    .measurement_run_toggle(),.controls_enable(),.tx_session_active(session),
    .tx_session_ready(1'b1),.acquisition_active(acquire),
    .result_capture_request(capture),.accepted_lane_mask(accepted_mask),
    .tx_error_inject_toggle(inject));

  task automatic wr(input logic [11:0] a,input logic [31:0] d);
    @(negedge clk);wa=a;wd=d;write=1;
    @(negedge clk);write=0;
  endtask
  task automatic descriptor(input logic [111:0] mask);
    wr(12'h020,32'h0000_1501); wr(12'h024,32'd20);
    wr(12'h028,32'd0); wr(12'h02c,mask[31:0]);
    wr(12'h030,mask[63:32]); wr(12'h034,mask[95:64]);
    wr(12'h038,{16'd0,mask[111:96]});
  endtask
  task automatic wait_idle;
    wait(core.state==0 && final_ready && final_idle); repeat(8) @(negedge clk);
  endtask
  task automatic run_mask(input logic [111:0] mask,input logic [31:0] summary,
                          input integer expected_run);
    descriptor(mask); wr(12'h00c,1);
    wait(core.state==1); repeat(3) @(negedge clk);
    if(accepted_mask!==mask) $fatal(1,"accepted mask epoch mismatch");
    for(integer q=0;q<14;q++) begin
      if(selected[q] !== (|mask[q*4+:4]) ||
         selected[14+q] !== (|mask[56+q*4+:4]))
        $fatal(1,"quad participation mismatch q%0d",q);
    end
    wait(irq); repeat(8) @(negedge clk);
    if(core.run_id!=expected_run || core.aggregate_summary!=summary)
      $fatal(1,"publication mismatch run%0d summary%h",core.run_id,core.aggregate_summary);
    wait_idle(); wr(12'h00c,4);
  endtask

  initial begin
    repeat(8) @(negedge clk);resetn=1;wait_idle();

    // Model the reported hardware condition: all fourteen unselected FireFly
    // controllers remain IDLE and never assert acquisition/capture.
    force b0.left_acquisition_ready='0; force b1.left_acquisition_ready='0;
    force b2.left_acquisition_ready='0; force b3.left_acquisition_ready='0;
    force b0.left_capture_done='0; force b1.left_capture_done='0;
    force b2.left_capture_done='0; force b3.left_capture_done='0;
    run_mask(DIRECT_MASK,32'h0038_3801,1);
    release b0.left_acquisition_ready; release b1.left_acquisition_ready;
    release b2.left_acquisition_ready; release b3.left_acquisition_ready;
    release b0.left_capture_done; release b1.left_capture_done;
    release b2.left_capture_done; release b3.left_capture_done;

    run_mask(SPARSE_MASK,32'h000c_0c01,2);
    run_mask(FULL_MASK,32'h0070_7001,3);
    // Same-instance changed mask proves accepted participation and publication
    // advance together rather than retaining the prior all-112 epoch.
    run_mask(DIRECT_MASK,32'h0038_3801,4);
    $display("PASS: all-links v2 direct-only/sparse/all112/back-to-back participation and publication epochs");
    $finish;
  end
  initial begin repeat(2000000) @(posedge clk); $fatal(1,"participation watchdog state%0d",core.state); end
endmodule
