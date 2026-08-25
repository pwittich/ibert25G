module i2c_register_slave #(
  parameter logic [6:0] I2C_ADDRESS = 7'h2b
) (
  input  wire clk,
  inout  wire scl,
  inout  wire sda,
  output logic [7:0] register_address,
  input  wire [7:0] read_data,
  input  wire [7:0] read_data_next,
  output logic write_enable,
  output logic [7:0] write_data
);
  typedef enum logic [3:0] {
    IDLE, RX_ADDRESS, ACK_ADDRESS, RX_REGISTER, ACK_REGISTER,
    RX_DATA, ACK_DATA, TX_DATA, TX_ACK
  } state_t;
  state_t state = IDLE;
  logic [2:0] scl_sync = 3'b111, sda_sync = 3'b111;
  logic [7:0] shift = 0, tx_byte = 0;
  logic [2:0] bit_count = 0;
  logic ack_started = 0, address_match = 0, read_transfer = 0;
  logic master_ack = 0, sda_drive_low = 0;
  wire scl_rise = (scl_sync[2:1] == 2'b01);
  wire scl_fall = (scl_sync[2:1] == 2'b10);
  wire start_condition = scl_sync[2] && (sda_sync[2:1] == 2'b10);
  wire stop_condition  = scl_sync[2] && (sda_sync[2:1] == 2'b01);
  wire rx_sda = sda_sync[2];

  assign sda = sda_drive_low ? 1'b0 : 1'bz;
  assign scl = 1'bz;

  always_ff @(posedge clk) begin
    scl_sync <= {scl_sync[1:0], scl};
    sda_sync <= {sda_sync[1:0], sda};
    write_enable <= 1'b0;

    if (start_condition) begin
      state <= RX_ADDRESS;
      bit_count <= 0;
      sda_drive_low <= 1'b0;
      ack_started <= 1'b0;
    end else if (stop_condition) begin
      state <= IDLE;
      sda_drive_low <= 1'b0;
    end else case (state)
      IDLE: sda_drive_low <= 1'b0;

      RX_ADDRESS: if (scl_rise) begin
        shift <= {shift[6:0], rx_sda};
        if (bit_count == 7) begin
          address_match <= (shift[6:0] == I2C_ADDRESS);
          read_transfer <= rx_sda;
          bit_count <= 0;
          ack_started <= 0;
          state <= ACK_ADDRESS;
        end else bit_count <= bit_count + 1'b1;
      end

      ACK_ADDRESS: if (scl_fall) begin
        if (!ack_started) begin
          sda_drive_low <= address_match;
          ack_started <= 1'b1;
        end else begin
          sda_drive_low <= 1'b0;
          ack_started <= 1'b0;
          if (!address_match) state <= IDLE;
          else if (read_transfer) begin
            tx_byte <= read_data;
            bit_count <= 7;
            sda_drive_low <= ~read_data[7];
            state <= TX_DATA;
          end else state <= RX_REGISTER;
        end
      end

      RX_REGISTER: if (scl_rise) begin
        shift <= {shift[6:0], rx_sda};
        if (bit_count == 7) begin
          register_address <= {shift[6:0], rx_sda};
          bit_count <= 0; ack_started <= 0; state <= ACK_REGISTER;
        end else bit_count <= bit_count + 1'b1;
      end

      ACK_REGISTER: if (scl_fall) begin
        if (!ack_started) begin sda_drive_low <= 1'b1; ack_started <= 1'b1; end
        else begin sda_drive_low <= 1'b0; ack_started <= 0; state <= RX_DATA; end
      end

      RX_DATA: if (scl_rise) begin
        shift <= {shift[6:0], rx_sda};
        if (bit_count == 7) begin
          write_data <= {shift[6:0], rx_sda};
          write_enable <= 1'b1;
          bit_count <= 0; ack_started <= 0; state <= ACK_DATA;
        end else bit_count <= bit_count + 1'b1;
      end

      ACK_DATA: if (scl_fall) begin
        if (!ack_started) begin sda_drive_low <= 1'b1; ack_started <= 1'b1; end
        else begin
          sda_drive_low <= 1'b0; ack_started <= 0;
          register_address <= register_address + 1'b1;
          state <= RX_DATA;
        end
      end

      TX_DATA: if (scl_fall) begin
        if (bit_count == 0) begin
          sda_drive_low <= 1'b0;
          state <= TX_ACK;
        end else begin
          bit_count <= bit_count - 1'b1;
          sda_drive_low <= ~tx_byte[bit_count-1];
        end
      end

      TX_ACK: begin
        if (scl_rise) master_ack <= ~rx_sda;
        if (scl_fall) begin
          if (master_ack) begin
            register_address <= register_address + 1'b1;
            tx_byte <= read_data_next;
            bit_count <= 7;
            sda_drive_low <= ~read_data_next[7];
            state <= TX_DATA;
          end else begin state <= IDLE; sda_drive_low <= 1'b0; end
        end
      end
      default: state <= IDLE;
    endcase
  end
endmodule
