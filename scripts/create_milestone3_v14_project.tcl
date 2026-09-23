set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
source [file join $script_dir milestone3_v14_config.tcl]
source [file join $script_dir create_milestone3_project.tcl]

# Keep v13's explicit descriptor timing for the full-image diagnostic.
remove_files [get_files */ibert_left_timing.xdc]
add_files -fileset constrs_1 -norecurse \
  [file join $repo_dir constraints ibert_left_milestone3_v13_timing.xdc]
set_property STEPS.OPT_DESIGN.TCL.PRE \
  [file join $script_dir apply_descriptor_cdc.tcl] [get_runs impl_1]
