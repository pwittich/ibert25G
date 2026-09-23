# Full Milestone 3 v13 left-side REFCLK constraints. This is the checked-in
# IBERT timing structure with only the managed quad-124 blanket exception
# omitted; apply_descriptor_cdc.tcl installs endpoint-specific exceptions and
# a 3.000-ns datapath bound for its 16 descriptor capture pins.

set_property C_CLK_INPUT_FREQ_HZ 50000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk \
  [get_nets -of_objects [get_pins u_ibert_debug_clk_bufg/O]]

create_clock -name gtrefclk0_2 -period 3.1030303 [get_ports p_lf_r0_ad]
set_clock_groups -group [get_clocks gtrefclk0_2 -include_generated_clocks] -asynchronous
create_clock -name gtrefclk0_4 -period 3.1030303 [get_ports p_lf_r0_af]
# No blanket gtrefclk0_4 group: descriptor CDC is constrained by the v13 hook.
create_clock -name gtrefclk0_6 -period 3.1030303 [get_ports p_lf_r0_r]
set_clock_groups -group [get_clocks gtrefclk0_6 -include_generated_clocks] -asynchronous
create_clock -name gtrefclk0_9 -period 3.1030303 [get_ports p_lf_r0_u]
set_clock_groups -group [get_clocks gtrefclk0_9 -include_generated_clocks] -asynchronous
create_clock -name gtrefclk0_10 -period 3.1030303 [get_ports p_lf_r0_w]
set_clock_groups -group [get_clocks gtrefclk0_10 -include_generated_clocks] -asynchronous
create_clock -name gtrefclk0_13 -period 3.1030303 [get_ports p_lf_r0_y]
set_clock_groups -group [get_clocks gtrefclk0_13 -include_generated_clocks] -asynchronous
