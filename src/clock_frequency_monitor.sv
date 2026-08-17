module clock_frequency_monitor #(
  parameter int N_CLOCKS = 37,
  parameter int REF_HZ = 200_000_000,
  parameter int WINDOW_CYCLES = REF_HZ / 1000,
  parameter logic [N_CLOCKS-1:0] SCALE_X2 = '0
) (
  input  wire ref_clk,
  input  wire [N_CLOCKS-1:0] monitored_clk,
  output logic [31:0] frequency_khz [0:N_CLOCKS-1],
  output logic measurement_valid
);
  logic [31:0] async_binary [0:N_CLOCKS-1];
  logic [31:0] async_gray [0:N_CLOCKS-1];
  (* ASYNC_REG = "TRUE" *) logic [31:0] gray_sync1 [0:N_CLOCKS-1];
  (* ASYNC_REG = "TRUE" *) logic [31:0] gray_sync2 [0:N_CLOCKS-1];
  logic [31:0] sampled_binary [0:N_CLOCKS-1];
  logic [31:0] previous_binary [0:N_CLOCKS-1];
  logic [31:0] window_counter = 0;
  localparam int KHZ_PER_COUNT = REF_HZ / (WINDOW_CYCLES * 1000);

  function automatic logic [31:0] gray_to_binary(input logic [31:0] gray);
    logic [31:0] value;
    value[31] = gray[31];
    for (int b = 30; b >= 0; b--) value[b] = value[b+1] ^ gray[b];
    return value;
  endfunction

  for (genvar n = 0; n < N_CLOCKS; n++) begin : g_clock_counter
    initial begin
      async_binary[n] = 0;
      async_gray[n] = 0;
      gray_sync1[n] = 0;
      gray_sync2[n] = 0;
      sampled_binary[n] = 0;
      previous_binary[n] = 0;
      frequency_khz[n] = 0;
    end
    always_ff @(posedge monitored_clk[n]) begin
      async_binary[n] <= async_binary[n] + 1'b1;
      async_gray[n] <= (async_binary[n] + 1'b1) ^ ((async_binary[n] + 1'b1) >> 1);
    end
    always_ff @(posedge ref_clk) begin
      gray_sync1[n] <= async_gray[n];
      gray_sync2[n] <= gray_sync1[n];
      sampled_binary[n] <= gray_to_binary(gray_sync2[n]);
    end
  end

  initial measurement_valid = 1'b0;
  always_ff @(posedge ref_clk) begin
    if (window_counter == WINDOW_CYCLES-1) begin
      window_counter <= 0;
      measurement_valid <= 1'b1;
      for (int n = 0; n < N_CLOCKS; n++) begin
        // Default window is 1 ms, so delta reports kHz.
        if (SCALE_X2[n])
          frequency_khz[n] <= (sampled_binary[n] - previous_binary[n]) * (2 * KHZ_PER_COUNT);
        else
          frequency_khz[n] <= (sampled_binary[n] - previous_binary[n]) * KHZ_PER_COUNT;
        previous_binary[n] <= sampled_binary[n];
      end
      // The reference cannot independently measure itself.
      frequency_khz[0] <= REF_HZ / 1000;
    end else begin
      window_counter <= window_counter + 1'b1;
    end
  end
endmodule
