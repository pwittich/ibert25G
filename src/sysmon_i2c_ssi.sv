module sysmon_i2c_ssi #(
  // Seven-bit I2C addresses. Change these four constants if required.
  // For SYSMONE4 I2C (not PMBus), address bit 2 must remain zero.
  parameter logic [6:0] SLR0_I2C_ADDR = 7'h30,
  parameter logic [6:0] SLR1_I2C_ADDR = 7'h31, // VU13P master SLR
  parameter logic [6:0] SLR2_I2C_ADDR = 7'h32,
  parameter logic [6:0] SLR3_I2C_ADDR = 7'h33
) (
  input  logic dclk,
  inout  wire  i2c_scl,
  inout  wire  i2c_sda
);
  logic i2c_scl_in, i2c_sda_in;
  logic [3:0] scl_ts, sda_ts;

  // SYSMONE4 TS outputs are active-high three-state controls. Any monitor
  // can pull either open-drain bus signal low.
  IOBUF u_i2c_scl_iobuf (
    .I(1'b0), .T(&scl_ts), .O(i2c_scl_in), .IO(i2c_scl)
  );
  IOBUF u_i2c_sda_iobuf (
    .I(1'b0), .T(&sda_ts), .O(i2c_sda_in), .IO(i2c_sda)
  );

  // Config register 43h: I2C_OR=1, I2C_A[6:0], I2C_EN=1.
  localparam logic [15:0] INIT43_SLR0 = 16'h8080 | ({9'b0, SLR0_I2C_ADDR} << 8);
  localparam logic [15:0] INIT43_SLR1 = 16'h8080 | ({9'b0, SLR1_I2C_ADDR} << 8);
  localparam logic [15:0] INIT43_SLR2 = 16'h8080 | ({9'b0, SLR2_I2C_ADDR} << 8);
  localparam logic [15:0] INIT43_SLR3 = 16'h8080 | ({9'b0, SLR3_I2C_ADDR} << 8);

  initial begin
    if (SLR0_I2C_ADDR[2] || SLR1_I2C_ADDR[2] ||
        SLR2_I2C_ADDR[2] || SLR3_I2C_ADDR[2])
      $error("SYSMONE4 I2C address bit 2 must be zero; one address selects PMBus");
    if ((SLR0_I2C_ADDR == SLR1_I2C_ADDR) || (SLR0_I2C_ADDR == SLR2_I2C_ADDR) ||
        (SLR0_I2C_ADDR == SLR3_I2C_ADDR) || (SLR1_I2C_ADDR == SLR2_I2C_ADDR) ||
        (SLR1_I2C_ADDR == SLR3_I2C_ADDR) || (SLR2_I2C_ADDR == SLR3_I2C_ADDR))
      $error("SYSMONE4 I2C addresses must be unique");
  end

  `define SYSMON_INSTANCE(NAME, INIT43, IDX) \
    SYSMONE4 #(.INIT_43(INIT43), .SIM_DEVICE("ULTRASCALE_PLUS")) NAME ( \
      .I2C_SCLK(i2c_scl_in), .I2C_SDA(i2c_sda_in), \
      .I2C_SCLK_TS(scl_ts[IDX]), .I2C_SDA_TS(sda_ts[IDX]), \
      .DCLK(dclk), .DADDR(8'h00), .DEN(1'b0), .DI(16'h0000), .DWE(1'b0), \
      .RESET(1'b0), .CONVST(1'b0), .CONVSTCLK(1'b0), \
      .VAUXP(16'h0000), .VAUXN(16'h0000), .VP(1'b0), .VN(1'b0), \
      .ALM(), .OT(), .ADC_DATA(), .DO(), .DRDY(), .SMBALERT_TS(), \
      .BUSY(), .CHANNEL(), .EOC(), .EOS(), .JTAGBUSY(), \
      .JTAGLOCKED(), .JTAGMODIFIED(), .MUXADDR() \
    );

  `SYSMON_INSTANCE(u_sysmon_slr0, INIT43_SLR0, 0)
  `SYSMON_INSTANCE(u_sysmon_slr1, INIT43_SLR1, 1)
  `SYSMON_INSTANCE(u_sysmon_slr2, INIT43_SLR2, 2)
  `SYSMON_INSTANCE(u_sysmon_slr3, INIT43_SLR3, 3)
  `undef SYSMON_INSTANCE
endmodule
