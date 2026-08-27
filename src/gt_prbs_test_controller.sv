`timescale 1ns/1ps

// Quad-local sequencer for the device-specific PRBS acquisition and result
// capture operations that cannot safely be performed by the generic engine.
module gt_prbs_test_controller #(
  parameter int unsigned SETTLE_CYCLES = 32,
  parameter int unsigned RESET_PULSE_CYCLES = 16,
  parameter int unsigned OPERATION_TIMEOUT_CYCLES = 200_000_000
) (
  input  wire         mgmt_clk,
  input  wire         resetn,
  input  wire [3:0]   lane_running_async,
  input  wire [3:0]   rx_prbs_locked_async,
  input  wire [2:0]   requested_loopback,
  input  wire         result_capture_request,
  input  wire         gtwiz_reset_rx_done_async,
  input  wire [3:0]   rxresetdone_async,
  input  wire [3:0]   rxpmaresetdone_async,

  output logic [2:0]  applied_loopback,
  output logic        gtwiz_reset_rx_datapath,
  output logic [3:0]  rxpmareset,
  output logic [3:0]  sequenced_prbs_counter_reset,
  output logic        acquisition_ready,
  output logic        runtime_rx_reset_active,
  output logic        controller_idle,
  output logic        controller_fault,
  output wire [4:0]   diagnostic_state,

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
    ST_IDLE, ST_CONTROL_SETTLE, ST_RX_RESET_ASSERT, ST_RX_RESET_WAIT,
    ST_LOOPBACK_SETTLE, ST_PMA_RESET_ASSERT, ST_PMA_RESET_WAIT,
    ST_COUNTER_RESET, ST_LOCK_WAIT, ST_MEASURE, ST_CAPTURE_WAIT,
    ST_DRP_LOW_START, ST_DRP_LOW_WAIT, ST_DRP_HIGH_START,
    ST_DRP_HIGH_WAIT, ST_CAPTURE_DONE, ST_CLEAN_RESET_ASSERT,
    ST_CLEAN_RESET_WAIT, ST_FAULT
  } state_t;

  // The sequence has three distinct phases: prepare/reacquire the RX path,
  // expose a stable measurement window to the generic engine, and read the
  // native 32-bit GT error counters through DRP after measurement stops.
  state_t state = ST_IDLE;
  (* ASYNC_REG = "TRUE" *) logic [3:0] running_meta = 0, running_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic [3:0] locked_meta = 0, locked_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic reset_done_meta = 0, reset_done_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic [3:0] rxreset_meta = 0, rxreset_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic [3:0] pma_done_meta = 0, pma_done_sync = 0;
  logic [3:0] selected_lanes = 0;
  logic [2:0] active_loopback = 0;
  logic [31:0] counter = 0;
  logic [1:0] drp_lane = 0;
  logic [15:0] drp_low_word = 0;
  logic [4:0] fault_stage = 0;

  wire selected_locked = (locked_sync & selected_lanes) == selected_lanes;
  wire selected_rx_done = (rxreset_sync & selected_lanes) == selected_lanes;
  wire selected_pma_done = (pma_done_sync & selected_lanes) == selected_lanes;
  wire current_lane_selected = selected_lanes[drp_lane];

  assign drpclk = {4{mgmt_clk}};
  assign diagnostic_state = controller_fault ? fault_stage : state;

  always_comb begin
    // Only near-end PMA loopback (010) needs the disruptive RX reset/PMA reset
    // sequence.  External-path tests leave LOOPBACK at 000 and proceed from
    // control settling directly to counter reset and lock qualification.
    applied_loopback = (state == ST_LOOPBACK_SETTLE ||
                        state == ST_PMA_RESET_ASSERT ||
                        state == ST_PMA_RESET_WAIT ||
                        state == ST_COUNTER_RESET || state == ST_LOCK_WAIT ||
                        state == ST_MEASURE || state == ST_CAPTURE_WAIT ||
                        state == ST_DRP_LOW_START || state == ST_DRP_LOW_WAIT ||
                        state == ST_DRP_HIGH_START || state == ST_DRP_HIGH_WAIT ||
                        state == ST_CAPTURE_DONE) ? active_loopback : 3'b000;
    gtwiz_reset_rx_datapath = (state == ST_RX_RESET_ASSERT ||
                                state == ST_CLEAN_RESET_ASSERT);
    rxpmareset = (state == ST_PMA_RESET_ASSERT) ? selected_lanes : 4'b0000;
    sequenced_prbs_counter_reset =
      (state == ST_COUNTER_RESET) ? selected_lanes : 4'b0000;
    acquisition_ready = state == ST_MEASURE;
    // The quad supervisor must tolerate RX status deasserting throughout an
    // intentional PMA-loopback reset and reacquisition, not just while the
    // datapath reset pin itself is asserted.  Drop the qualification only
    // after every selected lane has reacquired PRBS lock in ST_LOCK_WAIT.
    runtime_rx_reset_active = (state == ST_RX_RESET_ASSERT ||
                               state == ST_RX_RESET_WAIT ||
                               state == ST_LOOPBACK_SETTLE ||
                               state == ST_PMA_RESET_ASSERT ||
                               state == ST_PMA_RESET_WAIT ||
                               (active_loopback == 3'b010 &&
                                (state == ST_COUNTER_RESET ||
                                 state == ST_LOCK_WAIT)) ||
                               state == ST_CLEAN_RESET_ASSERT ||
                               state == ST_CLEAN_RESET_WAIT);
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
    end else begin
      case (state)
        ST_IDLE: begin
          // lane_running is asserted only after the generic engine has latched
          // a valid descriptor.  Snapshot the participating physical lanes and
          // loopback choice for the complete operation.
          result_capture_done <= 0;
          counter <= 0;
          if (|running_sync) begin
            selected_lanes <= running_sync;
            active_loopback <= requested_loopback;
            exact_error_counts <= 0;
            exact_error_valid <= 0;
            exact_error_saturated <= 0;
            state <= ST_CONTROL_SETTLE;
          end
        end

        ST_CONTROL_SETTLE: begin
          if (counter + 1 >= SETTLE_CYCLES) begin
            counter <= 0;
            state <= active_loopback == 3'b010
              ? ST_RX_RESET_ASSERT : ST_COUNTER_RESET;
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
            state <= ST_LOOPBACK_SETTLE;
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
            state <= ST_COUNTER_RESET;
          end else if (counter + 1 >= OPERATION_TIMEOUT_CYCLES) begin
            fault_stage <= ST_PMA_RESET_WAIT;
            state <= ST_FAULT;
          end else counter <= counter + 1'b1;
        end

        ST_COUNTER_RESET: begin
          if (counter + 1 >= RESET_PULSE_CYCLES) begin
            counter <= 0;
            state <= ST_LOCK_WAIT;
          end else counter <= counter + 1'b1;
        end

        ST_LOCK_WAIT: begin
          // Measurement cannot begin until every selected lane is locked; this
          // prevents reset/reacquisition time from contaminating tested bits.
          if (selected_locked) begin
            counter <= 0;
            state <= ST_MEASURE;
          end else if (counter + 1 >= OPERATION_TIMEOUT_CYCLES) begin
            fault_stage <= ST_LOCK_WAIT;
            state <= ST_FAULT;
          end else counter <= counter + 1'b1;
        end

        ST_MEASURE: if (!(|running_sync)) state <= ST_CAPTURE_WAIT;

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
            state <= active_loopback == 3'b010
              ? ST_CLEAN_RESET_ASSERT : ST_IDLE;
          end
        end

        ST_CLEAN_RESET_ASSERT: begin
          // Leaving PMA loopback through a reset returns the receiver to a
          // known external-path state for the next command.
          if (counter + 1 >= RESET_PULSE_CYCLES) begin
            counter <= 0;
            state <= ST_CLEAN_RESET_WAIT;
          end else counter <= counter + 1'b1;
        end

        ST_CLEAN_RESET_WAIT: begin
          if (reset_done_sync && selected_rx_done) state <= ST_IDLE;
          else if (counter + 1 >= OPERATION_TIMEOUT_CYCLES) begin
            fault_stage <= ST_CLEAN_RESET_WAIT;
            state <= ST_FAULT;
          end else counter <= counter + 1'b1;
        end

        default: begin
          fault_stage <= state;
          state <= ST_FAULT;
        end
      endcase
    end
  end
endmodule
