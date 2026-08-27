## Milestone-3 target-specific board status pins. General board, GT, monitor,
## SysMon, and compression constraints remain in the existing XDC files.
set_property IOSTANDARD LVCMOS18 [get_ports {led_f1_blue led_f1_green led_f1_red}]
set_property PACKAGE_PIN A30 [get_ports led_f1_blue]
set_property PACKAGE_PIN A29 [get_ports led_f1_green]
set_property PACKAGE_PIN A28 [get_ports led_f1_red]
set_property IOSTANDARD LVCMOS18 [get_ports {led_f2_blue led_f2_green led_f2_red}]
set_property PACKAGE_PIN BL27 [get_ports led_f2_blue]
set_property PACKAGE_PIN BL28 [get_ports led_f2_green]
set_property PACKAGE_PIN BL30 [get_ports led_f2_red]
