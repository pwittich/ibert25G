# Implementation-only CDC, timing, placement, and golden GT-property contract
# for the symmetric 112-lane all-links v1 target.  The project reads the
# canonical board_pins.xdc normally; this hook must not project or duplicate it.
set all_links_script_dir [file dirname [file normalize [info script]]]
set all_links_repo_dir [file dirname $all_links_script_dir]
set_msg_config -id {Vivado 12-3520} -limit 1
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set canonical_board [file normalize [file join $all_links_repo_dir constraints board_pins.xdc]]
set enabled_board_files {}
foreach f [get_files -of_objects [get_filesets constrs_1] -quiet] {
  if {[get_property IS_ENABLED $f] && [file tail $f] eq "board_pins.xdc"} {
    lappend enabled_board_files [file normalize $f]
  }
}
set checkpoint_resume [expr {[info exists ::all_links_v1_checkpoint_resume] &&
  $::all_links_v1_checkpoint_resume}]
if {!$checkpoint_resume &&
    ([llength $enabled_board_files] != 1 || [lindex $enabled_board_files 0] ne $canonical_board)} {
  error "Canonical board_pins.xdc is not the sole enabled board-pin file: $enabled_board_files"
}
if {$checkpoint_resume && [llength $enabled_board_files] != 0} {
  error "Checkpoint-only resume unexpectedly has project constraint files: $enabled_board_files"
}

proc v3_mgmt_launch_sources {endpoints} {
  set result {}
  foreach pin [all_fanin -flat -startpoints_only -to $endpoints] {
    set parent [get_property PARENT_CELL $pin]
    set cp [get_pins -quiet $parent/C]
    if {[llength $cp] == 1 && [lsearch -exact [get_clocks -quiet -of_objects $cp] clk_200] >= 0} {
      lappend result $pin
    }
  }
  if {![llength $result]} {error "V3 bundled control has no management launch registers"}
  return $result
}

# Descriptor skew compares only management-domain launch bits. Native hold/
# reset feedback is timed normally, outside this CDC data bundle.
set descriptors [get_pins -hier -filter {
  NAME =~ */g_lane*.g_managed.u_lane/selected_meta_reg/D ||
  NAME =~ */g_lane*.g_managed.u_lane/prbs_meta_reg*/D}]
if {[llength $descriptors] != 448} {
  error "Expected 448 descriptor endpoints, got [llength $descriptors]"
}
set rx_clocks {}
for {set q 0} {$q < 28} {incr q} {
  set qdesc {}
  for {set lane [expr {4*$q}]} {$lane < 4*$q+4} {incr lane} {
    set marker [format {g_lane[%d].g_managed.u_lane/} $lane]
    foreach p $descriptors {
      if {[string first $marker [get_property NAME $p]] >= 0} {lappend qdesc $p}
    }
  }
  if {[llength $qdesc] != 16} {error "Quad index $q descriptor count is [llength $qdesc]"}
  set clock_pins {}
  foreach p $qdesc {lappend clock_pins [get_pins [get_property PARENT_CELL $p]/C]}
  set qclocks [get_clocks -quiet -of_objects $clock_pins]
  if {[llength $qclocks] != 1} {error "Quad index $q has [llength $qclocks] RX clocks"}
  lappend rx_clocks [lindex $qclocks 0]
  set sources [v3_mgmt_launch_sources $qdesc]
  set_max_delay -datapath_only 3.000 -from [get_clocks clk_200] -to $qdesc
  set_bus_skew 3.000 -from $sources -to $qdesc
}

set rx_all_meta [get_pins -hier -quiet -filter {
  NAME =~ */g_lane*.g_managed.u_lane/*_meta_reg*/D}]
if {[llength $rx_all_meta] != 1456} {
  error "Expected 1456 RX first stages, got [llength $rx_all_meta]"
}
set rx_other_meta {}
foreach p $rx_all_meta {if {[lsearch -exact $descriptors $p] < 0} {lappend rx_other_meta $p}}
if {[llength $rx_other_meta] != 1008} {
  error "Expected 1008 scalar RX first stages, got [llength $rx_other_meta]"
}
set tx_meta [get_pins -hier -quiet -filter {
  NAME =~ *g_prbs_control*.txsel_meta_reg*/D ||
  NAME =~ *g_prbs_control*.loopback_meta_reg*/D ||
  NAME =~ *g_prbs_control*.inject_meta_reg/D}]
if {[llength $tx_meta] != 784} {
  error "Expected 784 TX-control first stages, got [llength $tx_meta]"
}
set reset_ready_meta {}
foreach p [get_pins -hier -quiet -filter {NAME =~ *u_lane_reset_policy/ready_sync_reg*/D}] {
  if {[regexp {ready_sync_reg\[0\]/D$} [get_property NAME $p]]} {lappend reset_ready_meta $p}
}
if {[llength $reset_ready_meta] != 28} {
  error "Expected 28 reset-ready first stages, got [llength $reset_ready_meta]"
}
set session_request_cells [get_cells -hier -quiet -filter {
  (NAME =~ *session_meta_reg || NAME =~ *session_sync_reg) && REF_NAME =~ FD*}]
set session_request_meta [get_pins -hier -quiet -filter {NAME =~ *session_meta_reg/D}]
set session_return_cells [get_cells -hier -quiet -filter {
  (NAME =~ *session_applied_meta_reg || NAME =~ *session_applied_sync_reg) && REF_NAME =~ FD*}]
set session_return_meta [get_pins -hier -quiet -filter {NAME =~ *session_applied_meta_reg/D}]
if {[llength $session_request_cells] != 56 || [llength $session_request_meta] != 28} {
  error "Expected 28 request chains/56 TX regs, got [llength $session_request_meta]/[llength $session_request_cells]"
}
if {[llength $session_return_cells] != 56 || [llength $session_return_meta] != 28} {
  error "Expected 28 return chains/56 management regs, got [llength $session_return_meta]/[llength $session_return_cells]"
}
foreach c [concat $session_request_cells $session_return_cells] {
  if {![get_property ASYNC_REG $c]} {error "Session synchronizer lacks ASYNC_REG: $c"}
}
set tx_clock_pins {}
foreach p $tx_meta {lappend tx_clock_pins [get_pins [get_property PARENT_CELL $p]/C]}
foreach c $session_request_cells {lappend tx_clock_pins [get_pins $c/C]}
set tx_clocks [lsort -unique [get_clocks -quiet -of_objects $tx_clock_pins]]
set rx_clocks [lsort -unique $rx_clocks]
if {[llength $rx_clocks] != 28 || [llength $tx_clocks] != 28} {
  error "Expected 28 RX and 28 TX native clocks, got [llength $rx_clocks]/[llength $tx_clocks]"
}
set native_clocks [lsort -unique [concat $rx_clocks $tx_clocks]]
set other_clocks {}
foreach c [get_clocks] {if {[lsearch -exact $native_clocks $c] < 0} {lappend other_clocks $c}}
set native_gt_prbs_controls [get_pins -hier -quiet -filter {
  REF_PIN_NAME == RXPRBSCNTRESET || REF_PIN_NAME == RXPRBSSEL[0] ||
  REF_PIN_NAME == RXPRBSSEL[1] || REF_PIN_NAME == RXPRBSSEL[2]}]
if {[llength $native_gt_prbs_controls] != 448} {
  error "Expected 448 native GT PRBS control pins, got [llength $native_gt_prbs_controls]"
}
set_false_path -from $other_clocks -to $native_gt_prbs_controls
set config_enable_first {}
set scalar_rx_other {}
foreach p $rx_other_meta {
  if {[string match {*u_lane/enable_meta_reg/D} [get_property NAME $p]]} {
    lappend config_enable_first $p
  } else {lappend scalar_rx_other $p}
}
set_false_path -from $other_clocks -to [concat $scalar_rx_other $reset_ready_meta $tx_meta]
set native_async_fabric_pins {}
foreach pin [all_registers -clock $native_clocks -async_pins] {
  set parent [get_cells -quiet [get_property PARENT_CELL $pin]]
  if {[llength $parent] == 1 && ([string match "FD*" [get_property REF_NAME $parent]] ||
      [string match "LD*" [get_property REF_NAME $parent]])} {lappend native_async_fabric_pins $pin}
}
if {[llength $native_async_fabric_pins] < 200} {
  error "Native fabric async-pin inventory unexpectedly small: [llength $native_async_fabric_pins]"
}
set_false_path -to $native_async_fabric_pins
set_false_path -from $native_clocks -to $other_clocks
set_false_path -from $rx_clocks -to $tx_clocks
set_false_path -from $tx_clocks -to $rx_clocks

set control_pipeline_d [get_pins -hier -quiet -filter {
  NAME =~ *u_control_pipeline/controls_out_reg*/D}]
if {[llength $control_pipeline_d] != 28} {
  error "Expected four seven-register control banks, got [llength $control_pipeline_d] D pins"
}
set_multicycle_path 2 -setup -to $control_pipeline_d
set_multicycle_path 1 -hold -to $control_pipeline_d
set participation_pipeline_d [get_pins -hier -quiet -filter {
  NAME =~ *g_bank_slr*/left_quad_selected_reg*/D ||
  NAME =~ *g_bank_slr*/right_quad_selected_reg*/D}]
if {[llength $participation_pipeline_d] != 28} {
  error "Expected 28 bank participation D pins, got [llength $participation_pipeline_d]"
}
# The participation vector is launched from the same accepted descriptor epoch
# as the bank controls.  Give this bank boundary the identical two-cycle setup
# and one-cycle hold contract; it remains under the bank's soft SLR assignment
# and is deliberately not added to the 32-register hard boundary pblocks.
set_multicycle_path 2 -setup -to $participation_pipeline_d
set_multicycle_path 1 -hold -to $participation_pipeline_d
set copy_record_stage_d [get_pins -hier -quiet -filter {
  NAME =~ *u_engine/u_core/copy_record_stage_reg*/D}]
if {[llength $copy_record_stage_d] != 256} {
  error "Expected 256 result-copy D pins, got [llength $copy_record_stage_d]"
}
set_multicycle_path 2 -setup -to $copy_record_stage_d
set_multicycle_path 1 -hold -to $copy_record_stage_d

# All-links v2 replaces the central 112-to-1 mux with four registered local
# banks.  V1 and every historical target have no such roots and retain the
# exact legacy constraint set above.
set result_copy_banks [get_cells -hier -quiet -filter {
  REF_NAME =~ all_links_v3_result_copy_bank*}]
if {[llength $result_copy_banks] ni {0 4}} {
  error "Expected zero or four v2 result-copy banks, got [llength $result_copy_banks]"
}
if {[llength $result_copy_banks] == 4} {
  set local_record_d [get_pins -hier -quiet -filter {
    NAME =~ *u_result_copy_slr*/record_stage_reg*/D}]
  set local_mismatch_d [get_pins -hier -quiet -filter {
    NAME =~ *u_result_copy_slr*/mismatch_stage_reg/D}]
  if {[llength $local_record_d] != 1024 || [llength $local_mismatch_d] != 4} {
    error "V2 result-copy staging D inventory [llength $local_record_d]/[llength $local_mismatch_d], expected 1024/4"
  }
  set_multicycle_path 2 -setup -to [concat $local_record_d $local_mismatch_d]
  set_multicycle_path 1 -hold -to [concat $local_record_d $local_mismatch_d]
  foreach bank $result_copy_banks {
    if {![regexp {u_result_copy_slr([0-3])$} [get_property NAME $bank] -> slr]} {
      error "Cannot classify v2 result-copy bank $bank"
    }
    set_property USER_SLR_ASSIGNMENT SLR$slr $bank
  }
}

set descriptor_launch_registers [get_cells -hier -quiet -filter {
  NAME =~ *g_descriptor_launch*.g_local.*_launch_reg*}]
if {[llength $descriptor_launch_registers] != 448} {
  error "Expected 448 descriptor launch registers, got [llength $descriptor_launch_registers]"
}
set launch_by_slr [list {} {} {} {}]
foreach cell $descriptor_launch_registers {
  if {![regexp {g_descriptor_launch\[([0-9]+)\]} [get_property NAME $cell] -> lane]} {
    error "Cannot classify descriptor launch register $cell"
  }
  set within [expr {$lane % 56}]
  set slr [expr {$within < 12 ? 0 : $within < 28 ? 1 : $within < 44 ? 2 : 3}]
  lset launch_by_slr $slr [concat [lindex $launch_by_slr $slr] $cell]
}
set control_by_slr [list {} {} {} {}]
foreach p $control_pipeline_d {
  if {![regexp {g_bank_slr([0-3])/u_control_pipeline} [get_property NAME $p] -> slr]} {
    error "Cannot classify control register $p"
  }
  lset control_by_slr $slr [concat [lindex $control_by_slr $slr] [get_cells [get_property PARENT_CELL $p]]]
}
set local_reset_regs [get_cells -hier -quiet -filter {
  NAME =~ *g_bank_slr*/local_resetn_reg && REF_NAME =~ FD*}]
if {[llength $local_reset_regs] != 4} {
  error "Expected four local reset-release registers, got [llength $local_reset_regs]"
}
foreach cell $local_reset_regs {
  if {![regexp {g_bank_slr([0-3])/local_resetn_reg} [get_property NAME $cell] -> slr]} {
    error "Cannot classify local reset register $cell"
  }
  lset control_by_slr $slr [concat [lindex $control_by_slr $slr] $cell]
}
set banks [get_cells -hier -quiet -filter {REF_NAME =~ all_links_v3_slr_bank*}]
if {[llength $banks] != 4} {error "Expected four all-links bank roots, got [llength $banks]"}
set wrapper_candidates [get_cells -hier -quiet -filter {
  REF_NAME =~ managed_all_links_v3_quad_wrapper* ||
  REF_NAME =~ managed_direct_quad_v6_wrapper*}]
set wrappers {}
foreach cell $wrapper_candidates {
  set name [get_property NAME $cell]
  if {[regexp {g_bank_slr[0-3]/g_left_quad\[[0-9]+\]\.u_managed_left$} $name] ||
      [regexp {g_bank_slr[0-3]/g_right_quad\[[0-9]+\]\.u_managed_right$} $name]} {
    lappend wrappers $cell
  }
}
set controllers [get_cells -hier -quiet -filter {REF_NAME =~ gt_prbs_test_controller*}]
set lane_engines [get_cells -hier -quiet -filter {REF_NAME =~ all_links_v3_lane_engine*}]
set reducer_groups [get_cells -hier -quiet -filter {
  REF_NAME =~ direct_all_v7_quad_group_aggregate* && NAME =~ *u_local_aggregate*}]
if {[llength $wrappers] != 28 || [llength $controllers] != 28 ||
    [llength $lane_engines] != 112 || [llength $reducer_groups] != 4} {
  error "Locality roots wrappers/controllers/engines/reducers=[llength $wrappers]/[llength $controllers]/[llength $lane_engines]/[llength $reducer_groups]"
}
# Remove the obsolete advisory hierarchy properties explicitly.
reset_property USER_SLR_ASSIGNMENT $wrappers
reset_property USER_SLR_ASSIGNMENT $controllers
reset_property USER_SLR_ASSIGNMENT $reducer_groups
foreach bank $banks {
  if {![regexp {g_bank_slr([0-3])$} [get_property NAME $bank] -> slr]} {
    error "Cannot classify bank root $bank"
  }
  set_property USER_SLR_ASSIGNMENT SLR$slr $bank
}
set failed_whole_wrapper_pblocks [get_pblocks -quiet all_links_v1_quads_slr*]
if {[llength $failed_whole_wrapper_pblocks] ni {0 4}} {
  error "Unexpected whole-wrapper pblock inventory [llength $failed_whole_wrapper_pblocks]"
}
if {[llength $failed_whole_wrapper_pblocks]} {delete_pblocks $failed_whole_wrapper_pblocks}

# Failed locality experiments stay deleted.  Only the proven control and
# descriptor launch-bank pblocks remain active.
if {[llength [get_pblocks -quiet all_links_v1_locality_slr*]]} {
  delete_pblocks [get_pblocks all_links_v1_locality_slr*]
}
if {[llength [get_pblocks -quiet all_links_v1_kh_locality_slr*]]} {
  delete_pblocks [get_pblocks all_links_v1_kh_locality_slr*]
}
for {set slr 0} {$slr < 4} {incr slr} {
  set controls [lsort -unique [lindex $control_by_slr $slr]]
  if {[llength $controls] != 8} {error "SLR$slr control/reset count [llength $controls]"}
  set launches [lsort -unique [lindex $launch_by_slr $slr]]
  set expected [lindex {96 128 128 96} $slr]
  if {[llength $launches] != $expected} {error "SLR$slr descriptor launches [llength $launches], expected $expected"}
  foreach {kind cells} [list control $controls descriptor $launches] {
    set pb all_links_v1_${kind}_slr${slr}
    if {[llength [get_pblocks -quiet $pb]]} {delete_pblocks [get_pblocks $pb]}
    create_pblock $pb
    resize_pblock [get_pblocks $pb] -add SLR$slr
    add_cells_to_pblock [get_pblocks $pb] $cells
    if {$kind eq "control"} {
      # These eight bank-boundary registers are the established narrow hard
      # boundary, unlike the rejected whole-wrapper locality experiments.
      set_property IS_SOFT false [get_pblocks $pb]
    }
  }
}

if {[llength [get_pblocks -quiet all_links_v1_quads_slr*]] != 0} {
  error "Failed whole-wrapper all_links_v1_quads_slr pblocks are still present"
}
set final_reduce {}
foreach cell [get_cells -hier -quiet -filter {REF_NAME == all_links_v3_quad_aggregate}] {
  if {[get_property NAME $cell] eq {u_all_links/g_all_links.u_quad_aggregate}} {
    lappend final_reduce $cell
  }
}
if {[llength $final_reduce] != 1} {error "No unique all-links final reducer"}
reset_property USER_SLR_ASSIGNMENT $final_reduce

set left_channels [get_cells -hier -filter {
  REF_NAME == GTYE4_CHANNEL && IS_PRIMITIVE && LOC =~ GTYE4_CHANNEL_X0Y*}]
set right_channels [get_cells -hier -filter {
  REF_NAME == GTYE4_CHANNEL && IS_PRIMITIVE && LOC =~ GTYE4_CHANNEL_X1Y*}]
if {[llength $left_channels] != 56 || [llength $right_channels] != 56} {
  error "Expected 56 left and 56 right channels, got [llength $left_channels]/[llength $right_channels]"
}
foreach channel $left_channels {
  set_property -dict [list ADAPT_CFG1 16'hF81C RXCDR_CFG3 16'h0012 \
    RXDFE_GC_CFG2 16'hFFF0 RX_DEGEN_CTRL 3'b100 RX_DFE_AGC_CFG1 2 \
    RX_SUM_DEGEN_AVTT_OVERITE 0 RX_SUM_VCMTUNE 4'b0011] $channel
}
foreach channel $right_channels {
  set_property -dict [list ADAPT_CFG1 16'hFB1C RXCDR_CFG3 16'h0010 \
    RXDFE_GC_CFG2 16'hFFE0 RX_DEGEN_CTRL 3'b111 RX_DFE_AGC_CFG1 4 \
    RX_SUM_DEGEN_AVTT_OVERITE 1 RX_SUM_VCMTUNE 4'b1001 \
    PCI3_AUTO_REALIGN FRST_SMPL PCIE_PLL_SEL_MODE_GEN4 2'h0 \
    RX_PROGDIV_CFG 20.0 RX_PROGDIV_RATE 16'h0000 RX_WIDEMODE_CDR_GEN3 2'b01 \
    RXCDR_CFG3_GEN2 6'h10 RXCDR_CFG3_GEN3 16'h0010 RXCDR_CFG3_GEN4 16'h0010] $channel
}
puts "ALL_LINKS_V1_CONSTRAINTS: 28x16 descriptor endpoints, 28 native RX/TX clocks, 28 bus-skew groups, 28 soft-bank participation registers, four soft bank assignments, 32 hard control/reset boundary registers, v2 result banks soft-only, descriptor pblocks, golden left/right RX properties"

# Additional v3 single-bit CDC inputs; no broad new exceptions.
set v3_cdc [get_pins -hier -quiet -filter {
  NAME =~ *tx_enable_meta_reg/D || NAME =~ *u_lane/config_sync_reg[0]/D}]
# config_sync bus notation is matched explicitly below to avoid glob brackets.
set rearm_first {}
foreach p [get_pins -hier -quiet -filter {NAME =~ *u_lane/config_sync_reg*/D}] {
  if {[regexp {config_sync_reg\[0\]/D$} [get_property NAME $p]]} {lappend rearm_first $p}
}
set enable_first [get_pins -hier -quiet -filter {NAME =~ *tx_enable_meta_reg/D}]
if {[llength $rearm_first] != 112 || [llength $enable_first] != 28} {
  error "V3 rearm/enable CDC inventory mismatch"
}
set_false_path -from [get_clocks clk_200] -to $enable_first

# Gray session request tags are bundled behind the two-stage session level;
# their four-stage request guard is checked in simulation and routed inventory.
set tag_meta [get_pins -hier -quiet -filter {NAME =~ *session_tag_meta_reg*/D}]
if {[llength $tag_meta] != 56} {error "Expected 56 Gray session tag first stages"}
set session_bundle [concat $session_request_meta $tag_meta]
set_max_delay -datapath_only 3.000 -from [get_clocks clk_200] -to $session_bundle
foreach native_tx_clk $tx_clocks {
  set endpoints {}
  foreach pin $session_bundle {
    set clock_pin [get_pins [get_property PARENT_CELL $pin]/C]
    if {[lsearch -exact [get_clocks -of_objects $clock_pin] $native_tx_clk] >= 0} {lappend endpoints $pin}
  }
  if {[llength $endpoints] != 3} {error "Expected three session bundle D pins per TX clock"}
  set sources [v3_mgmt_launch_sources $endpoints]
  set_bus_skew 3.000 -from $sources -to $endpoints
}

set config_banks [get_cells -hier -quiet -filter {REF_NAME =~ all_links_v3_config_ack_bank*}]
if {[llength $config_banks] != 4} {error "Expected four config acknowledgement banks"}
foreach bank $config_banks {
  if {![regexp {u_config_ack_slr([0-3])$} [get_property NAME $bank] -> slr]} {error "Bad config bank name"}
  set_property USER_SLR_ASSIGNMENT SLR$slr $bank
}
set config_launch [get_pins -hier -quiet -filter {
  NAME =~ *u_config_ack_slr*/*_expected_tx_reg*/D ||
  NAME =~ *u_config_ack_slr*/*_expected_rx_reg*/D ||
  NAME =~ *u_config_ack_slr*/*_expected_epoch_reg*/D}]
if {[llength $config_launch] != 84} {error "Expected 84 stable config bank boundary D pins"}
# These bundled controls are held through a phase-tagged request/ack handshake.
# They are not sampled as results until the matching return phase is captured.
set_multicycle_path 2 -setup -to $config_launch
set_multicycle_path 1 -hold -to $config_launch
foreach reg [get_cells -hier -quiet -filter {
  (NAME =~ *u_engine/u_core/epoch_meta_reg* || NAME =~ *u_engine/u_core/epoch_sync_reg*) && REF_NAME =~ FD*}] {
  if {![regexp {epoch_(meta|sync)_reg\[([0-9]+)\]} [get_property NAME $reg] -> kind lane]} {
    error "Cannot classify config return register $reg"
  }
  set within [expr {$lane % 56}]
  set slr [expr {$within < 12 ? 0 : $within < 28 ? 1 : $within < 44 ? 2 : 3}]
  set_property USER_SLR_ASSIGNMENT SLR$slr $reg
}

# Local epoch/enable are a bundled receive configuration request. The phase
# guard excludes the first seven management cycles after each phase change.
set rx_config_bundle [concat $rearm_first $config_enable_first]
if {[llength $rx_config_bundle] != 224} {error "Expected 224 RX configuration bundle endpoints"}
set_max_delay -datapath_only 3.000 -from [get_clocks clk_200] -to $rx_config_bundle
foreach native_rx_clk $rx_clocks {
  set endpoints {}
  foreach pin $rx_config_bundle {
    if {[lsearch -exact [get_clocks -of_objects [get_pins [get_property PARENT_CELL $pin]/C]] $native_rx_clk] >= 0} {
      lappend endpoints $pin
    }
  }
  if {[llength $endpoints] != 8} {error "Expected eight RX configuration bundle endpoints per quad"}
  set_bus_skew 3.000 -from [v3_mgmt_launch_sources $endpoints] -to $endpoints
}

# Return data is pipelined with its tag through real registers. No multi-cycle
# exception applies to these paths or to the session tag launch registers.
set return_count 0
foreach cell [get_cells -hier -quiet -filter {
  (NAME =~ *u_config_return_slr*/*stage*_reg* || NAME =~ *u_session_return_slr*/*stage*_reg* || NAME =~ *u_observed_return_slr*/*stage*_reg*) && REF_NAME =~ FD*}] {
  if {![regexp {u_(config|session|observed)_return_slr([0-3])/(stage_one|stage_two)_reg} [get_property NAME $cell] -> kind bank stage]} {
    error "Cannot classify return pipeline $cell"
  }
  set slr [expr {$stage eq "stage_two" ? 1 : ($bank == 3 ? 2 : $bank)}]
  set_property USER_SLR_ASSIGNMENT SLR$slr $cell
  incr return_count
}
if {$return_count != 160} {error "Expected 160 real return pipeline registers, found $return_count"}
foreach cell [get_cells -hier -quiet -filter {
  NAME =~ *u_engine/u_core/config_settled*_reg* || NAME =~ *u_engine/u_core/config_phase*_reg* ||
  NAME =~ *u_quad_aggregate/on_complete_reg || NAME =~ *u_quad_aggregate/off_complete_reg ||
  NAME =~ *u_quad_aggregate/acknowledged_tag*_reg*}] {
  set_property USER_SLR_ASSIGNMENT SLR1 $cell
}
