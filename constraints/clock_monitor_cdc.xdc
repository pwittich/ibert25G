# Gray counters cross into clk_200 only through the first ASYNC_REG stage.
# The guarded query keeps the source-level project usable before synthesis.
set clock_monitor_sync_d [get_pins -quiet -hier -filter {
  NAME =~ *u_clock_monitor*g_clock_counter*gray_sync1_reg*/D}]
if {[llength $clock_monitor_sync_d] > 0} {
  set_false_path -to $clock_monitor_sync_d
}

