set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
source [file join $script_dir milestone3_v13_config.tcl]
source [file join $script_dir create_milestone3_project.tcl]

# The full-v12 left timing XDC blankets the managed quad domain. Replace it
# with the v13 variant so the descriptor endpoints remain explicitly timed.
remove_files [get_files */ibert_left_timing.xdc]
add_files -fileset constrs_1 -norecurse \
  [file join $repo_dir constraints ibert_left_milestone3_v13_timing.xdc]
set_property STEPS.OPT_DESIGN.TCL.PRE \
  [file join $script_dir apply_descriptor_cdc.tcl] [get_runs impl_1]
