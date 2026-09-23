# FireFly 1 native-control feasibility group: global lanes 0-11, physical
# quads 121-123.  REFCLK0 enters q122 at lf_r0_ad and reaches q121/q123 over
# the dedicated south/north routes, exactly as in the frozen v15 baseline.
set native_left_name gt_native_left121_123
set native_left_lane_first 0
set native_left_lane_last 11
set native_left_physical_quads {121 122 123}
set native_left_refclk_port p_lf_r0_ad
set native_left_refclk_source_quad 122
set native_left_refclk_routes {{121 south} {122 local} {123 north}}
set native_left_channel_sites {
  GTYE4_CHANNEL_X0Y4 GTYE4_CHANNEL_X0Y5 GTYE4_CHANNEL_X0Y6 GTYE4_CHANNEL_X0Y7
  GTYE4_CHANNEL_X0Y8 GTYE4_CHANNEL_X0Y9 GTYE4_CHANNEL_X0Y10 GTYE4_CHANNEL_X0Y11
  GTYE4_CHANNEL_X0Y12 GTYE4_CHANNEL_X0Y13 GTYE4_CHANNEL_X0Y14 GTYE4_CHANNEL_X0Y15
}
set native_left_common_sites {GTYE4_COMMON_X0Y1 GTYE4_COMMON_X0Y2 GTYE4_COMMON_X0Y3}
set native_left_line_rate_gbps 25.78125
set native_left_refclk_mhz 322.265625
set native_left_user_data_width 80
