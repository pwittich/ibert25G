`timescale 1ns/1ps

// V3-specific implementation; historical modules remain unchanged at 34c73bb.

// Management-clock supervisor for one four-channel GTY quad.  The GT Wizard
// reset helper performs the device-specific reset sequence; this controller
// qualifies its asynchronous status, enforces a bounded initialization, and
// latches fatal loss of power-good/QPLL/reset-done after reaching READY.
module all_links_v3_quad_controller #(
  parameter int unsigned RESET_HOLD_CYCLES = 256,
  parameter int unsigned INIT_TIMEOUT_CYCLES = 200_000_000
) (
  input wire rx_enable,
  input  wire       mgmt_clk,
  input  wire       resetn,
  input  wire [3:0] gtpowergood_async,
  input  wire       qpll0lock_async,
  input  wire       tx_userclk_active_async,
  input  wire       rx_userclk_active_async,
  input  wire [3:0] txresetdone_async,
  input  wire [3:0] rxresetdone_async,
  input  wire       runtime_rx_reset_active,
  input  wire       runtime_quad_restart_request,
  output logic      gtwiz_reset_all,
  output logic      quad_ready,
  output logic      quad_fault,
  output logic [7:0] fault_reason,
  (* fsm_encoding = "none" *) output logic [2:0] state,
  output wire [31:0] diagnostic_live
);
  localparam logic [2:0] ST_RESET = 3'd0;
  localparam logic [2:0] ST_WAIT_POWER = 3'd1;
  localparam logic [2:0] ST_WAIT_PLL = 3'd2;
  localparam logic [2:0] ST_WAIT_DONE = 3'd3;
  localparam logic [2:0] ST_READY = 3'd4;
  localparam logic [2:0] ST_FAULT = 3'd5;
  localparam logic [2:0] ST_RX_REQUAL = 3'd6;
  localparam logic [2:0] ST_RESTART_ASSERT = 3'd7;

  // Every GT Wizard status input is asynchronous to mgmt_clk.  Keep each
  // qualifier behind an explicit two-flop synchronizer before it participates
  // in state transitions or the latched diagnostic word.
  (* ASYNC_REG = "TRUE" *) logic [3:0] power_meta = 0, power_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic qpll_meta = 0, qpll_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic tx_active_meta = 0, tx_active_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic rx_active_meta = 0, rx_active_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic [3:0] txdone_meta = 0, txdone_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic [3:0] rxdone_meta = 0, rxdone_sync = 0;
  logic [31:0] counter = 0;
  logic rx_requal_pending = 0;
  logic rx_enable_seen = 0;
  always_ff @(posedge mgmt_clk) begin
    if (!resetn) rx_enable_seen <= 0;
    else rx_enable_seen <= rx_enable;
  end
  logic [2:0] restart_assert_seen = 0;
  logic restart_reset_released = 0;

  wire all_power_good = &power_sync;
  wire all_reset_done = &txdone_sync && tx_active_sync &&
    (!rx_enable || (&rxdone_sync && rx_active_sync));
  // Bits 0-5 identify the live failed qualification: power, QPLL, TX user
  // clock, TX reset-done, RX user clock, and RX reset-done. Bit 6 marks a
  // bounded-wait timeout; bit 7 is reserved for the PRBS sequencer wrapper.
  wire [7:0] live_fault_reason = {
    2'b00, !(&rxdone_sync), !rx_active_sync,
    !(&txdone_sync), !tx_active_sync, !qpll_sync, !all_power_good
  };
  wire [7:0] non_rx_fault_reason = live_fault_reason & 8'h0f;
  wire [7:0] rx_fault_reason = rx_enable ? (live_fault_reason & 8'h30) : 8'd0;
  assign diagnostic_live = {
    2'd0, fault_reason, gtwiz_reset_all, quad_fault, quad_ready, state,
    runtime_rx_reset_active, rxdone_sync, txdone_sync,
    rx_active_sync, tx_active_sync, qpll_sync, power_sync
  };

  always_ff @(posedge mgmt_clk) begin
    power_meta <= gtpowergood_async;
    power_sync <= power_meta;
    qpll_meta <= qpll0lock_async;
    qpll_sync <= qpll_meta;
    tx_active_meta <= tx_userclk_active_async;
    tx_active_sync <= tx_active_meta;
    rx_active_meta <= rx_userclk_active_async;
    rx_active_sync <= rx_active_meta;
    txdone_meta <= txresetdone_async;
    txdone_sync <= txdone_meta;
    rxdone_meta <= rxresetdone_async;
    rxdone_sync <= rxdone_meta;

    if (!resetn) begin
      state <= ST_RESET;
      counter <= 0;
      gtwiz_reset_all <= 1;
      quad_ready <= 0;
      quad_fault <= 0;
      fault_reason <= 0;
      rx_requal_pending <= 0;
      restart_assert_seen <= 0;
      restart_reset_released <= 0;
    end else begin
      case (state)
        // Hold the Wizard's global reset long enough to make configuration and
        // board-clock startup deterministic, then qualify power, QPLL, and
        // user-clock/reset completion in that order.
        ST_RESET: begin
          gtwiz_reset_all <= 1;
          quad_ready <= 0;
          if (counter + 1 >= RESET_HOLD_CYCLES) begin
            counter <= 0;
            gtwiz_reset_all <= 0;
            state <= ST_WAIT_POWER;
          end else begin
            counter <= counter + 1'b1;
          end
        end

        ST_WAIT_POWER: begin
          if (all_power_good) begin
            counter <= 0;
            state <= ST_WAIT_PLL;
          end else if (counter + 1 >= INIT_TIMEOUT_CYCLES) begin
            fault_reason <= live_fault_reason | 8'h40;
            state <= ST_FAULT;
          end else begin
            counter <= counter + 1'b1;
          end
        end

        ST_WAIT_PLL: begin
          if (!all_power_good) begin
            fault_reason <= live_fault_reason;
            state <= ST_FAULT;
          end else if (qpll_sync) begin
            counter <= 0;
            state <= ST_WAIT_DONE;
          end else if (counter + 1 >= INIT_TIMEOUT_CYCLES) begin
            fault_reason <= live_fault_reason | 8'h40;
            state <= ST_FAULT;
          end else begin
            counter <= counter + 1'b1;
          end
        end

        ST_WAIT_DONE: begin
          if (!all_power_good || !qpll_sync) begin
            fault_reason <= live_fault_reason;
            state <= ST_FAULT;
          end else if (all_reset_done) begin
            counter <= 0;
            quad_ready <= 1;
            state <= ST_READY;
          end else if (counter + 1 >= INIT_TIMEOUT_CYCLES) begin
            fault_reason <= live_fault_reason | 8'h40;
            state <= ST_FAULT;
          end else begin
            counter <= counter + 1'b1;
          end
        end

        ST_READY: begin
          // Power/QPLL/TX losses are always fatal.  RX qualifiers are allowed
          // to fall only during the PRBS controller's intentional reset flow.
          if (runtime_quad_restart_request) begin
            // A bounded PRBS-acquisition recovery deliberately reuses the
            // complete power-up sequence.  Acknowledge it by dropping ready;
            // the requester then releases this level before bring-up returns.
            state <= ST_RESTART_ASSERT;
            counter <= 0;
            gtwiz_reset_all <= 1;
            quad_ready <= 0;
            quad_fault <= 0;
            fault_reason <= 0;
            rx_requal_pending <= 0;
            restart_assert_seen <= 0;
            restart_reset_released <= 0;
          end else if (non_rx_fault_reason != 0) begin
            fault_reason <= non_rx_fault_reason;
            quad_ready <= 0;
            state <= ST_FAULT;
          end else if (rx_enable && !rx_enable_seen) begin
            counter <= 0; rx_requal_pending <= 1; state <= ST_RX_REQUAL;
          end else if (runtime_rx_reset_active) begin
            // Remember that independently synchronized RX status must be
            // requalified after the intentional reset window closes.
            rx_requal_pending <= 1;
          end else if (rx_requal_pending) begin
            counter <= 0;
            state <= ST_RX_REQUAL;
          end else if (rx_fault_reason != 0) begin
            fault_reason <= rx_fault_reason;
            quad_ready <= 0;
            state <= ST_FAULT;
          end
        end

        ST_RESTART_ASSERT: begin
          quad_ready <= 0;
          if (!restart_reset_released) begin
            // The Wizard starts its internal reset sequence on release of the
            // level input.  Hold the request for the ordinary reset interval,
            // then release it before waiting for status to fall.
            gtwiz_reset_all <= 1;
            if (counter + 1 >= RESET_HOLD_CYCLES) begin
              counter <= 0;
              gtwiz_reset_all <= 0;
              restart_reset_released <= 1;
            end else begin
              counter <= counter + 1'b1;
            end
          end else begin
            // Runtime status can fall well after reset release.  Latch the
            // QPLL-lock, TX-reset-done, and RX-reset-done effects independently
            // because their low intervals need not overlap. Requiring the RX
            // low observation prevents stale-high status from satisfying the
            // subsequent WAIT_DONE state before the delayed RX drop arrives.
            gtwiz_reset_all <= 0;
            restart_assert_seen <= restart_assert_seen |
              {!(&rxdone_sync), !(&txdone_sync), !qpll_sync};
            if (&(restart_assert_seen |
                  {!(&rxdone_sync), !(&txdone_sync), !qpll_sync})) begin
              counter <= 0;
              restart_assert_seen <= 0;
              restart_reset_released <= 0;
              state <= ST_WAIT_POWER;
            end else if (counter + 1 >= INIT_TIMEOUT_CYCLES) begin
              fault_reason <= 8'h40;
              state <= ST_FAULT;
            end else begin
              counter <= counter + 1'b1;
            end
          end
        end

        ST_RX_REQUAL: begin
          // Independently synchronized RX status can trail the end of the
          // reset request.  This bounded state absorbs that CDC latency without
          // dropping quad_ready and recreating the original startup race.
          if (non_rx_fault_reason != 0) begin
            fault_reason <= non_rx_fault_reason;
            quad_ready <= 0;
            state <= ST_FAULT;
          end else if (rx_enable && !rx_enable_seen) begin
            counter <= 0; rx_requal_pending <= 1; state <= ST_RX_REQUAL;
          end else if (runtime_rx_reset_active) begin
            counter <= 0;
          end else if (rx_fault_reason == 0) begin
            counter <= 0;
            rx_requal_pending <= 0;
            state <= ST_READY;
          end else if (counter + 1 >= INIT_TIMEOUT_CYCLES) begin
            fault_reason <= rx_fault_reason | 8'h40;
            quad_ready <= 0;
            state <= ST_FAULT;
          end else begin
            counter <= counter + 1'b1;
          end
        end

        ST_FAULT: begin
          // Faults latch until the top-level reset.  Reasserting Wizard reset
          // leaves the physical quad in a deterministic safe state.
          gtwiz_reset_all <= 1;
          quad_ready <= 0;
          quad_fault <= 1;
        end

        default: begin
          state <= ST_FAULT;
          gtwiz_reset_all <= 1;
          quad_ready <= 0;
          quad_fault <= 1;
          fault_reason <= 8'h80;
        end
      endcase

      if (state == ST_FAULT) begin
        gtwiz_reset_all <= 1;
        quad_ready <= 0;
        quad_fault <= 1;
      end
    end
  end
endmodule
