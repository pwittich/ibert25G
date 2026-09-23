# Isolated direct-link builds do not import the full IBERT reference-clock XDCs.
# Preserve the deployed monitor mapping and declare the physical REFCLK0
# inputs so Vivado can derive the native GT user clocks.
create_clock -name gtrefclk0_2  -period 3.1030303 [get_ports p_lf_r0_ad]
create_clock -name gtrefclk0_4  -period 3.1030303 [get_ports p_lf_r0_af]
create_clock -name gtrefclk0_6  -period 3.1030303 [get_ports p_lf_r0_r]
create_clock -name gtrefclk0_9  -period 3.1030303 [get_ports p_lf_r0_u]
create_clock -name gtrefclk0_10 -period 3.1030303 [get_ports p_lf_r0_w]
create_clock -name gtrefclk0_13 -period 3.1030303 [get_ports p_lf_r0_y]
create_clock -name gtrefclk0_1  -period 3.1030303 [get_ports p_rt_r0_n]
create_clock -name gtrefclk0_3  -period 3.1030303 [get_ports p_rt_r0_p]
create_clock -name gtrefclk0_5  -period 3.1030303 [get_ports p_rt_r0_b]
create_clock -name gtrefclk0_7  -period 3.1030303 [get_ports p_rt_r0_e]
create_clock -name gtrefclk0_11 -period 3.1030303 [get_ports p_rt_r0_g]
create_clock -name gtrefclk0_12 -period 3.1030303 [get_ports p_rt_r0_i]
# Native-clock exceptions and descriptor bounds are applied by the pre-opt
# hook apply_direct_quad_v6_descriptor_cdc.tcl, not a blanket clock group.












# Remaining monitor-only reference inputs are independent clock domains.
# REFCLK1 is conservatively constrained at 322.265625 MHz (live ~320.6 MHz).
create_clock -name monitor_lf_r0_ab -period 3.103 [get_ports p_lf_r0_ab]
create_clock -name monitor_rt_r0_l -period 5.000 [get_ports p_rt_r0_l]
create_clock -name monitor_lf_r1_ab -period 3.103 [get_ports p_lf_r1_ab]
create_clock -name monitor_lf_r1_ad -period 3.103 [get_ports p_lf_r1_ad]
create_clock -name monitor_lf_r1_af -period 3.103 [get_ports p_lf_r1_af]
create_clock -name monitor_lf_r1_r -period 3.103 [get_ports p_lf_r1_r]
create_clock -name monitor_lf_r1_u -period 3.103 [get_ports p_lf_r1_u]
create_clock -name monitor_lf_r1_w -period 3.103 [get_ports p_lf_r1_w]
create_clock -name monitor_lf_r1_y -period 3.103 [get_ports p_lf_r1_y]
create_clock -name monitor_rt_r1_l -period 3.103 [get_ports p_rt_r1_l]
create_clock -name monitor_rt_r1_n -period 3.103 [get_ports p_rt_r1_n]
create_clock -name monitor_rt_r1_p -period 3.103 [get_ports p_rt_r1_p]
create_clock -name monitor_rt_r1_b -period 3.103 [get_ports p_rt_r1_b]
create_clock -name monitor_rt_r1_e -period 3.103 [get_ports p_rt_r1_e]
create_clock -name monitor_rt_r1_g -period 3.103 [get_ports p_rt_r1_g]
create_clock -name monitor_rt_r1_i -period 3.103 [get_ports p_rt_r1_i]
