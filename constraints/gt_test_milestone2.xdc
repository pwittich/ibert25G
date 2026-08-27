## Repository policy is to compress every generated configuration image.
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

set_property IOSTANDARD LVDS [get_ports {p_clk_200 n_clk_200}]
set_property DIFF_TERM_ADV TERM_100 [get_ports {p_clk_200 n_clk_200}]
set_property PACKAGE_PIN AT17 [get_ports p_clk_200]
set_property PACKAGE_PIN AU16 [get_ports n_clk_200]
create_clock -name clk_200 -period 5.000 [get_ports p_clk_200]

set_property IOSTANDARD LVCMOS18 [get_ports {
  i2c_scl_f_generic i2c_sda_f_generic
}]
set_property PACKAGE_PIN V36 [get_ports i2c_scl_f_generic]
set_property PACKAGE_PIN J32 [get_ports i2c_sda_f_generic]

# Cornell rev3 provides one active-high RGB triplet per FPGA site.  Drive both
# identically so this same Milestone 2 image has useful status at either site.
set_property IOSTANDARD LVCMOS18 [get_ports {led_f1_blue led_f1_green led_f1_red}]
set_property PACKAGE_PIN A30 [get_ports led_f1_blue]
set_property PACKAGE_PIN A29 [get_ports led_f1_green]
set_property PACKAGE_PIN A28 [get_ports led_f1_red]
set_property IOSTANDARD LVCMOS18 [get_ports {led_f2_blue led_f2_green led_f2_red}]
set_property PACKAGE_PIN BL27 [get_ports led_f2_blue]
set_property PACKAGE_PIN BL28 [get_ports led_f2_green]
set_property PACKAGE_PIN BL30 [get_ports led_f2_red]
