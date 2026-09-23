# q221-223 native-proof topology. This is data-only scaffolding: no IP is
# created until the full routed electrical baseline has been reviewed.
set native_proof_name gt_native_right221_223
set native_proof_lane_first 56
set native_proof_lane_last 67
set native_proof_quad_indices {14 15 16}
set native_proof_physical_quads {221 222 223}
set native_proof_refclk_port p_rt_r0_n
set native_proof_refclk_source_quad 222

# Preserve the generated IBERT topology exactly when creating native IP:
# q221 receives source q222 through south refclk, q222 locally, q223 through
# north refclk. The same relationship applies to CHANNEL and COMMON paths.
set native_proof_refclk_routes {
  {221 south} {222 local} {223 north}
}
set native_proof_channel_sites {
  GTYE4_CHANNEL_X1Y4 GTYE4_CHANNEL_X1Y5 GTYE4_CHANNEL_X1Y6 GTYE4_CHANNEL_X1Y7
  GTYE4_CHANNEL_X1Y8 GTYE4_CHANNEL_X1Y9 GTYE4_CHANNEL_X1Y10 GTYE4_CHANNEL_X1Y11
  GTYE4_CHANNEL_X1Y12 GTYE4_CHANNEL_X1Y13 GTYE4_CHANNEL_X1Y14 GTYE4_CHANNEL_X1Y15
}
# GT Wizard CONFIG.CHANNEL_ENABLE uses compact channel IDs, while routed
# primitive SITE properties use the GTYE4_CHANNEL_ prefix above.
set native_proof_wizard_channels {
  X1Y4 X1Y5 X1Y6 X1Y7 X1Y8 X1Y9 X1Y10 X1Y11
  X1Y12 X1Y13 X1Y14 X1Y15
}
set native_proof_common_sites {
  GTYE4_COMMON_X1Y1 GTYE4_COMMON_X1Y2 GTYE4_COMMON_X1Y3
}
set native_proof_line_rate_gbps 25.78125
set native_proof_refclk_mhz 322.265625
set native_proof_user_data_width 80
