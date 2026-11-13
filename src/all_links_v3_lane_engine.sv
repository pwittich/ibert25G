`timescale 1ns/1ps

// V3-specific implementation; historical modules remain unchanged at 34c73bb.

// Per-lane acquisition logic in the lane's RXUSRCLK2 domain.  Start/stop are
// toggle handshakes rather than pulses so an event cannot be lost while
// crossing from the 200-MHz management clock.  The lane freezes a complete
// 256-bit result record and acknowledges stop only after the management side
// has captured that record.
module all_links_v3_lane_engine #(
  parameter int unsigned LANE_ID = 0,
  parameter int unsigned USER_BITS_PER_CYCLE = 80
) (
  input  wire         start_req_toggle,
  input  wire         stop_req_toggle,
  input  wire         descriptor_selected,
  input  wire [2:0]   descriptor_prbs_mode,
  input  wire         measurement_enable,
  input  wire         controls_enable,
  output logic        start_ack_toggle,
  output logic        stop_ack_toggle,
  output logic        snapshot_send,
  input  wire         snapshot_rcv,

  input wire config_epoch, lane_enable,
  output logic config_ack = 0,
  input  wire         rx_clk,
  // Management reset synchronized to rx_clk; never driven by GT recovery.
  input  wire         protocol_reset,
  input  wire         rx_reset,
  input  wire         rx_prbs_locked,
  input  wire         rx_cdr_locked,
  input  wire [15:0]  rx_prbs_errors,

  output logic [2:0]  tx_prbs_select,
  output logic [2:0]  rx_prbs_select,
  output logic        prbs_counter_reset,
  output logic        running,

  output logic [31:0] snapshot_id_status,
  output logic [63:0] snapshot_errors,
  output logic [63:0] snapshot_tested_bits,
  output logic [31:0] snapshot_lock_losses,
  output logic [63:0] snapshot_valid_cycles
);
  // Descriptor fields are bundled-data CDC signals.  The global controller
  // launches them with start_req_toggle and holds through stop acknowledgement.
  // Data has two capture stages; requests have four. The two extra request
  // stages are a bundled-data settling budget, not an arbitrary-skew guarantee.
  // Physical implementation must bound source-to-data capture delay accordingly.
  (* ASYNC_REG = "TRUE" *) logic start_req_meta = 0, start_req_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic start_req_guard0 = 0, start_req_guard1 = 0;
  (* ASYNC_REG = "TRUE" *) logic stop_req_meta = 0, stop_req_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic stop_req_guard0 = 0, stop_req_guard1 = 0;
  (* ASYNC_REG = "TRUE" *) logic selected_meta = 0, selected_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic [2:0] prbs_meta = 0, prbs_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic lock_meta = 0, lock_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic cdr_lock_meta = 0, cdr_lock_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic measure_meta = 0, measure_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic controls_meta = 0, controls_sync = 0;

  (* ASYNC_REG = "TRUE" *) logic [3:0] config_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic enable_meta = 0, enable_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic rebase_start_meta = 0, rebase_start_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic rebase_stop_meta = 0, rebase_stop_sync = 0;
  always_ff @(posedge rx_clk) begin
    if (protocol_reset) begin
      config_sync <= 0; enable_meta <= 0; enable_sync <= 0; rebase_start_meta <= 0; rebase_start_sync <= 0;
      rebase_stop_meta <= 0; rebase_stop_sync <= 0;
    end else begin
      config_sync <= {config_sync[2:0],config_epoch};
      enable_meta <= lane_enable; enable_sync <= enable_meta;
      rebase_start_meta <= start_req_toggle; rebase_start_sync <= rebase_start_meta;
      rebase_stop_meta <= stop_req_toggle; rebase_stop_sync <= rebase_stop_meta;
    end
  end
  logic start_seen = 0, stop_seen = 0;
  logic selected = 0, previous_lock = 0;
  logic [2:0] accepted_prbs_mode = 0;
  logic [63:0] error_count = 0, tested_bits = 0, valid_cycles = 0;
  logic [31:0] lock_loss_count = 0;
  logic error_saturated = 0, bit_count_saturated = 0;
  logic stop_pending = 0;
  logic restart_rearm_pending = 0;
  logic [15:0] rx_prbs_errors_q = 0;
  logic [15:0] rx_error_sample = 0;
  logic rx_lock_sample = 0;
  // Keep native lock capture free of the protocol/reset mux. Qualification
  // and its reset behavior remain in the following existing two stages.
  always_ff @(posedge rx_clk) rx_lock_sample <= rx_prbs_locked;
  always_ff @(posedge rx_clk) rx_error_sample <= rx_prbs_errors;
  logic [16:0] error_low_sum;
  wire qualified_lock = lock_sync && cdr_lock_sync;

  // Register the GT RXPRBSERR output before arithmetic.  The GT primitive's
  // RXPRBSERR clock-to-out plus routing consumes most of a 322.265625-MHz
  // cycle; this register leaves a full cycle for the 16-bit low-word add.
  // A low-word carry increments the upper 48 bits, preserving an exact
  // saturating 64-bit count.
  always_comb begin
    error_low_sum = {1'b0, error_count[15:0]} +
                    {1'b0, rx_prbs_errors_q};
  end

  function automatic logic [63:0] saturating_add64(
    input logic [63:0] value,
    input logic [63:0] increment
  );
    if ((64'hffff_ffff_ffff_ffff - value) < increment)
      saturating_add64 = 64'hffff_ffff_ffff_ffff;
    else
      saturating_add64 = value + increment;
  endfunction

  always_ff @(posedge rx_clk) begin
    if (protocol_reset) begin
      config_ack <= 0;
      start_req_meta <= 0;
      start_req_sync <= 0;
      start_req_guard0 <= 0;
      start_req_guard1 <= 0;
      stop_req_meta <= 0;
      stop_req_sync <= 0;
      stop_req_guard0 <= 0;
      stop_req_guard1 <= 0;
      selected_meta <= 0;
      selected_sync <= 0;
      prbs_meta <= 0;
      prbs_sync <= 0;
      lock_meta <= 0;
      lock_sync <= 0;
      cdr_lock_meta <= 0;
      cdr_lock_sync <= 0;
      measure_meta <= 0;
      measure_sync <= 0;
      controls_meta <= 0;
      controls_sync <= 0;
      start_seen <= 0;
      stop_seen <= 0;
      start_ack_toggle <= 0;
      stop_ack_toggle <= 0;
      snapshot_send <= 0;
      tx_prbs_select <= 0;
      rx_prbs_select <= 0;
      prbs_counter_reset <= 1;
      running <= 0;
      selected <= 0;
      accepted_prbs_mode <= 0;
      previous_lock <= 0;
      error_count <= 0;
      tested_bits <= 0;
      valid_cycles <= 0;
      lock_loss_count <= 0;
      error_saturated <= 0;
      bit_count_saturated <= 0;
      stop_pending <= 0;
      restart_rearm_pending <= 0;
      rx_prbs_errors_q <= 0;
      snapshot_id_status <= LANE_ID;
      snapshot_errors <= 0;
      snapshot_tested_bits <= 0;
      snapshot_lock_losses <= 0;
      snapshot_valid_cycles <= 0;
    end else if (config_sync[3] || !enable_sync) begin
      // Configuration occurs only with stable global request toggles and no
      // transfer pending. Rebase every phase before the next descriptor.
      config_ack <= config_sync[3];
      start_req_meta <= rebase_start_sync; start_req_sync <= rebase_start_sync;
      start_req_guard0 <= rebase_start_sync; start_req_guard1 <= rebase_start_sync;
      stop_req_meta <= rebase_stop_sync; stop_req_sync <= rebase_stop_sync;
      stop_req_guard0 <= rebase_stop_sync; stop_req_guard1 <= rebase_stop_sync;
      start_seen <= rebase_start_sync; start_ack_toggle <= rebase_start_sync;
      stop_seen <= rebase_stop_sync; stop_ack_toggle <= rebase_stop_sync;
      snapshot_send <= 0; stop_pending <= 0; restart_rearm_pending <= 0;
      running <= 0; selected <= 0; selected_meta <= 0; selected_sync <= 0;
      tx_prbs_select <= 0; rx_prbs_select <= 0; prbs_counter_reset <= 1;
      snapshot_id_status <= LANE_ID; snapshot_errors <= 0;
      snapshot_tested_bits <= 0; snapshot_lock_losses <= 0; snapshot_valid_cycles <= 0;
      error_count <= 0; tested_bits <= 0; valid_cycles <= 0; lock_loss_count <= 0;
      error_saturated <= 0; bit_count_saturated <= 0; rx_prbs_errors_q <= 0;
      measure_meta <= 0; measure_sync <= 0;
    end else if (rx_reset) begin
      config_ack <= 0;
      // GT recovery freezes protocol and measurement state for every lane,
      // including unselected lanes and lanes awaiting snapshot acknowledgement.
      // Clear/reapply controls without manufacturing another start event.
      lock_meta <= 0;
      lock_sync <= 0;
      cdr_lock_meta <= 0;
      cdr_lock_sync <= 0;
      measure_meta <= 0;
      measure_sync <= 0;
      tx_prbs_select <= 0;
      rx_prbs_select <= 0;
      prbs_counter_reset <= 1;
      restart_rearm_pending <= 1;
      rx_prbs_errors_q <= 0;
    end else begin
      config_ack <= 0;
      // Requests take two stages longer than descriptor data. Equal request
      // depths also preserve start-before-stop ordering on an early abort.
      // The management controller keeps descriptor data
      // unchanged for the complete start-to-stop transaction.
      start_req_meta <= start_req_toggle;
      start_req_sync <= start_req_meta;
      start_req_guard0 <= start_req_sync;
      start_req_guard1 <= start_req_guard0;
      stop_req_meta <= stop_req_toggle;
      stop_req_sync <= stop_req_meta;
      stop_req_guard0 <= stop_req_sync;
      stop_req_guard1 <= stop_req_guard0;
      selected_meta <= descriptor_selected;
      selected_sync <= selected_meta;
      prbs_meta <= descriptor_prbs_mode;
      prbs_sync <= prbs_meta;
      lock_meta <= rx_lock_sample;
      lock_sync <= lock_meta;
      cdr_lock_meta <= rx_cdr_locked;
      cdr_lock_sync <= cdr_lock_meta;
      measure_meta <= measurement_enable;
      measure_sync <= measure_meta;
      controls_meta <= controls_enable;
      controls_sync <= controls_meta;
      rx_prbs_errors_q <= rx_error_sample;
      prbs_counter_reset <= 0;

      if (restart_rearm_pending) begin
        // Descriptor CDC state and the selected/running state were held while
        // reset was active. Reapply both checkers without manufacturing a new
        // start acknowledgement or depending on the request-toggle polarity.
        restart_rearm_pending <= 0;
        tx_prbs_select <= (selected && running) ? accepted_prbs_mode : 3'd0;
        rx_prbs_select <= (selected && running) ? accepted_prbs_mode : 3'd0;
        prbs_counter_reset <= selected && running;
        previous_lock <= qualified_lock;
      end else if (start_req_guard1 != start_seen) begin
        // Latch the descriptor exactly once per start toggle.  Unselected
        // lanes still acknowledge the request but never enable GT PRBS logic.
        start_seen <= start_req_guard1;
        start_ack_toggle <= start_req_guard1;
        selected <= selected_sync;
        accepted_prbs_mode <= prbs_sync;
        tx_prbs_select <= selected_sync ? prbs_sync : 3'd0;
        rx_prbs_select <= selected_sync ? prbs_sync : 3'd0;
        prbs_counter_reset <= selected_sync;
        running <= selected_sync;
        previous_lock <= qualified_lock;
        error_count <= 0;
        tested_bits <= 0;
        valid_cycles <= 0;
        lock_loss_count <= 0;
        error_saturated <= 0;
        bit_count_saturated <= 0;
        stop_pending <= 0;
      end else if (running && measure_sync) begin
        // Count only locked RX cycles as tested data.  Lock-loss transitions
        // remain visible even though unlocked intervals add no tested bits.
        // RXPRBSLOCKED remained asserted through the v11 FireFly outage even
        // though the module reported CDR LOL. Treat either PRBS-lock or the
        // native per-lane RXCDRLOCK falling as a runtime lock loss.
        previous_lock <= qualified_lock;
        if (previous_lock && !qualified_lock &&
            lock_loss_count != 32'hffff_ffff)
          lock_loss_count <= lock_loss_count + 1'b1;
        if (qualified_lock) begin
          valid_cycles <= saturating_add64(valid_cycles, 64'd1);
          tested_bits <= saturating_add64(tested_bits, USER_BITS_PER_CYCLE);
          if (tested_bits > (64'hffff_ffff_ffff_ffff - USER_BITS_PER_CYCLE))
            bit_count_saturated <= 1;
        end
        if (!error_saturated) begin
          error_count[15:0] <= error_low_sum[15:0];
          if (error_low_sum[16]) begin
            if (&error_count[63:16]) begin
              error_count <= 64'hffff_ffff_ffff_ffff;
              error_saturated <= 1;
            end else begin
              error_count[63:16] <= error_count[63:16] + 1'b1;
            end
          end
        end
      end

      if (stop_req_guard1 != stop_seen) begin
        // Stop the live counters immediately, then wait one RX cycle before
        // copying them so the registered final error sample is included.
        stop_seen <= stop_req_guard1;
        stop_pending <= 1;
        running <= 0;
      end

      if (!controls_sync && !running && !stop_pending) begin
        tx_prbs_select <= 0;
        rx_prbs_select <= 0;
      end

      // Defer the snapshot by one RX clock.  The running block on the stop
      // edge consumes rx_prbs_errors_q, which is the final pre-stop sample;
      // the deferred snapshot observes that registered counter update.
      if (stop_pending) begin
        stop_pending <= 0;
        snapshot_send <= 1;
        snapshot_id_status <= {
          16'd0,
          bit_count_saturated,
          error_saturated,
          (lock_loss_count != 0),
          qualified_lock,
          selected,
          3'b000,
          LANE_ID[7:0]
        };
        snapshot_errors <= error_count;
        snapshot_tested_bits <= tested_bits;
        snapshot_lock_losses <= lock_loss_count;
        snapshot_valid_cycles <= valid_cycles;
      end

      // The snapshot payload remains unchanged while snapshot_send is high.
      // For an asynchronous lane, the XPM handshake captures all 256 bits in
      // the management domain before returning snapshot_rcv.  Only then may
      // the global controller observe this lane's stop acknowledgement.
      if (snapshot_send && snapshot_rcv) begin
        snapshot_send <= 0;
        stop_ack_toggle <= stop_seen;
      end
    end
  end

endmodule
