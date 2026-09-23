# Structural inventory shared by the immutable routed-DCP preflight and the
# one-shot post-route physical-optimization gate.  The caller must have an
# all-links v1 checkpoint open.
foreach {label pattern expected} {
  channels {REF_NAME == GTYE4_CHANNEL && IS_PRIMITIVE} 112
  commons {REF_NAME == GTYE4_COMMON && IS_PRIMITIVE} 28
  refclks {REF_NAME == IBUFDS_GTE4 && IS_PRIMITIVE && NAME =~ *u_refclk_buffers*} 12
  controllers {NAME =~ */u_prbs_test_controller && REF_NAME =~ gt_prbs_test_controller*} 28
  request_meta {NAME =~ *session_meta_reg && REF_NAME =~ FD*} 28
  request_sync {NAME =~ *session_sync_reg && REF_NAME =~ FD*} 28
  return_meta {NAME =~ *session_applied_meta_reg && REF_NAME =~ FD*} 28
  return_sync {NAME =~ *session_applied_sync_reg && REF_NAME =~ FD*} 28
  descriptors {NAME =~ */g_lane*.g_managed.u_lane/selected_meta_reg/D || NAME =~ */g_lane*.g_managed.u_lane/prbs_meta_reg*/D} 448
} {
  if {$label eq "descriptors"} {
    set found [get_pins -hier -quiet -filter $pattern]
  } else {
    set found [get_cells -hier -quiet -filter $pattern]
  }
  if {[llength $found] != $expected} {error "$label inventory [llength $found], expected $expected"}
}
foreach pattern {*session_meta_reg *session_sync_reg *session_applied_meta_reg *session_applied_sync_reg} {
  foreach cell [get_cells -hier -quiet -filter "NAME =~ $pattern && REF_NAME =~ FD*"] {
    if {![get_property ASYNC_REG $cell]} {error "Session chain lacks ASYNC_REG: $cell"}
  }
}
foreach pattern {all_links_v1_quads_slr* all_links_v1_locality_slr* all_links_v1_kh_locality_slr*} {
  if {[llength [get_pblocks -quiet $pattern]]} {error "Obsolete experiment pblock $pattern"}
}
set expected_indices {0 2 3 4 5 6}
for {set slr 0} {$slr < 4} {incr slr} {
  set bank [get_cells -hier -quiet -filter "NAME =~ *g_bank_slr$slr && REF_NAME =~ all_links_v1_slr_bank*"]
  if {[llength $bank] != 1 || ![string equal -nocase [get_property USER_SLR_ASSIGNMENT $bank] "SLR$slr"]} {
    error "SLR$slr bank root/assignment mismatch"
  }
  set name [get_property NAME $bank]
  set ctrls [get_cells -hier -quiet -filter "NAME =~ ${name}/u_control_pipeline/controls_out_reg* && REF_NAME =~ FD*"]
  set indices {}
  foreach cell $ctrls {
    if {![regexp {controls_out_reg\[([0-9]+)\]$} [get_property NAME $cell] -> index]} {error "Bad control boundary $cell"}
    lappend indices $index
  }
  set indices [lsort -integer $indices]
  set reset [get_cells -hier -quiet -filter "NAME == ${name}/local_resetn_reg && REF_NAME =~ FD*"]
  if {$indices ne $expected_indices || [llength $reset] != 1} {error "SLR$slr post-opt boundary mismatch: $indices/[llength $reset]"}
  foreach cell [concat $ctrls $reset] {
    set actual [get_property NAME [get_slrs -quiet -of_objects [get_sites -quiet -of_objects $cell]]]
    if {$actual ne "SLR$slr"} {error "SLR$slr boundary escaped: $cell -> $actual"}
  }
  set roots [get_cells -hier -quiet -filter "NAME =~ ${name}/*/u_prbs_test_controller && REF_NAME =~ gt_prbs_test_controller*"]
  set expected [lindex {6 8 8 6} $slr]
  if {[llength $roots] != $expected} {error "SLR$slr controller ownership [llength $roots], expected $expected"}
  set reset_q [get_pins -quiet -of_objects $reset -filter {REF_PIN_NAME == Q}]
  foreach load [get_pins -quiet -leaf -of_objects [get_nets -quiet -of_objects $reset_q] -filter {DIRECTION == IN}] {
    if {![string match "${name}/*" [get_property NAME $load]]} {error "SLR$slr reset escapes bank: $load"}
  }
}

# Exact physical REFCLK topology: 28 dedicated common inputs and four direct
# QPLL0 connections per lane, i.e. 224 channel sinks.
set modes {south local north local south local north south local north local south local north}
set left_ports {p_lf_r0_ad p_lf_r0_ad p_lf_r0_ad p_lf_r0_af p_lf_r0_r p_lf_r0_r p_lf_r0_r p_lf_r0_u p_lf_r0_u p_lf_r0_u p_lf_r0_w p_lf_r0_y p_lf_r0_y p_lf_r0_y}
set right_ports {p_rt_r0_n p_rt_r0_n p_rt_r0_n p_rt_r0_p p_rt_r0_b p_rt_r0_b p_rt_r0_b p_rt_r0_e p_rt_r0_e p_rt_r0_e p_rt_r0_g p_rt_r0_i p_rt_r0_i p_rt_r0_i}
set route_count 0
set qpll_sink_count 0
foreach x {0 1} {
  set ports [expr {$x == 0 ? $left_ports : $right_ports}]
  for {set q 0} {$q < 14} {incr q} {
    set mode [lindex $modes $q]
    set common_pin [expr {$mode eq "local" ? "GTREFCLK00" : ($mode eq "south" ? "GTSOUTHREFCLK00" : "GTNORTHREFCLK00")}]
    set common_site GTYE4_COMMON_X${x}Y[expr {$q+1}]
    set common [get_cells -hier -quiet -filter "REF_NAME == GTYE4_COMMON && LOC == $common_site"]
    set pin [get_pins -quiet -of_objects $common -filter "REF_PIN_NAME == $common_pin"]
    set sources [all_fanin -quiet -flat -startpoints_only -to $pin]
    if {[llength $pin] != 1 || [lsearch -exact $sources [lindex $ports $q]] < 0} {error "$common_site dedicated REFCLK mismatch"}
    incr route_count
    for {set lane 0} {$lane < 4} {incr lane} {
      set channel_site GTYE4_CHANNEL_X${x}Y[expr {4+4*$q+$lane}]
      set channel [get_cells -hier -quiet -filter "REF_NAME == GTYE4_CHANNEL && LOC == $channel_site"]
      foreach {sink_name driver_name} {QPLL0CLK QPLL0OUTCLK QPLL0REFCLK QPLL0OUTREFCLK} {
        set sink [get_pins -quiet -of_objects $channel -filter "REF_PIN_NAME == $sink_name"]
        set drivers [get_pins -quiet -leaf -of_objects [get_nets -quiet -of_objects $sink] -filter {DIRECTION == OUT}]
        set expected_driver [get_pins -quiet -of_objects $common -filter "REF_PIN_NAME == $driver_name"]
        if {[llength $sink] != 1 || [llength $drivers] != 1 || [llength $expected_driver] != 1 || [lindex $drivers 0] ne [lindex $expected_driver 0]} {
          error "$channel_site/$sink_name QPLL source mismatch"
        }
        incr qpll_sink_count
      }
    }
  }
}
if {$route_count != 28 || $qpll_sink_count != 224} {error "REFCLK/QPLL inventory $route_count/$qpll_sink_count"}
puts "PASS: all-links post-route inventory 112/28/12, 28 controllers, 28 dedicated REFCLK routes, 224 QPLL sinks, 6/8/8/6 banks"
