source [file join [file dirname [file normalize [info script]]] milestone269_config.tcl]
set diagnostic_reference_project [file join $repo_dir build gt_test_milestone268 gt_test_milestone268.xpr]
set diagnostic_reference_dcp [file join $repo_dir build gt_test_milestone268 \
  gt_test_milestone268.runs impl_1 gt_test_milestone25_top_routed.dcp]
set diagnostic_reference_sha256 45ac009b1791e88a6aead156ec236297f5c99d5c26875d4c36ee4d08332ef7d5
source [file join $script_dir create_diagnostic_incremental.tcl]
