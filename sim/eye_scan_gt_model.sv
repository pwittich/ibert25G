`timescale 1ns/1ps

// Behavioral GTYE4 DRP model, not an analog receiver or vendor GT model.
// Constants are independently enumerated from UG578 Appendix C. Simulates
// delayed completion, initial WAIT/DONE, COUNT/END, UT-specific counters,
// writes that take effect before a lost reply, and bad readbacks.
module eye_scan_gt_model (
  input wire clk, resetn,
  input wire [39:0] addr,
  input wire [63:0] di,
  input wire [3:0] en, we,
  output logic [63:0] dout = 0,
  output logic [3:0] rdy = 0,
  input wire [15:0] initial_control,
  input wire hold_wait, hold_count, hold_stop, fast_end, initial_end, zero_samples,
  input wire bad_config, bad_restore, stall,
  input wire [1:0] expected_lane,
  input wire signed [10:0] expected_horizontal,
  input wire signed [8:0] expected_vertical,
  input wire [4:0] expected_prescale
);
  logic [15:0] mem [0:3][0:1023];
  logic active [0:3];
  integer polls [0:3];
  integer starts = 0, writes = 0, requests = 0;
  logic pending = 0;
  logic [1:0] pending_lane = 0;
  logic [9:0] pending_addr = 0;
  logic [15:0] pending_data = 0;
  logic pending_we = 0;
  integer delay_left = 0;

  function automatic [15:0] original(input integer l, a);
    if (a == 'h03c) original = initial_control;
    else original = 16'ha000 ^ (l << 10) ^ a;
  endfunction
  function automatic bit writable(input integer a);
    writable = a == 'h03c || a == 'h04f || a == 'h097 ||
      (a >= 'h044 && a <= 'h04d) || (a >= 'h0ec && a <= 'h0f5);
  endfunction
  function automatic [3:0] status_word(input integer l);
    if (!active[l]) status_word = initial_end && starts == 0 ? 4'h5 :
      (hold_stop && starts > 0 ? 4'h6 : 4'h1);
    else if (hold_wait) status_word = 4'h1;
    else if (hold_count) status_word = 4'h6;
    else if (fast_end || polls[l] >= 4) status_word = 4'h5;
    else if (polls[l] < 2) status_word = 4'h1;
    else status_word = 4'h6;
  endfunction
  function automatic [15:0] read_word(input integer l, a);
    if (a == 'h253) read_word = {12'd0, status_word(l)};
    else if (a == 'h251) read_word = mem[l]['h097][9] ? 16'd9 : 16'd3;
    else if (a == 'h252) read_word = zero_samples ? 16'd0 :
      (mem[l]['h097][9] ? 16'h2345 : 16'h1234);
    else if (a == 'h044 && bad_config && mem[l][a] == 16'hffff)
      read_word = mem[l][a] ^ 16'h1;
    else if (a == 'h044 && bad_restore && writes > 0 && mem[l][a] == original(l,a))
      read_word = mem[l][a] ^ 16'h1;
    else read_word = mem[l][a];
  endfunction

  always @(posedge clk) begin : model
    integer l, a;
    logic [15:0] value;
    if (!resetn) begin
      for (l=0; l<4; l++) begin
        active[l] = 0; polls[l] = 0;
        for (a=0; a<1024; a++) mem[l][a] = original(l,a);
      end
      starts = 0; writes = 0; requests = 0;
      pending <= 0; rdy <= 0; dout <= 0; delay_left <= 0;
    end else begin
      rdy <= 0;
      if (|en) begin
        if (pending || rdy != 0) $fatal(1, "DRP issued before previous completion drained");
        if (en != (4'b1 << expected_lane)) $fatal(1, "DRP accessed unselected lane");
        l = expected_lane; a = addr[l*10 +: 10]; value = di[l*16 +: 16];
        requests = requests + 1;
        pending <= 1; pending_lane <= l; pending_addr <= a;
        pending_data <= value; pending_we <= we[l];
        delay_left <= 2 + (requests % 4);
        if (we[l]) begin
          if (!writable(a)) $fatal(1, "scanner wrote non-eye address %h", a);
          if (a == 'h04f && value[3:0] != mem[l][a][3:0])
            $fatal(1, "horizontal write clobbered shared fields");
          if (a == 'h097 && (value & 16'hf803) != (mem[l][a] & 16'hf803))
            $fatal(1, "vertical write clobbered shared fields/range");
          if (a == 'h03c) begin
            if ((value & 16'h00e0) != (initial_control & 16'h00e0) || !value[8] ||
                (value[15:10] != 0 && value[15:10] != 1))
              $fatal(1, "unsafe eye control write");
            if (value[10]) begin
              if (!value[9] || active[l]) $fatal(1, "invalid/repeated RUN");
              for (integer j='h044; j<='h048; j++)
                if (mem[l][j] != 16'hffff) $fatal(1, "lower qualifier mask incorrect");
              for (integer j='h0ec; j<='h0f0; j++)
                if (mem[l][j] != 16'hffff) $fatal(1, "upper qualifier mask incorrect");
              for (integer j='h049; j<='h04d; j++)
                if (mem[l][j] != 0) $fatal(1, "current data must be unmasked at width80");
              for (integer j='h0f1; j<='h0f5; j++)
                if (mem[l][j] != 16'hffff) $fatal(1, "previous data double counted");
              if (!mem[l]['h04f][15]) $fatal(1, "phase unification not set");
              if ($signed(mem[l]['h04f][14:4]) != expected_horizontal ||
                  mem[l]['h097][10] != (expected_vertical < 0) ||
                  mem[l]['h097][8:2] != (expected_vertical < 0 ? -expected_vertical : expected_vertical) ||
                  value[4:0] != expected_prescale)
                $fatal(1, "offset or prescale encoding incorrect");
              starts = starts + 1; polls[l] = 0; active[l] = 1;
            end else active[l] = 0;
          end else if (active[l]) $fatal(1, "scan registers changed while RUN");
          mem[l][a] = value;
          writes = writes + 1;
        end else begin
          if ((a == 'h251 || a == 'h252) && status_word(l) != 5)
            $fatal(1, "counter read accepted stale DONE before END");
        end
      end
      if (pending && !stall) begin
        if (addr[pending_lane*10 +: 10] != pending_addr ||
            di[pending_lane*16 +: 16] != pending_data || we[pending_lane] != pending_we)
          $fatal(1, "DRP bundle changed before completion");
        if (delay_left == 0) begin
          dout[pending_lane*16 +: 16] <= read_word(pending_lane,pending_addr);
          rdy <= 4'b1 << pending_lane; pending <= 0;
          if (!pending_we && pending_addr == 'h253 && active[pending_lane])
            polls[pending_lane] = polls[pending_lane] + 1;
        end else delay_left <= delay_left - 1;
      end
    end
  end
endmodule
