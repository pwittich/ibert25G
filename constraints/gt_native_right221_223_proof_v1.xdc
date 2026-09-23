# Isolated q221-223 native topology proof.  No v15 or historical target uses
# this file.  q222 REFCLK0 and the 200-MHz free-running Wizard clock only.
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property PACKAGE_PIN AT17 [get_ports p_clk_200]
set_property PACKAGE_PIN AU16 [get_ports n_clk_200]
set_property IOSTANDARD LVDS [get_ports {p_clk_200 n_clk_200}]
create_clock -name proof_clk_200 -period 5.000 [get_ports p_clk_200]

set_property PACKAGE_PIN AY13 [get_ports p_rt_r0_n]
set_property PACKAGE_PIN AY12 [get_ports n_rt_r0_n]
create_clock -name proof_q222_refclk -period 3.1030303 [get_ports p_rt_r0_n]
set_clock_groups -asynchronous -group [get_clocks proof_clk_200] \
  -group [get_clocks proof_q222_refclk -include_generated_clocks]
