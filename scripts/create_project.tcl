set script_dir [file dirname [file normalize [info script]]]
set repo_dir   [file dirname $script_dir]
set build_dir  [file join $repo_dir build]

create_project vu13p_ibert_25g $build_dir -part xcvu13p-flga2577-2-e -force
set_property target_language VHDL [current_project]
set_property simulator_language Mixed [current_project]

add_files [list \
  [file join $repo_dir src ibert_ultrascale_gty_l.vhd] \
  [file join $repo_dir src ibert_ultrascale_gty_r.vhd] \
  [file join $repo_dir src ibert_top.vhd] \
  [file join $repo_dir src clock_input_buffers.sv] \
  [file join $repo_dir src clock_frequency_monitor.sv] \
  [file join $repo_dir src i2c_register_slave.sv] \
  [file join $repo_dir src sysmon_i2c_ssi.sv] \
  [file join $repo_dir src top.sv]]

add_files -norecurse [list \
  [file join $repo_dir ip ibert_left ibert_ultrascale_gty_core_l.xci] \
  [file join $repo_dir ip ibert_right ibert_ultrascale_gty_core_r.xci]]

add_files -fileset constrs_1 [list \
  [file join $repo_dir constraints board_pins.xdc] \
  [file join $repo_dir constraints ibert_left_timing.xdc] \
  [file join $repo_dir constraints ibert_right_timing.xdc] \
  [file join $repo_dir constraints sysmon.xdc] \
  [file join $repo_dir constraints clock_monitor_pins.xdc] \
  [file join $repo_dir constraints clock_monitor_cdc.xdc]]

set_property top top [get_filesets sources_1]
update_compile_order -fileset sources_1

foreach ip [get_ips] {
  set locked [get_property IS_LOCKED $ip]
  if {$locked} {
    puts "WARNING: $ip is locked. Run report_ip_status and upgrade_ip if Vivado requests it."
  }
}

puts "Created [get_property DIRECTORY [current_project]]"
puts "Next: generate_target all [get_ips]; launch_runs impl_1 -to_step write_bitstream"
