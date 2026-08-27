set_property IOSTANDARD LVDS [get_ports {p_clk_200 n_clk_200}]
set_property DIFF_TERM_ADV TERM_100 [get_ports {p_clk_200 n_clk_200}]
set_property PACKAGE_PIN AT17 [get_ports p_clk_200]
set_property PACKAGE_PIN AU16 [get_ports n_clk_200]
create_clock -name clk_200 -period 5.000 [get_ports p_clk_200]

set_property IOSTANDARD LVCMOS18 [get_ports {i2c_scl_f_sysmon i2c_sda_f_sysmon}]
set_property PACKAGE_PIN BB16 [get_ports i2c_scl_f_sysmon]
set_property PACKAGE_PIN BC16 [get_ports i2c_sda_f_sysmon]

set_property LOC SYSMONE4_X0Y0 [get_cells -hier -filter {
  NAME =~ *u_sysmon_i2c/u_sysmon_slr0}]
set_property LOC SYSMONE4_X0Y1 [get_cells -hier -filter {
  NAME =~ *u_sysmon_i2c/u_sysmon_slr1}]
set_property LOC SYSMONE4_X0Y2 [get_cells -hier -filter {
  NAME =~ *u_sysmon_i2c/u_sysmon_slr2}]
set_property LOC SYSMONE4_X0Y3 [get_cells -hier -filter {
  NAME =~ *u_sysmon_i2c/u_sysmon_slr3}]
