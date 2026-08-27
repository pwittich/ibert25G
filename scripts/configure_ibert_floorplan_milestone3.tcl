proc disable_automatic_ibert_floorplan_m3 {ip_name} {
  set floorplan_files [get_files -all -quiet *${ip_name}/tcl/quad_pblock.tcl]
  if {[llength $floorplan_files] != 1} {
    error "Expected one quad_pblock.tcl for $ip_name, found [llength $floorplan_files]"
  }
  set_property IS_ENABLED false $floorplan_files
  puts "Disabled automatic floorplan sourcing for $ip_name"
}

disable_automatic_ibert_floorplan_m3 ibert_ultrascale_gty_core_l
disable_automatic_ibert_floorplan_m3 ibert_ultrascale_gty_core_r
set hook [file join [file dirname [file normalize [info script]]] \
  apply_ibert_floorplan_milestone3.tcl]
set_property STEPS.PLACE_DESIGN.TCL.PRE $hook [get_runs impl_1]
