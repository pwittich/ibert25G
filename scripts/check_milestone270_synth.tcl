source [file join [file dirname [info script]] check_milestone269_trace.tcl]
set guards [get_cells -hier -filter {NAME =~ */g_lane*.g_managed.u_lane/start_req_guard1_reg}]
if {[llength $guards] != 4} { error "Missing four delayed start capture chains" }
source [file join [file dirname [info script]] apply_descriptor_cdc.tcl]
