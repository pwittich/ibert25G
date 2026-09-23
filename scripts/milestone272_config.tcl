set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set project_name_override gt_test_milestone272
set firmware_elf_override [file join $repo_dir build firmware272 gt_test_milestone272.elf]
# Isolated diagnostic v272: freeze the hardware-supported initial runtime
# integrity policy. Historical targets retain their default-off behavior.
set top_generics_override {
  DIAGNOSTIC_TRACE=2 HARDWARE_VERSION=131350 STAGED_RX_ACQUISITION=1
  REQUIRE_ERROR_FREE_QUALIFICATION=0 USE_EXACT_ERROR_COUNTS=0
  DIAGNOSTIC_RX_CLOCK_MONITOR=1 EXTERNAL_RX_RECOVERY=0 EXTERNAL_QUAD_RECOVERY=1
  POST_CAPTURE_RX_REQUAL=0 POST_CAPTURE_QUAD_RESTART=1
  RUNTIME_INTEGRITY_DETECTOR=1
}
