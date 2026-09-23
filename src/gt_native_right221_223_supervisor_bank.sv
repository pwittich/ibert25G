`timescale 1ns/1ps

// Three real management-clock quad supervisors for q221/q222/q223.  Their
// reset outputs intentionally remain vector-valued: the current generic
// Wizard outer wrapper has only one global reset input and must be derived
// again before these independent reset requests can be connected safely.
module gt_native_right221_223_supervisor_bank (
  input wire mgmt_clk, input wire resetn,
  input wire [11:0] gtpowergood, input wire [2:0] qpll0lock,
  input wire [2:0] tx_userclk_active, input wire [2:0] rx_userclk_active,
  input wire [11:0] txresetdone, input wire [11:0] rxresetdone,
  input wire [2:0] runtime_rx_reset_active,
  input wire [2:0] active_quad_restart,
  output wire [2:0] gtwiz_reset_all, output wire [2:0] quad_ready,
  output wire [2:0] quad_fault, output wire [23:0] fault_reason,
  output wire [8:0] state
);
  for (genvar q = 0; q < 3; q++) begin : g_quad
    (* DONT_TOUCH = "TRUE", KEEP_HIERARCHY = "yes" *)
    gt_quad_controller u_supervisor (
      .mgmt_clk(mgmt_clk), .resetn(resetn),
      .gtpowergood_async(gtpowergood[q*4 +: 4]), .qpll0lock_async(qpll0lock[q]),
      .tx_userclk_active_async(tx_userclk_active[q]),
      .rx_userclk_active_async(rx_userclk_active[q]),
      .txresetdone_async(txresetdone[q*4 +: 4]),
      .rxresetdone_async(rxresetdone[q*4 +: 4]),
      .runtime_rx_reset_active(runtime_rx_reset_active[q]),
      .runtime_quad_restart_request(active_quad_restart[q]),
      .gtwiz_reset_all(gtwiz_reset_all[q]), .quad_ready(quad_ready[q]),
      .quad_fault(quad_fault[q]), .fault_reason(fault_reason[q*8 +: 8]),
      .state(state[q*3 +: 3]), .diagnostic_live()
    );
  end
endmodule
