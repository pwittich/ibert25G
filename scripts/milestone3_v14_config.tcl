set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set project_name_override gt_test_milestone3_v14
set firmware_elf_override [file join $repo_dir build firmware_milestone3_v14 \
  gt_test_milestone3_v14.elf]
# Full v14 is a one-variable diagnostic of v13: omit only the planned
# external startup full-quad restart.  It is not a qualification candidate.
set top_generics_override {
  DIAGNOSTIC_TRACE=2 HARDWARE_VERSION=131086 STAGED_RX_ACQUISITION=1
  REQUIRE_ERROR_FREE_QUALIFICATION=0 USE_EXACT_ERROR_COUNTS=1
  DIAGNOSTIC_RX_CLOCK_MONITOR=0 EXTERNAL_RX_RECOVERY=0 EXTERNAL_QUAD_RECOVERY=1
  EXTERNAL_STARTUP_QUAD_RESTART=0
  POST_CAPTURE_RX_REQUAL=0 POST_CAPTURE_QUAD_RESTART=1
  RUNTIME_INTEGRITY_DETECTOR=1 INTEGRITY_HEARTBEAT_TEST_HOOK=0
}
