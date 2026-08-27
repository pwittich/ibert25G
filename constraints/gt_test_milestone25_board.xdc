# Isolated quad-124 board subset.  No other GT transmitter is constrained or
# enabled in this target.
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLNONE [current_design]
set_property BITSTREAM.CONFIG.OVERTEMPSHUTDOWN ENABLE [current_design]

set_property PACKAGE_PIN AY39 [get_ports p_lf_r0_ad]
set_property PACKAGE_PIN AY40 [get_ports n_lf_r0_ad]
set_property PACKAGE_PIN AM39 [get_ports p_lf_r0_r]
set_property PACKAGE_PIN AM40 [get_ports n_lf_r0_r]
set_property PACKAGE_PIN AA41 [get_ports p_lf_r0_u]
set_property PACKAGE_PIN AA42 [get_ports n_lf_r0_u]
set_property PACKAGE_PIN N41  [get_ports p_lf_r0_y]
set_property PACKAGE_PIN N42  [get_ports n_lf_r0_y]
set_property PACKAGE_PIN AT39 [get_ports p_lf_r0_af]
set_property PACKAGE_PIN AT40 [get_ports n_lf_r0_af]
set_property PACKAGE_PIN U41  [get_ports p_lf_r0_w]
set_property PACKAGE_PIN U42  [get_ports n_lf_r0_w]
set_property PACKAGE_PIN AY13 [get_ports p_rt_r0_n]
set_property PACKAGE_PIN AY12 [get_ports n_rt_r0_n]
set_property PACKAGE_PIN AM13 [get_ports p_rt_r0_b]
set_property PACKAGE_PIN AM12 [get_ports n_rt_r0_b]
set_property PACKAGE_PIN AA11 [get_ports p_rt_r0_e]
set_property PACKAGE_PIN AA10 [get_ports n_rt_r0_e]
set_property PACKAGE_PIN U11  [get_ports p_rt_r0_g]
set_property PACKAGE_PIN U10  [get_ports n_rt_r0_g]
set_property PACKAGE_PIN AT13 [get_ports p_rt_r0_p]
set_property PACKAGE_PIN AT12 [get_ports n_rt_r0_p]
set_property PACKAGE_PIN N11  [get_ports p_rt_r0_i]
set_property PACKAGE_PIN N10  [get_ports n_rt_r0_i]

# The isolated target still consumes every REFCLK0 through the deployed clock
# monitor map.  Declare all twelve primary clocks here because the full IBERT
# timing XDCs are intentionally excluded from this target. XDC forbids Tcl
# loops, so keep these declarations explicit.
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

set_clock_groups -group [get_clocks gtrefclk0_2  -include_generated_clocks] -asynchronous
set_clock_groups -group [get_clocks gtrefclk0_4  -include_generated_clocks] -asynchronous
set_clock_groups -group [get_clocks gtrefclk0_6  -include_generated_clocks] -asynchronous
set_clock_groups -group [get_clocks gtrefclk0_9  -include_generated_clocks] -asynchronous
set_clock_groups -group [get_clocks gtrefclk0_10 -include_generated_clocks] -asynchronous
set_clock_groups -group [get_clocks gtrefclk0_13 -include_generated_clocks] -asynchronous
set_clock_groups -group [get_clocks gtrefclk0_1  -include_generated_clocks] -asynchronous
set_clock_groups -group [get_clocks gtrefclk0_3  -include_generated_clocks] -asynchronous
set_clock_groups -group [get_clocks gtrefclk0_5  -include_generated_clocks] -asynchronous
set_clock_groups -group [get_clocks gtrefclk0_7  -include_generated_clocks] -asynchronous
set_clock_groups -group [get_clocks gtrefclk0_11 -include_generated_clocks] -asynchronous
set_clock_groups -group [get_clocks gtrefclk0_12 -include_generated_clocks] -asynchronous

set_property PACKAGE_PIN BA50 [get_ports {p_ff5_recv[0]}]
set_property PACKAGE_PIN BA51 [get_ports {n_ff5_recv[0]}]
set_property PACKAGE_PIN AY48 [get_ports {p_ff5_recv[1]}]
set_property PACKAGE_PIN AY49 [get_ports {n_ff5_recv[1]}]
set_property PACKAGE_PIN AW50 [get_ports {p_ff5_recv[2]}]
set_property PACKAGE_PIN AW51 [get_ports {n_ff5_recv[2]}]
set_property PACKAGE_PIN AV48 [get_ports {p_ff5_recv[3]}]
set_property PACKAGE_PIN AV49 [get_ports {n_ff5_recv[3]}]
set_property PACKAGE_PIN BA45 [get_ports {p_ff5_xmit[0]}]
set_property PACKAGE_PIN BA46 [get_ports {n_ff5_xmit[0]}]
set_property PACKAGE_PIN AY43 [get_ports {p_ff5_xmit[1]}]
set_property PACKAGE_PIN AY44 [get_ports {n_ff5_xmit[1]}]
set_property PACKAGE_PIN AW45 [get_ports {p_ff5_xmit[2]}]
set_property PACKAGE_PIN AW46 [get_ports {n_ff5_xmit[2]}]
set_property PACKAGE_PIN AV43 [get_ports {p_ff5_xmit[3]}]
set_property PACKAGE_PIN AV44 [get_ports {n_ff5_xmit[3]}]
