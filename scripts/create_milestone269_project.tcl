source [file join [file dirname [file normalize [info script]]] milestone269_config.tcl]
if {[info exists milestone269_clean_build]} { set project_name_override gt_test_milestone269_clean }
if {[file exists [file join $repo_dir build $project_name_override]]} {
  error "Destination exists; preserve it before explicitly requesting a rebuild"
}
source [file join $script_dir create_milestone255_project.tcl]
