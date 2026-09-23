`timescale 1ns/1ps

// Quad-local sequencer for the device-specific PRBS acquisition and result
// capture operations that cannot safely be performed by the generic engine.
module gt_prbs_test_controller #(
  parameter int unsigned SETTLE_CYCLES = 32,
  parameter int unsigned RESET_PULSE_CYCLES = 16,
  parameter int unsigned RUNNING_MASK_SETTLE_CYCLES = 16,
  parameter int unsigned ERROR_FREE_QUALIFY_CYCLES = 200_000,
  parameter bit STAGED_RX_ACQUISITION = 1'b0,
  parameter bit REQUIRE_ERROR_FREE_QUALIFICATION = 1'b1,
  parameter bit EXTERNAL_RX_RECOVERY = 1'b0,
  parameter bit EXTERNAL_QUAD_RECOVERY = 1'b0,
  parameter bit EXTERNAL_STARTUP_QUAD_RESTART = 1'b0,
  parameter bit POST_CAPTURE_RX_REQUAL = 1'b0,
  parameter bit POST_CAPTURE_QUAD_RESTART = 1'b0,
  parameter bit RETAIN_POST_CLEANUP_IDLE_GUARD = 1'b0,
  parameter bit RUNTIME_INTEGRITY_DETECTOR = 1'b0,
  parameter bit INTEGRITY_HEARTBEAT_TEST_HOOK = 1'b0,
  parameter int unsigned INTEGRITY_ERROR_ASSERT_CYCLES = 20_000_000,
  parameter int unsigned INTEGRITY_ERROR_CLEAR_CYCLES = 200_000,
  parameter int unsigned INTEGRITY_CLOCK_TIMEOUT_CYCLES = 20_000_000,
  parameter int unsigned EXTERNAL_LOCK_RECOVERY_CYCLES = 20_000_000,
  parameter int unsigned POST_CAPTURE_SETTLE_CYCLES = 20_000_000,
  parameter int unsigned OPERATION_TIMEOUT_CYCLES = 2_000_000_000
) (
  input  wire         mgmt_clk,
  input  wire         resetn,
  input  wire [3:0]   lane_running_async,
  input  wire [3:0]   rx_prbs_locked_async,
  input  wire [3:0]   rx_prbs_error_async,
  input  wire [2:0]   requested_loopback,
  input  wire         acquisition_active,
  input  wire         measurement_enable,
  input  wire         rx_clock_heartbeat_async,
  input  wire         result_capture_request,
  input  wire         gtwiz_reset_rx_done_async,
  input  wire [3:0]   rxresetdone_async,
  input  wire [3:0]   rxpmaresetdone_async,
  input  wire         quad_ready,

  output logic [2:0]  applied_loopback,
  output logic        gtwiz_reset_rx_datapath,
  output logic [3:0]  rxpmareset,
  output logic [3:0]  sequenced_prbs_counter_reset,
  output logic        rx_checker_enable,
  output logic        acquisition_ready,
  output logic        runtime_rx_reset_active,
  output logic        quad_restart_request,
  output logic        controller_idle,
  output logic        controller_fault,
  output wire [4:0]   diagnostic_state,
  output wire [31:0]  diagnostic_live,
  output wire [31:0]  diagnostic_rx,
  output wire [31:0]  diagnostic_counter,
  output wire [255:0] recovery_diagnostics,

  output logic [39:0] drpaddr,
  output wire [3:0]   drpclk,
  output logic [63:0] drpdi,
  output logic [3:0]  drpen,
  output logic [3:0]  drpwe,
  input  wire [63:0]  drpdo,
  input  wire [3:0]   drprdy,
  output logic         result_capture_done,
  output logic [127:0] exact_error_counts,
  output logic [3:0]  exact_error_valid,
  output logic [3:0]  exact_error_saturated
);
  typedef enum logic [4:0] {
    ST_IDLE                    = 5'd0,
    ST_CONTROL_SETTLE          = 5'd1,
    ST_RX_RESET_ASSERT         = 5'd2,
    ST_RX_RESET_WAIT           = 5'd3,
    ST_LOOPBACK_SETTLE         = 5'd4,
    ST_PMA_RESET_ASSERT        = 5'd5,
    ST_PMA_RESET_WAIT          = 5'd6,
    ST_COUNTER_RESET           = 5'd7,
    ST_LOCK_WAIT               = 5'd8,
    ST_POST_LOCK_COUNTER_RESET = 5'd9,
    ST_MEASURE                 = 5'd10,
    ST_CAPTURE_WAIT            = 5'd11,
    ST_DRP_LOW_START           = 5'd12,
    ST_DRP_LOW_WAIT            = 5'd13,
    ST_DRP_HIGH_START          = 5'd14,
    ST_DRP_HIGH_WAIT           = 5'd15,
    ST_CAPTURE_DONE            = 5'd16,
    ST_CLEAN_RESET_ASSERT      = 5'd17,
    ST_CLEAN_RESET_WAIT        = 5'd18,
    ST_FAULT                   = 5'd19,
    ST_RX_CHECKER_SETTLE       = 5'd20,
    ST_ERROR_FREE_QUALIFY      = 5'd21,
    ST_POST_CAPTURE_RX_REQUAL  = 5'd22,
    ST_QUAD_RESTART_REQUEST    = 5'd23,
    ST_QUAD_RESTART_WAIT       = 5'd24,
    ST_EXTERNAL_FAILURE_QUALIFY = 5'd25,
    ST_POST_LOCK_COUNTER_SETTLE = 5'd26,
    ST_RUNTIME_INTEGRITY_FAULT  = 5'd27
  } state_t;

  // The sequence has three distinct phases: prepare/reacquire the RX path,
  // expose a stable measurement window to the generic engine, and read the
  // native 32-bit GT error counters through DRP after measurement stops.
  // State numbers are an external diagnostic ABI; do not let synthesis
  // recode them when fanout changes between development candidates.
  (* fsm_encoding = "none" *) state_t state = ST_IDLE;
  (* ASYNC_REG = "TRUE" *) logic [3:0] running_meta = 0, running_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic [3:0] locked_meta = 0, locked_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic [3:0] error_meta = 0, error_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic reset_done_meta = 0, reset_done_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic [3:0] rxreset_meta = 0, rxreset_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic [3:0] pma_done_meta = 0, pma_done_sync = 0;
  logic [3:0] selected_lanes = 0;
  logic [2:0] active_loopback = 0;
  logic [31:0] counter = 0;
  logic cleanup_wizard_reset_seen = 0;
  logic [3:0] cleanup_lane_reset_seen = 0;
  // PMA-loopback cleanup can produce more than one delayed RX reset-done
  // transition after LOOPBACK and RXPRBSSEL are removed.  Once cleanup has
  // completed, keep the supervisor's intentional-RX-change qualification
  // asserted throughout IDLE.  The next accepted acquisition already owns
  // the guard through its setup and requalifies RX before measurement.
  logic post_cleanup_idle_guard = 0;
  logic [1:0] drp_lane = 0;
  logic [15:0] drp_low_word = 0;
  logic [4:0] fault_stage = 0;
  logic [3:0] lock_seen = 0;
  logic [3:0] lock_lost_seen = 0;
  logic [3:0] running_candidate = 0;
  logic [31:0] running_mask_settle_count = 0;
  logic [31:0] error_free_count = 0;
  logic [31:0] maximum_clean_count = 0;
  logic [3:0] qualification_error_seen = 0;
  logic [3:0] qualification_unlock_seen = 0;
  logic external_rx_recovery_attempted = 0;
  logic startup_quad_restart_issued = 0;
  logic post_capture_restart = 0;
  wire runtime_integrity_fault;
  wire [3:0] integrity_error_fault_lanes;
  wire integrity_clock_fault;
  wire [31:0] integrity_event_count, integrity_state;
  wire [3:0] retained_integrity_error_lanes;
  wire retained_integrity_clock_fault;

  gt_runtime_integrity_monitor #(
    .ERROR_ASSERT_CYCLES(INTEGRITY_ERROR_ASSERT_CYCLES),
    .ERROR_CLEAR_CYCLES(INTEGRITY_ERROR_CLEAR_CYCLES),
    .HEARTBEAT_TIMEOUT_CYCLES(INTEGRITY_CLOCK_TIMEOUT_CYCLES)
  ) u_runtime_integrity_monitor (
    .mgmt_clk(mgmt_clk), .resetn(resetn),
    .monitor_enable(RUNTIME_INTEGRITY_DETECTOR && measurement_enable),
    .selected_lanes(selected_lanes),
    .rx_prbs_error_async(rx_prbs_error_async),
    .rx_clock_heartbeat_async(rx_clock_heartbeat_async),
    .integrity_fault(runtime_integrity_fault),
    .error_fault_lanes(integrity_error_fault_lanes),
    .clock_fault(integrity_clock_fault),
    .event_count(integrity_event_count),
    .retained_error_lanes(retained_integrity_error_lanes),
    .retained_clock_fault(retained_integrity_clock_fault),
    .diagnostic_state(integrity_state)
  );

  // Persistent management-domain evidence. These records survive IDLE and
  // subsequent requests; only resetn clears them. Count request edges, not
  // cycles in the level handshake. Completion means supervisor readiness
  // returned; it does not claim that PRBS reacquisition succeeded.
  logic [31:0] restart_count = 0, restart_completed_count = 0;
  logic [31:0] restart_accepted_count = 0;
  logic [7:0] restart_cause = 0, restart_status = 0;
  logic [4:0] previous_state = ST_IDLE;
  logic [3:0] restart_lanes = 0;
  assign recovery_diagnostics = {
    RUNTIME_INTEGRITY_DETECTOR ? integrity_state : 32'd0,
    RUNTIME_INTEGRITY_DETECTOR ? integrity_event_count : 32'd0,
    restart_accepted_count,
    {12'd0, restart_lanes, restart_status, restart_cause},
    restart_completed_count, restart_count,
    {29'd0, INTEGRITY_HEARTBEAT_TEST_HOOK,
     RUNTIME_INTEGRITY_DETECTOR, 1'b1},
    32'h5243_0001  // "RC", schema 1
  };
  always_ff @(posedge mgmt_clk) begin
    if (!resetn) begin
      previous_state <= ST_IDLE;
      restart_count <= 0;
      restart_completed_count <= 0;
      restart_accepted_count <= 0;
      restart_cause <= 0;
      restart_status <= 0;
      restart_lanes <= 0;
    end else begin
      previous_state <= state;
      if (state == ST_QUAD_RESTART_REQUEST &&
          previous_state != ST_QUAD_RESTART_REQUEST) begin
        if (!(&restart_count)) restart_count <= restart_count + 1'b1;
        restart_cause <= previous_state == ST_LOCK_WAIT ? 8'd1 :
                         previous_state == ST_EXTERNAL_FAILURE_QUALIFY ? 8'd2 :
                         previous_state == ST_CAPTURE_DONE ? 8'd3 :
                         previous_state == ST_CONTROL_SETTLE &&
                           EXTERNAL_STARTUP_QUAD_RESTART ? 8'd4 : 8'hff;
        restart_status <= 8'd1; // requested
        restart_lanes <= selected_lanes;
      end
      if (state == ST_QUAD_RESTART_REQUEST && !quad_ready) begin
        if (!(&restart_accepted_count))
          restart_accepted_count <= restart_accepted_count + 1'b1;
        restart_status <= 8'd2; // acknowledged by supervisor
      end
      if (state == ST_QUAD_RESTART_WAIT && quad_ready) begin
        if (!(&restart_completed_count))
          restart_completed_count <= restart_completed_count + 1'b1;
        restart_status <= 8'd3; // supervisor completed
      end
      if (state == ST_FAULT && previous_state != ST_FAULT &&
          (restart_status == 1 || restart_status == 2))
        restart_status <= 8'd4; // timeout/failure before completion
    end
  end

  wire selected_locked = (locked_sync & selected_lanes) == selected_lanes;
  wire selected_error = |(error_sync & selected_lanes);
  wire selected_rx_done = (rxreset_sync & selected_lanes) == selected_lanes;
  wire selected_pma_done = (pma_done_sync & selected_lanes) == selected_lanes;
  wire current_lane_selected = selected_lanes[drp_lane];

  assign drpclk = {4{mgmt_clk}};
  assign diagnostic_state = controller_fault ? fault_stage : state;
  // These words deliberately expose synchronized rather than raw GT status.
  // lock_seen/lock_lost_seen retain intermittent acquisition behavior that
  // would otherwise disappear when the engine removes PRBS controls.
  assign diagnostic_live = {
    controller_fault, controller_idle, runtime_rx_reset_active,
    acquisition_ready, lock_lost_seen, lock_seen, locked_sync,
    running_sync, selected_lanes, active_loopback, diagnostic_state
  };
  // The fixed-window 2.5.2 experiment replaces the ordinary RX-qualifier
  // word with acquisition evidence.  This is parameterized off in every
  // historical target.  Bit 0 is a format marker so its decoder cannot
  // silently interpret this as the legacy layout.
  assign diagnostic_rx =
    (STAGED_RX_ACQUISITION && !REQUIRE_ERROR_FREE_QUALIFICATION) ? {
      qualification_error_seen, qualification_unlock_seen,
      maximum_clean_count[17:0], selected_error, selected_locked,
      reset_done_sync, selected_rx_done, selected_pma_done, 1'b1
    } : {
      2'd0, requested_loopback, applied_loopback, drprdy, drpen,
      result_capture_done, result_capture_request, rxpmareset,
      gtwiz_reset_rx_datapath, pma_done_sync, rxreset_sync, reset_done_sync
    };
  assign diagnostic_counter = counter;

  // Reset completion is a low-then-high handshake, not a sampled high level.
  // Latch each lane independently because low intervals need not overlap.
  always_ff @(posedge mgmt_clk) begin
    if (!resetn || state == ST_CAPTURE_DONE) begin
      cleanup_wizard_reset_seen <= 0;
      cleanup_lane_reset_seen <= 0;
    end else if (state == ST_CLEAN_RESET_ASSERT || state == ST_CLEAN_RESET_WAIT) begin
      cleanup_wizard_reset_seen <= cleanup_wizard_reset_seen | !reset_done_sync;
      cleanup_lane_reset_seen <= cleanup_lane_reset_seen | ~rxreset_sync;
    end
  end

  always_comb begin
    // Near-end PMA loopback (010) uses the disruptive RX datapath and PMA
    // reset sequence.  External-path acquisition deliberately leaves the RX
    // datapath running: hardware tests showed that resetting an already-live
    // external receiver could lock while producing continuous PRBS errors.
    applied_loopback = (state == ST_LOOPBACK_SETTLE ||
                        state == ST_PMA_RESET_ASSERT ||
                        state == ST_PMA_RESET_WAIT ||
                        state == ST_RX_CHECKER_SETTLE ||
                        state == ST_COUNTER_RESET || state == ST_LOCK_WAIT ||
                        state == ST_ERROR_FREE_QUALIFY ||
                        state == ST_POST_LOCK_COUNTER_RESET ||
                        state == ST_POST_LOCK_COUNTER_SETTLE ||
                        state == ST_MEASURE || state == ST_CAPTURE_WAIT ||
                        state == ST_DRP_LOW_START || state == ST_DRP_LOW_WAIT ||
                        state == ST_DRP_HIGH_START || state == ST_DRP_HIGH_WAIT ||
                        state == ST_CAPTURE_DONE) ? active_loopback : 3'b000;
    gtwiz_reset_rx_datapath = (state == ST_RX_RESET_ASSERT ||
                                state == ST_CLEAN_RESET_ASSERT);
    rxpmareset = (state == ST_PMA_RESET_ASSERT) ? selected_lanes : 4'b0000;
    // Clear once before acquisition and again after every selected lane has
    // locked.  The second pulse prevents acquisition errors from contaminating
    // the timed result while preserving the first pulse's deterministic
    // checker initialization.
    sequenced_prbs_counter_reset =
      (state == ST_COUNTER_RESET || state == ST_POST_LOCK_COUNTER_RESET)
        ? selected_lanes : 4'b0000;
    // Milestone 2.5.1 deliberately establishes the TX pattern before the RX
    // checker is enabled. Historical and full-M3 targets keep their original
    // behavior until the isolated experiment is accepted on hardware.
    rx_checker_enable = !STAGED_RX_ACQUISITION ||
                        state == ST_RX_CHECKER_SETTLE ||
                        state == ST_COUNTER_RESET ||
                        state == ST_LOCK_WAIT ||
                        state == ST_ERROR_FREE_QUALIFY ||
                        state == ST_EXTERNAL_FAILURE_QUALIFY ||
                        state == ST_POST_LOCK_COUNTER_RESET ||
                        state == ST_POST_LOCK_COUNTER_SETTLE ||
                        state == ST_MEASURE || state == ST_CAPTURE_WAIT ||
                        state == ST_DRP_LOW_START || state == ST_DRP_LOW_WAIT ||
                        state == ST_DRP_HIGH_START ||
                        state == ST_DRP_HIGH_WAIT ||
                        state == ST_CAPTURE_DONE;
    acquisition_ready = state == ST_MEASURE;
    // Qualify RX status from the management-domain ARM interval through PRBS
    // lock.  This covers control CDC latency for external acquisition without
    // resetting the live receiver, and covers the complete disruptive reset
    // sequence for PMA loopback.  Normal measurement is never masked.
    runtime_rx_reset_active = post_cleanup_idle_guard ||
                              ((acquisition_active &&
                                (state == ST_IDLE ||
                                 state == ST_CONTROL_SETTLE ||
                                 state == ST_RX_RESET_ASSERT ||
                                 state == ST_RX_RESET_WAIT ||
                                 state == ST_LOOPBACK_SETTLE ||
                                 state == ST_PMA_RESET_ASSERT ||
                                 state == ST_PMA_RESET_WAIT ||
                                 state == ST_RX_CHECKER_SETTLE ||
                                 state == ST_COUNTER_RESET ||
                                 state == ST_LOCK_WAIT ||
                                 state == ST_ERROR_FREE_QUALIFY ||
                                 state == ST_EXTERNAL_FAILURE_QUALIFY ||
                                 state == ST_POST_LOCK_COUNTER_RESET ||
                                 state == ST_POST_LOCK_COUNTER_SETTLE)) ||
                               state == ST_RX_RESET_ASSERT ||
                               state == ST_RX_RESET_WAIT ||
                               state == ST_LOOPBACK_SETTLE ||
                               state == ST_PMA_RESET_ASSERT ||
                               state == ST_PMA_RESET_WAIT ||
                               state == ST_RX_CHECKER_SETTLE ||
                               state == ST_CAPTURE_DONE ||
                               (active_loopback == 3'b010 &&
                                (state == ST_COUNTER_RESET ||
                                 state == ST_LOCK_WAIT)) ||
                               state == ST_CLEAN_RESET_ASSERT ||
                               state == ST_CLEAN_RESET_WAIT ||
                               state == ST_POST_CAPTURE_RX_REQUAL ||
                               state == ST_QUAD_RESTART_REQUEST ||
                               state == ST_QUAD_RESTART_WAIT);
    quad_restart_request = state == ST_QUAD_RESTART_REQUEST;
    controller_idle = state == ST_IDLE;
    controller_fault = state == ST_FAULT;
    drpaddr = 40'd0;
    drpdi = 64'd0;
    drpen = 4'b0000;
    drpwe = 4'b0000;
    if (state == ST_DRP_LOW_START || state == ST_DRP_LOW_WAIT) begin
      // UltraScale+ RX_PRBS_ERR_CNT is split across DRP addresses 25E/25F.
      // Reads are serialized per selected lane so each published count is an
      // exact native counter value rather than sampled RXPRBSERR pulses.
      drpaddr[drp_lane*10 +: 10] = 10'h25e;
      drpen[drp_lane] = state == ST_DRP_LOW_START;
    end else if (state == ST_DRP_HIGH_START || state == ST_DRP_HIGH_WAIT) begin
      drpaddr[drp_lane*10 +: 10] = 10'h25f;
      drpen[drp_lane] = state == ST_DRP_HIGH_START;
    end
  end

  always_ff @(posedge mgmt_clk) begin
    running_meta <= lane_running_async;
    running_sync <= running_meta;
    locked_meta <= rx_prbs_locked_async;
    locked_sync <= locked_meta;
    error_meta <= rx_prbs_error_async;
    error_sync <= error_meta;
    reset_done_meta <= gtwiz_reset_rx_done_async;
    reset_done_sync <= reset_done_meta;
    rxreset_meta <= rxresetdone_async;
    rxreset_sync <= rxreset_meta;
    pma_done_meta <= rxpmaresetdone_async;
    pma_done_sync <= pma_done_meta;

    if (!resetn) begin
      state <= ST_IDLE;
      selected_lanes <= 0;
      active_loopback <= 0;
      counter <= 0;
      drp_lane <= 0;
      drp_low_word <= 0;
      result_capture_done <= 0;
      exact_error_counts <= 0;
      exact_error_valid <= 0;
      exact_error_saturated <= 0;
      fault_stage <= 0;
      lock_seen <= 0;
      lock_lost_seen <= 0;
      running_candidate <= 0;
      running_mask_settle_count <= 0;
      error_free_count <= 0;
      maximum_clean_count <= 0;
      qualification_error_seen <= 0;
      qualification_unlock_seen <= 0;
      external_rx_recovery_attempted <= 0;
      startup_quad_restart_issued <= 0;
      post_capture_restart <= 0;
      post_cleanup_idle_guard <= 0;
    end else begin
      if ((state == ST_LOCK_WAIT ||
           state == ST_ERROR_FREE_QUALIFY ||
           state == ST_POST_LOCK_COUNTER_RESET ||
           state == ST_MEASURE) && |selected_lanes) begin
        lock_seen <= lock_seen | (locked_sync & selected_lanes);
        lock_lost_seen <= lock_lost_seen |
          (lock_seen & selected_lanes & ~locked_sync);
      end
      case (state)
        ST_IDLE: begin
          // lane_running is asserted only after the generic engine has latched
          // a valid descriptor.  Snapshot the participating physical lanes and
          // loopback choice for the complete operation.
          result_capture_done <= 0;
          counter <= 0;
          if (!acquisition_active || !(|running_sync)) begin
            running_candidate <= 0;
            running_mask_settle_count <= 0;
          end else if (running_sync != running_candidate) begin
            // The per-lane running indications cross independently.  Do not
            // snapshot the first nonzero partial vector; wait until the whole
            // vector has remained unchanged for a bounded settling interval.
            running_candidate <= running_sync;
            running_mask_settle_count <= 1;
          end else if (running_mask_settle_count + 1 >=
                       RUNNING_MASK_SETTLE_CYCLES) begin
            selected_lanes <= running_candidate;
            active_loopback <= requested_loopback;
            lock_seen <= 0;
            lock_lost_seen <= 0;
            // Preserve the preceding run's acquisition evidence throughout
            // IDLE. Clear it only when this controller accepts the next
            // stable running mask and begins a new physical acquisition.
            maximum_clean_count <= 0;
            qualification_error_seen <= 0;
            qualification_unlock_seen <= 0;
            external_rx_recovery_attempted <= 0;
            startup_quad_restart_issued <= 0;
            post_capture_restart <= 0;
            // Clearing this latch cannot expose RX status: acquisition_active
            // keeps runtime_rx_reset_active asserted from this acceptance
            // point through physical setup and PRBS reacquisition.
            post_cleanup_idle_guard <= 0;
            running_mask_settle_count <= 0;
            exact_error_counts <= 0;
            exact_error_valid <= 0;
            exact_error_saturated <= 0;
            state <= ST_CONTROL_SETTLE;
          end else running_mask_settle_count <=
            running_mask_settle_count + 1'b1;
        end

        ST_CONTROL_SETTLE: begin
          if (counter + 1 >= SETTLE_CYCLES) begin
            counter <= 0;
            if (EXTERNAL_STARTUP_QUAD_RESTART &&
                active_loopback == 3'b000 &&
                !startup_quad_restart_issued) begin
              // Diagnostic-only policy experiment: after the TX selection has
              // settled, perform one coordinated restart before enabling the
              // RX checker. Mark the ordinary recovery budget consumed so a
              // failed post-restart acquisition cannot silently reset again.
              startup_quad_restart_issued <= 1;
              external_rx_recovery_attempted <= 1;
              state <= ST_QUAD_RESTART_REQUEST;
            end else begin
              state <= active_loopback == 3'b010
                ? ST_RX_RESET_ASSERT
                : (STAGED_RX_ACQUISITION
                   ? ST_RX_CHECKER_SETTLE : ST_COUNTER_RESET);
            end
          end else counter <= counter + 1'b1;
        end

        ST_RX_RESET_ASSERT: begin
          if (counter + 1 >= RESET_PULSE_CYCLES) begin
            counter <= 0;
            state <= ST_RX_RESET_WAIT;
          end else counter <= counter + 1'b1;
        end

        ST_RX_RESET_WAIT: begin
          if (reset_done_sync && selected_rx_done) begin
            counter <= 0;
            state <= active_loopback == 3'b010
              ? ST_LOOPBACK_SETTLE
              : (STAGED_RX_ACQUISITION
                 ? ST_RX_CHECKER_SETTLE : ST_COUNTER_RESET);
          end else if (counter + 1 >= OPERATION_TIMEOUT_CYCLES) begin
            fault_stage <= ST_RX_RESET_WAIT;
            state <= ST_FAULT;
          end else counter <= counter + 1'b1;
        end

        ST_LOOPBACK_SETTLE: begin
          if (counter + 1 >= SETTLE_CYCLES) begin
            counter <= 0;
            state <= ST_PMA_RESET_ASSERT;
          end else counter <= counter + 1'b1;
        end

        ST_PMA_RESET_ASSERT: begin
          if (counter + 1 >= RESET_PULSE_CYCLES) begin
            counter <= 0;
            state <= ST_PMA_RESET_WAIT;
          end else counter <= counter + 1'b1;
        end

        ST_PMA_RESET_WAIT: begin
          if (selected_pma_done) begin
            counter <= 0;
            state <= STAGED_RX_ACQUISITION
              ? ST_RX_CHECKER_SETTLE : ST_COUNTER_RESET;
          end else if (counter + 1 >= OPERATION_TIMEOUT_CYCLES) begin
            fault_stage <= ST_PMA_RESET_WAIT;
            state <= ST_FAULT;
          end else counter <= counter + 1'b1;
        end

        ST_RX_CHECKER_SETTLE: begin
          // TXPRBSSEL is already stable. Apply RXPRBSSEL only now and allow
          // its RX-clock-domain control path to settle before acquisition.
          if (counter + 1 >= SETTLE_CYCLES) begin
            counter <= 0;
            state <= ST_COUNTER_RESET;
          end else counter <= counter + 1'b1;
        end

        ST_COUNTER_RESET: begin
          if (counter + 1 >= RESET_PULSE_CYCLES) begin
            counter <= 0;
            state <= ST_LOCK_WAIT;
          end else counter <= counter + 1'b1;
        end

        ST_LOCK_WAIT: begin
          // Measurement cannot begin until every selected lane is locked.
          // Reset the native counters once more after lock so errors observed
          // during checker acquisition cannot contaminate the timed result.
          if (selected_locked) begin
            counter <= 0;
            error_free_count <= 0;
            state <= STAGED_RX_ACQUISITION
              ? ST_ERROR_FREE_QUALIFY : ST_POST_LOCK_COUNTER_RESET;
          end else if (EXTERNAL_QUAD_RECOVERY &&
                       active_loopback == 3'b000 &&
                       !external_rx_recovery_attempted &&
                       counter + 1 >= EXTERNAL_LOCK_RECOVERY_CYCLES) begin
            // If the live external checker does not lock, request one full
            // coordinated quad restart.  The quad controller owns Wizard
            // reset and acknowledges by dropping quad_ready.  Never loop: a
            // second failure consumes the ordinary LOCK_WAIT timeout.
            counter <= 0;
            external_rx_recovery_attempted <= 1;
            state <= ST_QUAD_RESTART_REQUEST;
          end else if (EXTERNAL_RX_RECOVERY &&
                       active_loopback == 3'b000 &&
                       !external_rx_recovery_attempted &&
                       counter + 1 >= EXTERNAL_LOCK_RECOVERY_CYCLES) begin
            // Preserve the normal non-disruptive external path when its
            // already-live checker locks promptly. If it does not, perform
            // one bounded RX-datapath reset and checker restart, matching the
            // recovery action that makes the golden IBERT link deterministic.
            // Never loop: a second failure consumes the ordinary operation
            // timeout and publishes the existing LOCK_WAIT fault.
            counter <= 0;
            external_rx_recovery_attempted <= 1;
            state <= ST_RX_RESET_ASSERT;
          end else if (counter + 1 >= OPERATION_TIMEOUT_CYCLES) begin
            fault_stage <= ST_LOCK_WAIT;
            state <= ST_FAULT;
          end else counter <= counter + 1'b1;
        end

        ST_QUAD_RESTART_REQUEST: begin
          // Hold the level request until the supervisor has accepted it and
          // removed readiness.  This makes the handshake insensitive to the
          // relative state-machine phases on the shared management clock.
          if (!quad_ready) begin
            counter <= 0;
            state <= ST_QUAD_RESTART_WAIT;
          end else if (counter + 1 >= OPERATION_TIMEOUT_CYCLES) begin
            fault_stage <= ST_QUAD_RESTART_REQUEST;
            state <= ST_FAULT;
          end else counter <= counter + 1'b1;
        end

        ST_QUAD_RESTART_WAIT: begin
          // The supervisor performs its ordinary bounded full-quad bring-up.
          // Once ready, reapply the checker and restart acquisition from a
          // deterministic counter-clear sequence.
          if (quad_ready) begin
            counter <= 0;
            if (post_capture_restart) begin
              post_capture_restart <= 0;
              state <= ST_IDLE;
            end else begin
              state <= ST_RX_CHECKER_SETTLE;
            end
          end else if (counter + 1 >= OPERATION_TIMEOUT_CYCLES) begin
            fault_stage <= ST_QUAD_RESTART_WAIT;
            state <= ST_FAULT;
          end else counter <= counter + 1'b1;
        end

        ST_ERROR_FREE_QUALIFY: begin
          // 2.5.1 required a clean interval and timed out.  The 2.5.2 mode
          // instead observes one fixed interval, records its error/unlock
          // evidence, then clears the native counter and measures anyway.
          qualification_error_seen <= qualification_error_seen |
            (error_sync & selected_lanes);
          qualification_unlock_seen <= qualification_unlock_seen |
            (~locked_sync & selected_lanes);
          if (!selected_locked || selected_error) begin
            error_free_count <= 0;
          end else begin
            error_free_count <= error_free_count + 1'b1;
            if (error_free_count + 1 > maximum_clean_count)
              maximum_clean_count <= error_free_count + 1'b1;
          end

          if (!REQUIRE_ERROR_FREE_QUALIFICATION &&
              counter + 1 >= ERROR_FREE_QUALIFY_CYCLES) begin
            counter <= 0;
            error_free_count <= 0;
            // Preserve the fixed 1-ms observation. If it saw errors or
            // unlocks, require a subsequent continuous clean interval. This
            // detects sustained garbage even when RXPRBSLOCKED stays high.
            state <= (EXTERNAL_QUAD_RECOVERY &&
                      active_loopback == 3'b000 &&
                      (!external_rx_recovery_attempted ||
                       (EXTERNAL_STARTUP_QUAD_RESTART &&
                        startup_quad_restart_issued)) &&
                      (|(qualification_error_seen |
                         qualification_unlock_seen) ||
                       selected_error || !selected_locked))
              ? ST_EXTERNAL_FAILURE_QUALIFY
              : ST_POST_LOCK_COUNTER_RESET;
          end else if (counter + 1 >= OPERATION_TIMEOUT_CYCLES) begin
            fault_stage <= ST_ERROR_FREE_QUALIFY;
            state <= ST_FAULT;
          end else if (!REQUIRE_ERROR_FREE_QUALIFICATION) begin
            counter <= counter + 1'b1;
          end else if (!selected_locked || selected_error) begin
            counter <= counter + 1'b1;
          end else if (error_free_count + 1 >=
                       ERROR_FREE_QUALIFY_CYCLES) begin
            counter <= 0;
            error_free_count <= 0;
            state <= ST_POST_LOCK_COUNTER_RESET;
          end else begin
            counter <= counter + 1'b1;
          end
        end

        ST_EXTERNAL_FAILURE_QUALIFY: begin
          // A clean link escapes after one continuous 1-ms interval. If no
          // such interval occurs within 100 ms, perform the bounded one-shot
          // full-quad recovery used for a missing PRBS lock.
          if (selected_locked && !selected_error) begin
            if (error_free_count + 1 >= ERROR_FREE_QUALIFY_CYCLES) begin
              counter <= 0;
              error_free_count <= 0;
              state <= ST_POST_LOCK_COUNTER_RESET;
            end else begin
              error_free_count <= error_free_count + 1'b1;
              counter <= counter + 1'b1;
            end
          end else begin
            error_free_count <= 0;
            if (counter + 1 >= EXTERNAL_LOCK_RECOVERY_CYCLES) begin
              counter <= 0;
              if (EXTERNAL_STARTUP_QUAD_RESTART &&
                  startup_quad_restart_issued) begin
                // The planned restart already consumed the only reset budget.
                // Preserve a conclusive post-restart qualification failure.
                fault_stage <= ST_EXTERNAL_FAILURE_QUALIFY;
                state <= ST_FAULT;
              end else begin
                external_rx_recovery_attempted <= 1;
                state <= ST_QUAD_RESTART_REQUEST;
              end
            end else begin
              counter <= counter + 1'b1;
            end
          end
        end

        ST_POST_LOCK_COUNTER_RESET: begin
          if (counter + 1 >= RESET_PULSE_CYCLES) begin
            counter <= 0;
            state <= ST_POST_LOCK_COUNTER_SETTLE;
          end else counter <= counter + 1'b1;
        end

        ST_POST_LOCK_COUNTER_SETTLE: begin
          // RXPRBSCNTRESET clears the native counter synchronously to the RX
          // path. Allow its error output and the registered lane-engine input
          // to drain for the fixed 1-ms observation interval before
          // measurement_enable can count a stale sample.
          if (counter + 1 >= ERROR_FREE_QUALIFY_CYCLES) begin
            counter <= 0;
            state <= ST_MEASURE;
          end else begin
            counter <= counter + 1'b1;
          end
        end

        ST_MEASURE: begin
          if (RUNTIME_INTEGRITY_DETECTOR && runtime_integrity_fault) begin
            // This is a data-integrity/platform-clock observation, not a
            // claim that native CDR lock or optical signal detect changed.
            fault_stage <= ST_RUNTIME_INTEGRITY_FAULT;
            state <= ST_FAULT;
          end else if (!(|running_sync)) begin
            state <= ST_CAPTURE_WAIT;
          end
        end

        ST_CAPTURE_WAIT: if (result_capture_request) begin
          // The generic engine requests exact counters only after all lane
          // snapshots have crossed into the management clock domain.
          drp_lane <= 0;
          state <= ST_DRP_LOW_START;
        end

        ST_DRP_LOW_START: begin
          if (!current_lane_selected) begin
            if (drp_lane == 3) state <= ST_CAPTURE_DONE;
            else drp_lane <= drp_lane + 1'b1;
          end else state <= ST_DRP_LOW_WAIT;
        end

        ST_DRP_LOW_WAIT: if (drprdy[drp_lane]) begin
          drp_low_word <= drpdo[drp_lane*16 +: 16];
          state <= ST_DRP_HIGH_START;
        end

        ST_DRP_HIGH_START: state <= ST_DRP_HIGH_WAIT;

        ST_DRP_HIGH_WAIT: if (drprdy[drp_lane]) begin
          exact_error_counts[drp_lane*32 +: 32] <=
            {drpdo[drp_lane*16 +: 16], drp_low_word};
          exact_error_valid[drp_lane] <= 1;
          exact_error_saturated[drp_lane] <=
            {drpdo[drp_lane*16 +: 16], drp_low_word} == 32'hffff_ffff;
          if (drp_lane == 3) state <= ST_CAPTURE_DONE;
          else begin
            drp_lane <= drp_lane + 1'b1;
            state <= ST_DRP_LOW_START;
          end
        end

        ST_CAPTURE_DONE: begin
          // Hold done until the request drops, forming a level handshake that
          // cannot be missed by either controller.
          result_capture_done <= 1;
          if (!result_capture_request) begin
            result_capture_done <= 0;
            counter <= 0;
            error_free_count <= 0;
            if (active_loopback == 3'b010) begin
              state <= ST_CLEAN_RESET_ASSERT;
            end else if (POST_CAPTURE_QUAD_RESTART) begin
              // RXPRBSSEL removal can leave Wizard RX-reset-done low
              // indefinitely. Reuse the coordinated restart after counters
              // have been safely captured and published.
              post_capture_restart <= 1;
              state <= ST_QUAD_RESTART_REQUEST;
            end else begin
              state <= POST_CAPTURE_RX_REQUAL
                ? ST_POST_CAPTURE_RX_REQUAL : ST_IDLE;
            end
          end
        end

        ST_POST_CAPTURE_RX_REQUAL: begin
          // Removing RXPRBSSEL after an external run can transiently deassert
          // the Wizard's RX reset-done status.  Keep the quad supervisor's
          // intentional-RX-change guard asserted through that propagation,
          // then require the synchronized status to be healthy before IDLE.
          // Hardware can launch the RX-status drop well after the control and
          // its two synchronizer stages have settled. Hold this guard for a
          // fixed 100 ms before accepting healthy status, then retain the
          // ordinary bounded timeout if the receiver does not recover.
          if (counter + 1 < POST_CAPTURE_SETTLE_CYCLES) begin
            counter <= counter + 1'b1;
          end else if (selected_rx_done && selected_pma_done) begin
            counter <= 0;
            // The Wizard aggregate can remain low after RXPRBSSEL removal
            // even when every primitive RXRESETDONE observed by the quad
            // supervisor and every selected PMA-done input is high.  It is
            // therefore diagnostic here, not a completion qualifier.
            // Status has requalified, but hardware can launch another delayed
            // cleanup transition after this state returns to IDLE. Retain the
            // intentional-change guard until the next command is accepted.
            post_cleanup_idle_guard <= RETAIN_POST_CLEANUP_IDLE_GUARD;
            state <= ST_IDLE;
          end else if (counter + 1 >= OPERATION_TIMEOUT_CYCLES) begin
            fault_stage <= ST_POST_CAPTURE_RX_REQUAL;
            state <= ST_FAULT;
          end else begin
            counter <= counter + 1'b1;
          end
        end

        ST_CLEAN_RESET_ASSERT: begin
          // Leaving PMA loopback through a reset returns the receiver to a
          // known external-path state for the next command.
          if (counter + 1 >= RESET_PULSE_CYCLES) begin
            counter <= 0;
            error_free_count <= 0;
            state <= ST_CLEAN_RESET_WAIT;
          end else counter <= counter + 1'b1;
        end

        ST_CLEAN_RESET_WAIT: begin
          // LOOPBACK/RXPRBSSEL removal and the Wizard reset request can cause
          // distinct delayed reset-done transitions. First require a low
          // acknowledgement from the Wizard and every selected lane. Then
          // require a complete, consecutive healthy-high settling interval;
          // any later low restarts that interval. Keep the ordinary counter
          // as an independent absolute timeout so repeated transitions cannot
          // hold the intentional-reset guard forever.
          if (counter + 1 >= OPERATION_TIMEOUT_CYCLES) begin
            fault_stage <= ST_CLEAN_RESET_WAIT;
            state <= ST_FAULT;
          end else if (cleanup_wizard_reset_seen &&
                       (&(cleanup_lane_reset_seen | ~selected_lanes)) &&
                       reset_done_sync && selected_rx_done &&
                       error_free_count + 1 >=
                         POST_CAPTURE_SETTLE_CYCLES) begin
            counter <= 0;
            error_free_count <= 0;
            post_cleanup_idle_guard <= RETAIN_POST_CLEANUP_IDLE_GUARD;
            state <= ST_IDLE;
          end else begin
            counter <= counter + 1'b1;
            if (cleanup_wizard_reset_seen &&
                (&(cleanup_lane_reset_seen | ~selected_lanes)) &&
                reset_done_sync && selected_rx_done)
              error_free_count <= error_free_count + 1'b1;
            else
              error_free_count <= 0;
          end
        end

        ST_FAULT: begin
          // Preserve fault_stage from the first failing operation. Without an
          // explicit hold state the default branch overwrites it with the
          // numeric value of ST_FAULT on every subsequent cycle.
          state <= ST_FAULT;
        end

        default: begin
          fault_stage <= state;
          state <= ST_FAULT;
        end
      endcase
    end
  end
endmodule
