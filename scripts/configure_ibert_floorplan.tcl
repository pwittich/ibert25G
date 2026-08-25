proc disable_automatic_ibert_floorplan {ip_name} {
  set floorplan_files [get_files -all -quiet *${ip_name}/tcl/quad_pblock.tcl]
  if {[llength $floorplan_files] != 1} {
    error "Expected one quad_pblock.tcl for $ip_name, found [llength $floorplan_files]"
  }

  # Vivado does not honor SCOPED_TO_CELLS when it automatically sources this
  # encrypted place-time Tcl. A pre-place hook supplies the required context.
  set_property IS_ENABLED false $floorplan_files
  puts "Disabled automatic floorplan sourcing for $ip_name"
}

disable_automatic_ibert_floorplan ibert_ultrascale_gty_core_l
disable_automatic_ibert_floorplan ibert_ultrascale_gty_core_r

set floorplan_hook [file join [file dirname [file normalize [info script]]] apply_ibert_floorplan.tcl]
set_property STEPS.PLACE_DESIGN.TCL.PRE $floorplan_hook [get_runs impl_1]
puts "Configured IBERT pre-place floorplan hook: $floorplan_hook"
