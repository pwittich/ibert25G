set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set project_name_override gt_test_milestone275
set firmware_elf_override [file join $repo_dir build firmware275 gt_test_milestone275.elf]
# Isolated v275 qualification candidate. Preserve v273 startup/runtime policy,
# while explicitly disabling the v274-only monitor-injection hook.
set top_generics_override {
  DIAGNOSTIC_TRACE=2 HARDWARE_VERSION=131353 STAGED_RX_ACQUISITION=1
  REQUIRE_ERROR_FREE_QUALIFICATION=0 USE_EXACT_ERROR_COUNTS=0
  DIAGNOSTIC_RX_CLOCK_MONITOR=1 EXTERNAL_RX_RECOVERY=0 EXTERNAL_QUAD_RECOVERY=1
  EXTERNAL_STARTUP_QUAD_RESTART=1
  POST_CAPTURE_RX_REQUAL=0 POST_CAPTURE_QUAD_RESTART=1
  RUNTIME_INTEGRITY_DETECTOR=1 INTEGRITY_HEARTBEAT_TEST_HOOK=0
}
