set milestone_build_suffix 259
set milestone_build_label "2.5.9"
set milestone_create_script create_milestone259_project.tcl
source [file join [file dirname [file normalize [info script]]] \
  build_milestone258_bitstream.tcl]
