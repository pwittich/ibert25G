source [file join [file dirname [info script]] check_milestone270_synth.tcl]
set measurement_source [get_cells -hier -filter {NAME =~ *u_engine/u_core/measurement_active_reg}]
if {[llength $measurement_source] != 1} {
  error "Expected one registered measurement source; found [llength $measurement_source]"
}
foreach {name pattern expected} {
  measurement_synchronizers *g_profile*.profile/measure_meta_reg 4
  epoch_synchronizers *g_profile*.profile/run_meta_reg 4
  profile_active_owners *g_profile*.profile/active_reg 4
  profile_completed_epochs *g_profile*.profile/completed_epoch_reg 4
} {
  set cells [get_cells -hier -filter "NAME =~ $pattern"]
  if {[llength $cells] != $expected} {
    error "Expected $expected $name; found [llength $cells]"
  }
}
