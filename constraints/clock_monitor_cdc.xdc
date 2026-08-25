# Gray counters cross into clk_200 only through the first ASYNC_REG stage.
set_false_path -to [get_pins -hier -filter {
  NAME =~ *u_clock_monitor*g_clock_counter*gray_sync1_reg*/D}]
