set audit_suffix 274
set audit_label "2.5.24"
source [file join [file dirname [file normalize [info script]]] audit_milestone255_routed.tcl]
source [file join $script_dir check_descriptor_routed.tcl]
source [file join $script_dir check_profile_control_routed.tcl]
source [file join $script_dir check_runtime_integrity_routed.tcl]
source [file join $script_dir check_milestone274_hook_routed.tcl]
