set all_links_check_dir [file dirname [file normalize [info script]]]
source [file join $all_links_check_dir apply_eye_scan_v1_constraints.tcl]

set channels [get_cells -hier -filter {REF_NAME == GTYE4_CHANNEL && IS_PRIMITIVE}]
set commons [get_cells -hier -filter {REF_NAME == GTYE4_COMMON && IS_PRIMITIVE}]
set refclks [get_cells -hier -filter {REF_NAME == IBUFDS_GTE4 && IS_PRIMITIVE && NAME =~ *u_refclk_buffers*}]
if {[llength $channels] != 112 || [llength $commons] != 28 || [llength $refclks] != 12} {
  error "Synthesized GT inventory channels/commons/refclks=[llength $channels]/[llength $commons]/[llength $refclks]"
}
set expected_channels {}
set expected_commons {}
foreach x {0 1} {
  for {set y 4} {$y <= 59} {incr y} {lappend expected_channels GTYE4_CHANNEL_X${x}Y$y}
  for {set y 1} {$y <= 14} {incr y} {lappend expected_commons GTYE4_COMMON_X${x}Y$y}
}
set actual_channels {}; foreach c $channels {lappend actual_channels [get_property LOC $c]}
set actual_commons {}; foreach c $commons {lappend actual_commons [get_property LOC $c]}
if {[lsort $actual_channels] ne [lsort $expected_channels]} {
  error "Synthesized channel site inventory mismatch"
}
# The generated Wizard checkpoints do not carry COMMON LOCs into the parent
# synthesized netlist.  They are fixed during implementation by the GT
# topology.  Reject a partial or wrong pre-placement inventory, but permit the
# observed all-unplaced synthesis state; the routed audit requires all sites.
set placed_commons {}
foreach site $actual_commons {if {$site ne ""} {lappend placed_commons $site}}
if {[llength $placed_commons] != 0 &&
    [lsort $placed_commons] ne [lsort $expected_commons]} {
  error "Synthesized COMMON site inventory is partially/wrongly placed: $actual_commons"
}
foreach {label pattern expected} {
  lane_engines {*g_lane*.g_managed.u_lane} 112
  prbs_controllers {*g_all_links*g_*_quad*u_prbs_test_controller} 28
  quad_controllers {*g_all_links*g_*_quad*u_quad_controller} 28
  session_applied_sync {*g_all_links*g_*_quad*session_applied_sync_reg} 28
} {
  set found [get_cells -hier -quiet -filter "NAME =~ $pattern"]
  if {[llength $found] != $expected} {
    error "$label count [llength $found], expected $expected"
  }
}
set participation_regs [get_cells -hier -quiet -filter {
  (NAME =~ *g_bank_slr*/left_quad_selected_reg* ||
   NAME =~ *g_bank_slr*/right_quad_selected_reg*) && REF_NAME =~ FD*}]
if {[llength $participation_regs] != 28} {
  error "Participation register count [llength $participation_regs], expected 28"
}
set participation_by_slr {0 0 0 0}
foreach c $participation_regs {
  if {![regexp {g_bank_slr([0-3])/} [get_property NAME $c] -> slr]} {
    error "Cannot classify participation register $c"
  }
  lset participation_by_slr $slr [expr {[lindex $participation_by_slr $slr] + 1}]
}
if {$participation_by_slr ne {6 8 8 6}} {
  error "Participation ownership is $participation_by_slr, expected 6 8 8 6"
}
set v2_copy_banks [get_cells -hier -quiet -filter {
  REF_NAME =~ eye_scan_v1_result_copy_bank*}]
if {[llength $v2_copy_banks] == 4} {
  set local_copy_regs [get_cells -hier -quiet -filter {
    NAME =~ *u_result_copy_slr*/record_stage_reg* && REF_NAME =~ FD*}]
  set local_copy_mismatch [get_cells -hier -quiet -filter {
    NAME =~ *u_result_copy_slr*/mismatch_stage_reg && REF_NAME =~ FD*}]
  if {[llength $local_copy_regs] != 1024 || [llength $local_copy_mismatch] != 4} {
    error "V2 local copy register inventory [llength $local_copy_regs]/[llength $local_copy_mismatch], expected 1024/4"
  }
  set quad_reset_regs [get_cells -hier -quiet -filter {
    NAME =~ *g_localize_quad_reset.*_quad_resetn_reg* && REF_NAME =~ FD*}]
  if {[llength $quad_reset_regs] != 28} {
    error "V2 per-quad reset-release inventory [llength $quad_reset_regs], expected 28"
  }
  foreach c $quad_reset_regs {
    if {[string tolower [get_property KEEP $c]] ni {true 1 yes}} {
      error "V2 per-quad reset release is not KEEP-preserved: $c"
    }
  }
  set split_snapshot_regs [get_cells -hier -quiet -filter {
    NAME =~ *g_split_snapshot.g_chunk*/dest_hsdata_ff_reg* && REF_NAME =~ FD*}]
  if {[llength $split_snapshot_regs] != 28672} {
    error "V2 split snapshot payload inventory [llength $split_snapshot_regs], expected 28672"
  }
  set split_ce_pins [get_pins -quiet -of_objects $split_snapshot_regs -filter {REF_PIN_NAME == CE}]
  set split_ce_nets [lsort -unique [get_nets -quiet -of_objects $split_ce_pins]]
  if {[llength $split_ce_nets] != 448} {
    error "V2 split snapshot capture-enable nets [llength $split_ce_nets], expected 448"
  }
  foreach n $split_ce_nets {
    set ce_loads [get_pins -quiet -of_objects $n -filter {REF_PIN_NAME == CE}]
    if {[llength $ce_loads] != 64} {
      error "V2 split snapshot capture-enable payload fanout is not 64 on $n: [llength $ce_loads]"
    }
  }
} elseif {[llength $v2_copy_banks] != 0} {
  error "Unexpected partial v2 result-copy bank inventory [llength $v2_copy_banks]"
}
set engine_state_cells [get_cells -hier -quiet -filter {NAME =~ *u_engine/u_core/state_reg* && REF_NAME =~ FD*}]
set quad_state_cells [get_cells -hier -quiet -filter {NAME =~ *u_quad_controller/state_reg* && REF_NAME =~ FD*}]
set prbs_state_cells [get_cells -hier -quiet -filter {NAME =~ *u_prbs_test_controller/state_reg* && REF_NAME =~ FD*}]
set engine_states {}; foreach c $engine_state_cells {
  if {[regexp {/state_reg\[[0-9]+\]$} [get_property NAME $c]]} {lappend engine_states $c}}
set quad_states {}; foreach c $quad_state_cells {
  if {[regexp {/state_reg\[[0-9]+\]$} [get_property NAME $c]]} {lappend quad_states $c}}
set prbs_states {}; foreach c $prbs_state_cells {
  if {[regexp {/state_reg\[[0-9]+\]$} [get_property NAME $c]]} {lappend prbs_states $c}}
# Engine bit 3 is unreachable for the ABI values 0..6 and is optimized away;
# each PRBS controller also has one legal fanout replica of bit 3.  Count the
# semantic state bits separately, while checking encoding on replicas too.
if {[llength $engine_states] != 3 || [llength $quad_states] != 84 || [llength $prbs_states] != 140} {
  error "FSM state inventory engine/quad/prbs=[llength $engine_states]/[llength $quad_states]/[llength $prbs_states]"
}
foreach c [concat $engine_state_cells $quad_state_cells $prbs_state_cells] {
  if {[lsearch -exact [list_property $c] FSM_ENCODING] >= 0 &&
      [string tolower [get_property FSM_ENCODING $c]] ni {none ""}} {
    error "FSM recoding detected on $c: [get_property FSM_ENCODING $c]"
  }
}
puts "PASS: all-links synthesis preflight; exact 112/28/12 GT inventory, 6/8/8/6 participation, and target CDC/placement contract"

foreach {pattern expected} {
  {*tx_enable_meta_reg} 28 {*tx_enable_sync_reg} 28
  {*enable_applied_meta_reg} 28 {*enable_applied_sync_reg} 28
  {*u_lane/config_ack_reg} 112
} {
  set cells [get_cells -hier -quiet -filter "NAME =~ $pattern && REF_NAME =~ FD*"]
  if {[llength $cells] != $expected} {error "V3 inventory $pattern = [llength $cells], expected $expected"}
}
foreach c [get_cells -hier -filter {REF_NAME == GTYE4_CHANNEL && IS_PRIMITIVE}] {
  set pin [get_pins $c/TXELECIDLE]
  set starts [all_fanin -flat -startpoints_only -only_cells -to $pin]
  if {![llength $starts]} {error "TXELECIDLE is constant on $c"}
  foreach source $starts {
    if {![string match {*tx_enable_sync_reg} [get_property NAME $source]] ||
        ![string match {FD*} [get_property REF_NAME $source]]} {
      error "Unexpected TXELECIDLE source $source"
    }
  }
}
puts "PASS: v3 dynamic electrical-idle and config/rearm inventories"

foreach {ref count} {eye_scan_point 28 eye_scan_drp_arbiter 28 eye_scan_controller 1} {
  set found [get_cells -hier -quiet -filter "REF_NAME =~ ${ref}*"]
  if {[llength $found] != $count} {error "Eye inventory $ref=[llength $found], expected $count"}
}
foreach c $channels {
  if {![string equal -nocase [get_property ES_EYE_SCAN_EN $c] TRUE] ||
      [get_property ES_HORZ_OFFSET $c] ne "12'h800"} {error "Eye initialization absent on $c"}
  set driver [get_nets -of_objects [get_pins $c/RXLPMEN]]
  if {[get_property TYPE $driver] ne "POWER"} {error "Unexpected runtime equalizer mode on $c"}
}
set eye_ram [get_cells -hier -quiet -filter {NAME =~ *u_eye_controller/matrix* && REF_NAME =~ RAMB*}]
if {[llength $eye_ram] < 8} {error "4096-point matrix is missing block RAM: [llength $eye_ram]"}
foreach c [get_cells -hier -quiet -filter {
  (NAME =~ *u_eye_point/state_reg* || NAME =~ *u_eye_drp/state_reg* ||
   NAME =~ *u_eye_controller/state_reg*) && REF_NAME =~ FD*}] {
  if {[lsearch -exact [list_property $c] FSM_ENCODING]>=0 &&
      [string tolower [get_property FSM_ENCODING $c]] ni {none ""}} {error "Eye FSM recoded on $c"}
}
puts "PASS: eye scan 28 local points/DRP owners, one global controller, initialized GTs and matrix BRAM"
set status_stages [get_cells -hier -quiet -filter {
  (NAME =~ *g_status_return*.u_return/stage_one_reg* ||
   NAME =~ *g_status_return*.u_return/stage_two_reg*) && REF_NAME =~ FD*}]
if {[llength $status_stages] != 1896} {error "Matched status return inventory [llength $status_stages], expected 1896"}
set queued_launches [get_cells -hier -quiet -filter {NAME =~ *u_eye_drp/launch_pending_reg && REF_NAME =~ FD*}]
if {[llength $queued_launches] != 28} {error "Missing registered DRP launch boundaries"}
source [file join $all_links_check_dir check_eye_scan_drp_boundary.tcl]
puts "PASS: 1896 matched status-return stages and 28 queued DRP launch boundaries"


foreach {pattern expected} {
  {*session_tag_meta_reg*} 56 {*session_tag_sync_reg*} 56
  {*session_tag_guard0_reg*} 56 {*session_tag_guard1_reg*} 56
  {*session_tag_guard2_reg*} 56 {*session_tag_guard3_reg*} 56
  {*session_tag_return_meta_reg*} 56 {*session_tag_return_sync_reg*} 56
  {*session_tag_latched_reg*} 56 {*session_tag_applied_reg*} 56
} {
  set cells [get_cells -hier -quiet -filter "NAME =~ $pattern && REF_NAME =~ FD*"]
  if {[llength $cells] != $expected} {error "V3 tagged-session inventory $pattern [llength $cells], expected $expected"}
}
puts "PASS: v3 tagged session request, guards, applied-tag and return inventories"

set return_registers [get_cells -hier -quiet -filter {
  (NAME =~ *u_config_return_slr*/*stage*_reg* || NAME =~ *u_session_return_slr*/*stage*_reg* || NAME =~ *u_observed_return_slr*/*stage*_reg*) && REF_NAME =~ FD*}]
if {[llength $return_registers] != 160} {error "V3 real return pipeline inventory [llength $return_registers], expected 160"}
puts "PASS: v3 160 real management return pipeline registers"
