`timescale 1ns/1ps

// Measurement-time data-integrity monitor.  This block deliberately reports
// observed PRBS corruption and loss of the shared RXUSRCLK2 heartbeat; neither
// condition is labelled as optical LOS or CDR loss.
module gt_runtime_integrity_monitor #(
  parameter int unsigned ERROR_ASSERT_CYCLES = 20_000_000,
  parameter int unsigned ERROR_CLEAR_CYCLES = 200_000,
  parameter int unsigned HEARTBEAT_TIMEOUT_CYCLES = 20_000_000,
  parameter int unsigned HEARTBEAT_RECOVERY_EDGES = 4
) (
  input  wire        mgmt_clk,
  input  wire        resetn,
  input  wire        monitor_enable,
  input  wire [3:0]  selected_lanes,
  input  wire [3:0]  rx_prbs_error_async,
  input  wire        rx_clock_heartbeat_async,
  output wire        integrity_fault,
  output logic [3:0] error_fault_lanes,
  output logic       clock_fault,
  output logic [31:0] event_count,
  output logic [3:0] retained_error_lanes,
  output logic       retained_clock_fault,
  output wire [31:0] diagnostic_state
);
  (* ASYNC_REG = "TRUE" *) logic [3:0] error_meta = 0, error_sync = 0;
  (* ASYNC_REG = "TRUE" *) logic heartbeat_meta = 0, heartbeat_sync = 0;
  logic heartbeat_seen = 0;
  logic [31:0] heartbeat_timeout_count = 0;
  logic [31:0] heartbeat_recovery_count = 0;
  logic [31:0] error_assert_count [0:3];
  logic [31:0] error_clear_count [0:3];
  logic heartbeat_edge;
  logic [3:0] new_error_events;
  logic new_clock_event;

  assign heartbeat_edge = heartbeat_sync != heartbeat_seen;
  assign integrity_fault = |error_fault_lanes || clock_fault;
  assign diagnostic_state = {
    12'd0, monitor_enable, selected_lanes, retained_clock_fault,
    retained_error_lanes, clock_fault, error_fault_lanes, integrity_fault
  };

  always_comb begin
    new_error_events = 0;
    for (int lane = 0; lane < 4; lane++) begin
      if (monitor_enable && selected_lanes[lane] && error_sync[lane] &&
          !error_fault_lanes[lane] &&
          error_assert_count[lane] + 1 >= ERROR_ASSERT_CYCLES)
        new_error_events[lane] = 1'b1;
    end
    new_clock_event = monitor_enable && !heartbeat_edge && !clock_fault &&
      heartbeat_timeout_count + 1 >= HEARTBEAT_TIMEOUT_CYCLES;
  end

  always_ff @(posedge mgmt_clk) begin
    error_meta <= rx_prbs_error_async;
    error_sync <= error_meta;
    heartbeat_meta <= rx_clock_heartbeat_async;
    heartbeat_sync <= heartbeat_meta;

    if (!resetn) begin
      heartbeat_seen <= 0;
      heartbeat_timeout_count <= 0;
      heartbeat_recovery_count <= 0;
      error_fault_lanes <= 0;
      clock_fault <= 0;
      event_count <= 0;
      retained_error_lanes <= 0;
      retained_clock_fault <= 0;
      for (int lane = 0; lane < 4; lane++) begin
        error_assert_count[lane] <= 0;
        error_clear_count[lane] <= 0;
      end
    end else begin
      if (|(new_error_events) || new_clock_event) begin
        if (!(&event_count)) event_count <= event_count + 1'b1;
        retained_error_lanes <= retained_error_lanes | new_error_events;
        retained_clock_fault <= retained_clock_fault | new_clock_event;
      end

      if (!monitor_enable) begin
        heartbeat_seen <= heartbeat_sync;
        heartbeat_timeout_count <= 0;
        heartbeat_recovery_count <= 0;
        error_fault_lanes <= 0;
        clock_fault <= 0;
        for (int lane = 0; lane < 4; lane++) begin
          error_assert_count[lane] <= 0;
          error_clear_count[lane] <= 0;
        end
      end else begin
        if (heartbeat_edge) begin
          heartbeat_seen <= heartbeat_sync;
          heartbeat_timeout_count <= 0;
          if (clock_fault) begin
            if (heartbeat_recovery_count + 1 >= HEARTBEAT_RECOVERY_EDGES) begin
              heartbeat_recovery_count <= 0;
              clock_fault <= 0;
            end else heartbeat_recovery_count <=
              heartbeat_recovery_count + 1'b1;
          end else heartbeat_recovery_count <= 0;
        end else begin
          if (!clock_fault) begin
            if (heartbeat_timeout_count + 1 >= HEARTBEAT_TIMEOUT_CYCLES) begin
              heartbeat_timeout_count <= heartbeat_timeout_count;
              clock_fault <= 1;
            end else heartbeat_timeout_count <= heartbeat_timeout_count + 1'b1;
          end
        end

        for (int lane = 0; lane < 4; lane++) begin
          if (!selected_lanes[lane]) begin
            error_assert_count[lane] <= 0;
            error_clear_count[lane] <= 0;
            error_fault_lanes[lane] <= 0;
          end else if (error_sync[lane]) begin
            error_clear_count[lane] <= 0;
            if (!error_fault_lanes[lane]) begin
              if (error_assert_count[lane] + 1 >= ERROR_ASSERT_CYCLES) begin
                error_assert_count[lane] <= error_assert_count[lane];
                error_fault_lanes[lane] <= 1;
              end else error_assert_count[lane] <=
                error_assert_count[lane] + 1'b1;
            end
          end else begin
            error_assert_count[lane] <= 0;
            if (error_fault_lanes[lane]) begin
              if (error_clear_count[lane] + 1 >= ERROR_CLEAR_CYCLES) begin
                error_clear_count[lane] <= 0;
                error_fault_lanes[lane] <= 0;
              end else error_clear_count[lane] <=
                error_clear_count[lane] + 1'b1;
            end else error_clear_count[lane] <= 0;
          end
        end
      end
    end
  end
endmodule
