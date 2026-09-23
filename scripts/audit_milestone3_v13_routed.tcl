set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set milestone3_audit_project gt_test_milestone3_v13
set milestone3_audit_label v13
set milestone3_audit_report_dir \
  [file join $repo_dir build gt_test_milestone3_v13_audit]
source [file join $script_dir audit_milestone3_routed.tcl]
source [file join $script_dir check_descriptor_routed.tcl]
source [file join $script_dir check_profile_control_routed.tcl]
source [file join $script_dir check_runtime_integrity_routed.tcl]
source [file join $script_dir check_milestone3_v13_policy_routed.tcl]
