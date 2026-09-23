`timescale 1ns/1ps
module tb_all_links_v1_slr_bank;
  logic clk=0, resetn=0;
  logic [6:0] controls=7'd0;
  logic [27:0] selected='1;
  wire [3:0] gr, gf, gi, ga, gc, gs;
  wire [31:0] reason;
  wire [895:0] diag;
  wire final_ready, final_fault, final_idle, final_acquire, final_capture, final_session;
  wire [7:0] final_reason;
  wire [223:0] final_diag;
  always #1 clk=~clk;

`define BANK(NAME, OFFSET, NQUADS, IDX) \
  all_links_v1_slr_bank #(.LEFT_FIRST(OFFSET),.COUNT(NQUADS), \
    .LOCALIZE_QUAD_RESET(1'b1)) NAME ( \
    .clk_200(clk),.resetn(resetn),.controls_in(controls), \
    .left_quad_selected_in(selected[OFFSET +: NQUADS]), \
    .right_quad_selected_in(selected[14+OFFSET +: NQUADS]), \
    .group_ready(gr[IDX]),.group_fault(gf[IDX]),.group_idle(gi[IDX]), \
    .group_acquire(ga[IDX]),.group_capture(gc[IDX]), \
    .group_session_applied(gs[IDX]),.group_fault_reason(reason[IDX*8 +: 8]), \
    .group_diagnostics(diag[IDX*224 +: 224]));
  `BANK(b0,0,3,0)
  `BANK(b1,3,4,1)
  `BANK(b2,7,4,2)
  `BANK(b3,11,3,3)
`undef BANK

  all_links_v1_quad_aggregate final_reduce (
    .clk(clk),.resetn(resetn),.group_ready(gr),.group_fault(gf),
    .group_idle(gi),.group_acquire(ga),.group_capture(gc),
    .group_session_applied(gs),.group_reason(reason),.group_diagnostics(diag),
    .quad_ready(final_ready),.quad_fault(final_fault),.controller_idle(final_idle),
    .acquisition_ready(final_acquire),.capture_done(final_capture),
    .tx_session_applied(final_session),.fault_reason(final_reason),
    .diagnostics(final_diag));

  task tick; @(posedge clk); #0.1; endtask
  initial begin
    controls=7'b1000100; // session request plus acquisition request
    #0.1;
    if (b0.local_resetn || b1.local_resetn || b2.local_resetn || b3.local_resetn)
      $fatal(1,"local resets did not initialize low");
    repeat(2) tick();
    if (|gs || final_session || |ga || final_acquire)
      $fatal(1,"request/ack accepted during local reset");
    @(negedge clk); resetn=1;
    if (b0.local_resetn || b1.local_resetn || b2.local_resetn || b3.local_resetn)
      $fatal(1,"local reset released before clk_200 edge");
    tick();
    if (!(b0.local_resetn && b1.local_resetn && b2.local_resetn && b3.local_resetn))
      $fatal(1,"four local resets did not release together on first edge");
    if (|b0.g_localize_quad_reset.left_quad_resetn ||
        |b0.g_localize_quad_reset.right_quad_resetn ||
        |b1.g_localize_quad_reset.left_quad_resetn ||
        |b1.g_localize_quad_reset.right_quad_resetn ||
        |b2.g_localize_quad_reset.left_quad_resetn ||
        |b2.g_localize_quad_reset.right_quad_resetn ||
        |b3.g_localize_quad_reset.left_quad_resetn ||
        |b3.g_localize_quad_reset.right_quad_resetn)
      $fatal(1,"per-quad reset releases skipped the matched local stage");
    if (b0.local_controls !== controls || b1.local_controls !== controls ||
        b2.local_controls !== controls || b3.local_controls !== controls)
      $fatal(1,"control pipeline latency/value changed");
    if (|gs || final_session) $fatal(1,"session ack rose on reset-release edge");
    tick();
    if (&b0.g_localize_quad_reset.left_quad_resetn !== 1'b1 ||
        &b0.g_localize_quad_reset.right_quad_resetn !== 1'b1 ||
        &b1.g_localize_quad_reset.left_quad_resetn !== 1'b1 ||
        &b1.g_localize_quad_reset.right_quad_resetn !== 1'b1 ||
        &b2.g_localize_quad_reset.left_quad_resetn !== 1'b1 ||
        &b2.g_localize_quad_reset.right_quad_resetn !== 1'b1 ||
        &b3.g_localize_quad_reset.left_quad_resetn !== 1'b1 ||
        &b3.g_localize_quad_reset.right_quad_resetn !== 1'b1)
      $fatal(1,"per-quad reset releases did not rise together on second edge");
    if (|gs || final_session)
      $fatal(1,"ack bypassed per-quad reset-release latency");
    tick();
    if (gs !== 4'hf || final_session) $fatal(1,"local all-member ack barrier failed");
    tick();
    if (!final_session || !final_acquire) $fatal(1,"global four-bank barrier failed");

    // Entire unselected quads are neutral only for acquisition and capture.
    // The bank mask has the same one-cycle launch boundary as controls.
    @(negedge clk); selected[0]=1'b0; selected[14]=1'b0; controls[0]=1'b1;
    force b0.left_acquisition_ready[0]=1'b0;
    force b0.right_acquisition_ready[0]=1'b0;
    force b0.left_capture_done[0]=1'b0;
    force b0.right_capture_done[0]=1'b0;
    tick(); tick(); tick();
    if (!final_acquire || !final_capture)
      $fatal(1,"unselected quad did not neutralize acquisition/capture");
    force b0.left_quad_ready[0]=1'b0;
    tick(); tick();
    if (final_ready) $fatal(1,"selection weakened global ready barrier");
    release b0.left_quad_ready[0];
    force b0.left_controller_idle[0]=1'b0;
    tick(); tick();
    if (final_idle) $fatal(1,"selection weakened global idle barrier");
    release b0.left_controller_idle[0];
    force b0.left_quad_fault[0]=1'b1;
    tick(); tick();
    if (!final_fault) $fatal(1,"selection weakened global fault barrier");
    release b0.left_quad_fault[0];
    force b0.left_tx_session_applied[0]=1'b0;
    tick(); tick();
    if (final_session) $fatal(1,"selection weakened global session barrier");
    release b0.left_tx_session_applied[0];
    release b0.left_acquisition_ready[0]; release b0.right_acquisition_ready[0];
    release b0.left_capture_done[0]; release b0.right_capture_done[0];

    // A selected controller may not be bypassed while control/CDC settles.
    @(negedge clk); selected[0]=1'b1;
    force b0.left_acquisition_ready[0]=1'b0;
    tick(); tick(); tick();
    if (final_acquire) $fatal(1,"selected idle controller allowed early RUN");
    release b0.left_acquisition_ready[0];
    tick(); tick();
    if (!final_acquire) $fatal(1,"selected controller completion not observed");

    force b2.right_tx_session_applied[1]=1'b0;
    tick(); tick();
    if (gs[2]) $fatal(1,"local ack ignored one member quad");
    tick();
    if (final_session) $fatal(1,"global ack ignored one bank");
    release b2.right_tx_session_applied[1];

    force b0.left_quad_fault[0]=1'b1;
    force b0.left_fault_reason[7:0]=8'h01;
    force b0.left_diagnostics[223:0]=224'h121;
    force b3.right_quad_fault[2]=1'b1;
    force b3.right_fault_reason[23:16]=8'h80;
    force b3.right_diagnostics[3*224-1 -: 224]=224'h234;
    tick(); tick();
    if (!final_fault || final_reason!=8'h81 || final_diag!=224'h121)
      $fatal(1,"reducer OR or lowest-global-quad priority changed");
    $display("PASS: four SLR-bank reset, control, local/global ack, packing, and priority contract");
    $finish;
  end
endmodule
