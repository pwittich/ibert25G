set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
if {[info exists ::all_links_audit_candidate]} {
  set candidate $::all_links_audit_candidate
} else {
  set candidate [file join $repo_dir build gt_test_all_links_v1 gt_test_all_links_v1_routed.dcp]
}
set golden [file join $repo_dir build gt_test_milestone3_v15 \
  gt_test_milestone3_v15.runs impl_1 gt_test_milestone3_top_routed.dcp]
if {[info exists ::all_links_audit_report_dir]} {
  set report_dir $::all_links_audit_report_dir
} else {
  set report_dir [file join $repo_dir build all_links_v1_audit]
}
file mkdir $report_dir
foreach f [list $candidate $golden] {if {![file isfile $f]} {error "Missing $f"}}

proc all_links_metadata_property {property} {
  if {[string match "*NAME*" $property]} {return 1}
  if {$property in {CLASS FILE_NAME FILE_NAMES FULL_NAME ID IS_REUSED LINE_NUMBER NAME OPT_MODIFIED
                    PARENT PBLOCK REUSE_STATUS TOOL_DERIVED_CLK_NAMES UUID XILINX_JEP106_ID
                    XILINX_REPORT_XFORM PORT_SELECT PORTS SWITCH_SELECT is_du_within_envelope
                    msgon syn_noprune}} {return 1}
  if {[string match "LC_*" $property] || [string match "P_*" $property]} {return 1}
  return 0
}

# Read the golden checkpoint only to capture physical primitive properties.
# No build assertion or candidate project Tcl is sourced by this audit.
open_checkpoint $golden
set golden_properties [dict create]
foreach x {0 1} {
  for {set y 4} {$y <= 59} {incr y} {
    set site GTYE4_CHANNEL_X${x}Y$y
    set cell [get_cells -hier -filter "REF_NAME == GTYE4_CHANNEL && LOC == $site"]
    if {[llength $cell] != 1} {error "Golden lacks exactly one $site"}
    set values [dict create]
    foreach p [list_property $cell] {
      if {![catch {get_property $p $cell} value]} {dict set values $p $value}
    }
    dict set golden_properties $site $values
  }
}
close_design

open_checkpoint $candidate
if {[get_property PART [current_design]] ne "xcvu13p-flga2577-2-e"} {error "Wrong part"}
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {
  error "Compression disabled"
}
check_timing -verbose -file [file join $report_dir check_timing.rpt]
set timing [report_timing_summary -return_string -file [file join $report_dir timing.rpt]]
set routing [report_route_status -return_string -file [file join $report_dir routing.rpt]]
report_methodology -file [file join $report_dir methodology.rpt]
report_cdc -details -file [file join $report_dir cdc.rpt]
report_clock_interaction -file [file join $report_dir clock_interaction.rpt]
report_clocks -file [file join $report_dir clocks.rpt]
report_exceptions -coverage -file [file join $report_dir exceptions.rpt]
report_utilization -file [file join $report_dir utilization.rpt]
report_drc -file [file join $report_dir drc.rpt]
if {![string match {*All user specified timing constraints are met.*} $timing]} {error "Timing failed"}
if {![regexp {# of nets with routing errors[. ]*:[ ]*0} $routing]} {error "Routing errors"}
foreach v [get_drc_violations -quiet] {
  if {[get_property SEVERITY $v] eq "Error"} {error "DRC error $v"}
}
if {[llength [get_methodology_violations -quiet -filter {NAME =~ TIMING-17* || NAME =~ TIMING-26*}]]} {
  error "Missing sequential or GT clocks"
}

set channels [get_cells -hier -filter {REF_NAME == GTYE4_CHANNEL && IS_PRIMITIVE}]
set commons [get_cells -hier -filter {REF_NAME == GTYE4_COMMON && IS_PRIMITIVE}]
set refclks [get_cells -hier -filter {REF_NAME == IBUFDS_GTE4 && IS_PRIMITIVE && NAME =~ *u_refclk_buffers*}]
if {[llength $channels] != 112 || [llength $commons] != 28 || [llength $refclks] != 12} {
  error "GT inventory [llength $channels]/[llength $commons]/[llength $refclks], expected 112/28/12"
}
set expected_channels {}; set expected_commons {}
foreach x {0 1} {
  for {set y 4} {$y <= 59} {incr y} {lappend expected_channels GTYE4_CHANNEL_X${x}Y$y}
  for {set y 1} {$y <= 14} {incr y} {lappend expected_commons GTYE4_COMMON_X${x}Y$y}
}
set actual_channels {}; foreach c $channels {lappend actual_channels [get_property LOC $c]}
set actual_commons {}; foreach c $commons {lappend actual_commons [get_property LOC $c]}
if {[lsort $actual_channels] ne [lsort $expected_channels] ||
    [lsort $actual_commons] ne [lsort $expected_commons]} {error "GT site ownership mismatch"}

foreach {label pattern expected} {
  controllers {*u_prbs_test_controller} 28
  wizard_cleanup {*u_prbs_test_controller/cleanup_wizard_reset_seen_reg} 28
  lane_cleanup {*u_prbs_test_controller/cleanup_lane_reset_seen_reg*} 112
  idle_guards {*u_prbs_test_controller/post_cleanup_idle_guard_reg*} 28
  request_meta {*session_meta_reg} 28
  request_sync {*session_sync_reg} 28
  return_meta {*session_applied_meta_reg} 28
  return_sync {*session_applied_sync_reg} 28
} {
  if {$label eq "controllers"} {
    set found [get_cells -hier -quiet -filter "NAME =~ $pattern && REF_NAME =~ gt_prbs_test_controller*"]
  } else {
    set found [get_cells -hier -quiet -filter "NAME =~ $pattern && REF_NAME =~ FD*"]
  }
  if {[llength $found] != $expected} {error "$label count [llength $found], expected $expected"}
  if {$label in {request_meta request_sync return_meta return_sync}} {
    foreach c $found {if {![get_property ASYNC_REG $c]} {error "Unmarked session synchronizer $c"}}
  }
}

set descriptors [get_pins -hier -filter {
  NAME =~ */g_lane*.g_managed.u_lane/selected_meta_reg/D ||
  NAME =~ */g_lane*.g_managed.u_lane/prbs_meta_reg*/D}]
if {[llength $descriptors] != 448} {error "Descriptor endpoint count [llength $descriptors]"}
foreach pin $descriptors {
  set path [get_timing_paths -quiet -from [get_clocks clk_200] -to $pin -max_paths 1]
  if {[llength $path] != 1 || [get_property SLACK $path] < 0 ||
      abs([get_property REQUIREMENT $path]-3.000) > 0.001} {
    error "Descriptor timing failure: $pin"
  }
}
# Rebuild the skew groups from routed endpoint clocks and actual drivers.
set descriptor_rx_clocks {}
foreach p $descriptors {
  lappend descriptor_rx_clocks {*}[get_clocks -quiet -of_objects \
    [get_pins [get_property PARENT_CELL $p]/C]]
}
set descriptor_rx_clocks [lsort -unique $descriptor_rx_clocks]
if {[llength $descriptor_rx_clocks] != 28} {error "Descriptor RX clock count [llength $descriptor_rx_clocks]"}
foreach clk $descriptor_rx_clocks {
  set endpoints {}
  foreach pin [get_pins -of_objects [all_registers -clock $clk] -filter {REF_PIN_NAME == D}] {
    if {[lsearch -exact $descriptors $pin] >= 0} {lappend endpoints $pin}
  }
  if {[llength $endpoints] != 16} {error "$clk has [llength $endpoints] descriptor endpoints"}
  set sources [all_fanin -flat -startpoints_only -to $endpoints]
  set_bus_skew 3.000 -from $sources -to $endpoints
}
set skew [report_bus_skew -return_string -file [file join $report_dir bus_skew.rpt]]
set expected_skew_groups [expr {[info exists ::all_links_audit_v2_hardening] &&
  $::all_links_audit_v2_hardening ? 476 : 28}]
if {[regexp -all {Slack \(MET\)} $skew] != $expected_skew_groups ||
    [string match {*VIOLATED*} $skew]} {
  error "Expected exactly $expected_skew_groups passing bus-skew groups (28 descriptor plus target CDC groups)"
}

# Synthesis has four seven-register control banks plus four local reset
# registers.  Post-opt, control bit 1 is legitimately absent because every
# wrapper controller has its runtime detector disabled.  Audit the exact six
# surviving identities plus reset, not raw pblock membership counts.
# intended 6/8/8/6 physical SLR split.  Result-copy gets timing only, no pblock.
for {set slr 0} {$slr < 4} {incr slr} {
  set cp [get_cells -quiet -of_objects [get_pblocks all_links_v1_control_slr$slr]]
  set dp [get_cells -quiet -of_objects [get_pblocks all_links_v1_descriptor_slr$slr]]
  set expected [lindex {96 128 128 96} $slr]
  if {[llength $dp] != $expected} {
    error "SLR$slr descriptor pblock count [llength $dp], expected $expected"
  }
  if {[get_property IS_SOFT [get_pblocks all_links_v1_control_slr$slr]]} {
    error "SLR$slr control/reset boundary pblock is unexpectedly soft"
  }
  set bank [get_cells -hier -quiet -filter "NAME =~ *g_bank_slr$slr && REF_NAME =~ all_links_v1_slr_bank*"]
  if {[llength $bank] != 1 || ![string equal -nocase [get_property USER_SLR_ASSIGNMENT $bank] "SLR$slr"]} {
    error "SLR$slr bank root/property mismatch: $bank"
  }
  set reset_reg [get_cells -hier -quiet -filter "NAME == [get_property NAME $bank]/local_resetn_reg && REF_NAME =~ FD*"]
  set controls [get_cells -hier -quiet -filter "NAME =~ [get_property NAME $bank]/u_control_pipeline/controls_out_reg* && REF_NAME =~ FD*"]
  set control_indices {}
  foreach cell $controls {
    if {![regexp {controls_out_reg\[([0-9]+)\]$} [get_property NAME $cell] -> index]} {error "Cannot decode boundary register $cell"}
    lappend control_indices $index
  }
  set control_indices [lsort -integer $control_indices]
  if {[llength $reset_reg] != 1 || $control_indices ne {0 2 3 4 5 6}} {
    error "SLR$slr bank control/reset inventory mismatch"
  }
  if {[info exists ::all_links_audit_participation] && $::all_links_audit_participation} {
    set participation [get_cells -hier -quiet -filter \
      "(NAME =~ [get_property NAME $bank]/left_quad_selected_reg* || NAME =~ [get_property NAME $bank]/right_quad_selected_reg*) && REF_NAME =~ FD*"]
    set expected_participation [lindex {6 8 8 6} $slr]
    if {[llength $participation] != $expected_participation} {
      error "SLR$slr participation count [llength $participation], expected $expected_participation"
    }
    foreach cell $participation {
      set actual [get_property NAME [get_slrs -quiet -of_objects [get_sites -quiet -of_objects $cell]]]
      if {$actual ne "SLR$slr"} {error "SLR$slr participation cell escaped: $cell actual=$actual"}
    }
  }
  if {[info exists ::all_links_audit_v2_hardening] && $::all_links_audit_v2_hardening} {
    set quad_resets [get_cells -hier -quiet -filter \
      "NAME =~ [get_property NAME $bank]/g_localize_quad_reset.*_quad_resetn_reg* && REF_NAME =~ FD*"]
    set expected_quad_resets [lindex {6 8 8 6} $slr]
    if {[llength $quad_resets] != $expected_quad_resets} {
      error "SLR$slr localized reset count [llength $quad_resets], expected $expected_quad_resets"
    }
    foreach cell $quad_resets {
      if {[string tolower [get_property KEEP $cell]] ni {true 1 yes}} {
        error "SLR$slr localized reset lost KEEP: $cell"
      }
      set actual [get_property NAME [get_slrs -quiet -of_objects [get_sites -quiet -of_objects $cell]]]
      if {$actual ne "SLR$slr"} {error "SLR$slr localized reset escaped: $cell actual=$actual"}
    }
  }
  foreach cell [concat $controls $reset_reg] {
    set actual [get_property NAME [get_slrs -quiet -of_objects [get_sites -quiet -of_objects $cell]]]
    if {$actual ne "SLR$slr"} {error "SLR$slr boundary cell escaped: $cell actual=$actual"}
  }
  set controllers [get_cells -hier -quiet -filter "NAME =~ [get_property NAME $bank]/*/u_prbs_test_controller && REF_NAME =~ gt_prbs_test_controller*"]
  set wrappers [get_cells -hier -quiet -filter "NAME =~ [get_property NAME $bank]/g_left_quad*.u_managed_left || NAME =~ [get_property NAME $bank]/g_right_quad*.u_managed_right"]
  set expected_quads [lindex {6 8 8 6} $slr]
  if {[llength $controllers] != $expected_quads || [llength $wrappers] != $expected_quads} {
    error "SLR$slr bank controllers/wrappers [llength $controllers]/[llength $wrappers], expected $expected_quads/$expected_quads"
  }
  set reset_q [get_pins -quiet -of_objects $reset_reg -filter {REF_PIN_NAME == Q}]
  set reset_loads [get_pins -quiet -leaf -of_objects [get_nets -quiet -of_objects $reset_q] -filter {DIRECTION == IN}]
  if {![llength $reset_loads]} {error "SLR$slr local reset has no routed loads"}
  foreach load $reset_loads {
    if {![string match "[get_property NAME $bank]/*" [get_property NAME $load]]} {
      error "SLR$slr local reset escapes its bank: $load"
    }
  }
}
set banks [get_cells -hier -quiet -filter {REF_NAME =~ all_links_v1_slr_bank*}]
if {[llength $banks] != 4} {error "Routed bank count [llength $banks], expected 4"}
foreach bank $banks {
  if {![string equal -nocase [get_property KEEP_HIERARCHY $bank] true] &&
      ![string equal -nocase [get_property KEEP_HIERARCHY $bank] yes]} {error "Bank root lacks KEEP_HIERARCHY: $bank"}
  if {[string equal -nocase [get_property DONT_TOUCH $bank] true]} {error "Forbidden bank DONT_TOUCH: $bank"}
}
if {[llength [get_pblocks -quiet all_links_v1_quads_slr*]] ||
    [llength [get_pblocks -quiet all_links_v1_locality_slr*]] ||
    [llength [get_pblocks -quiet all_links_v1_kh_locality_slr*]]} {
  error "Obsolete whole-hierarchy pblock remains"
}
set copy_d [get_pins -hier -quiet -filter {NAME =~ *u_engine/u_core/copy_record_stage_reg*/D}]
if {[llength $copy_d] != 256} {error "Result-copy D count [llength $copy_d]"}
if {[info exists ::all_links_audit_v2_hardening] && $::all_links_audit_v2_hardening} {
  set copy_pblocks [get_pblocks -quiet all_links_v2_copy_stage_slr*]
  if {[llength $copy_pblocks] != 0} {error "V2 result-copy stage must not be hard-pblocked"}
  set copy_banks [get_cells -hier -quiet -filter {REF_NAME =~ all_links_v2_result_copy_bank*}]
  if {[llength $copy_banks] != 4} {error "V2 result-copy bank count [llength $copy_banks], expected 4"}
  set copy_locality [open [file join $report_dir result_copy_stage_locality.rpt] w]
  foreach bank $copy_banks {
    if {![regexp {u_result_copy_slr([0-3])$} [get_property NAME $bank] -> slr]} {
      error "Cannot classify V2 result-copy bank $bank"
    }
    set records [get_cells -hier -quiet -filter \
      "NAME =~ [get_property NAME $bank]/record_stage_reg* && REF_NAME =~ FD*"]
    set mismatch [get_cells -hier -quiet -filter \
      "NAME == [get_property NAME $bank]/mismatch_stage_reg && REF_NAME =~ FD*"]
    if {[llength $records] != 256 || [llength $mismatch] != 1} {
      error "SLR$slr V2 copy staging [llength $records]/[llength $mismatch], expected 256/1"
    }
    if {![string equal -nocase [get_property USER_SLR_ASSIGNMENT $bank] "SLR$slr"]} {
      close $copy_locality
      error "SLR$slr V2 copy bank lost its soft SLR assignment"
    }
    array set copy_counts {SLR0 0 SLR1 0 SLR2 0 SLR3 0 NONE 0}
    foreach cell [concat $records $mismatch] {
      set actual [get_property NAME [get_slrs -quiet -of_objects [get_sites -quiet -of_objects $cell]]]
      if {$actual eq ""} {set actual NONE}
      incr copy_counts($actual)
    }
    puts $copy_locality "bank=SLR$slr total=257 SLR0=$copy_counts(SLR0) SLR1=$copy_counts(SLR1) SLR2=$copy_counts(SLR2) SLR3=$copy_counts(SLR3) NONE=$copy_counts(NONE)"
  }
  close $copy_locality
  set split_payload [get_cells -hier -quiet -filter {
    NAME =~ *g_split_snapshot.g_chunk*/dest_hsdata_ff_reg* && REF_NAME =~ FD*}]
  set split_ce_pins [get_pins -quiet -of_objects $split_payload -filter {REF_PIN_NAME == CE}]
  set split_ce_nets [lsort -unique [get_nets -quiet -of_objects $split_ce_pins]]
  if {[llength $split_payload] != 28672 || [llength $split_ce_nets] != 448} {
    error "V2 split snapshot inventory [llength $split_payload]/[llength $split_ce_nets], expected 28672/448"
  }
  foreach net $split_ce_nets {
    set payload_loads [get_pins -quiet -of_objects $net -filter {REF_PIN_NAME == CE}]
    if {[llength $payload_loads] != 64} {
      error "V2 split snapshot CE payload fanout on $net is [llength $payload_loads], expected 64"
    }
  }
}

# Prove 28 dedicated REFCLK common endpoints and 224 direct QPLL0 sinks.
set modes {south local north local south local north south local north local south local north}
set left_ports {p_lf_r0_ad p_lf_r0_ad p_lf_r0_ad p_lf_r0_af p_lf_r0_r p_lf_r0_r p_lf_r0_r p_lf_r0_u p_lf_r0_u p_lf_r0_u p_lf_r0_w p_lf_r0_y p_lf_r0_y p_lf_r0_y}
set right_ports {p_rt_r0_n p_rt_r0_n p_rt_r0_n p_rt_r0_p p_rt_r0_b p_rt_r0_b p_rt_r0_b p_rt_r0_e p_rt_r0_e p_rt_r0_e p_rt_r0_g p_rt_r0_i p_rt_r0_i p_rt_r0_i}
set ref_report [open [file join $report_dir dedicated_refclk_routes.rpt] w]
foreach x {0 1} {
  set ports [expr {$x == 0 ? $left_ports : $right_ports}]
  for {set q 0} {$q < 14} {incr q} {
    set mode [lindex $modes $q]
    set common_pin [expr {$mode eq "local" ? "GTREFCLK00" : ($mode eq "south" ? "GTSOUTHREFCLK00" : "GTNORTHREFCLK00")}]
    set common_site GTYE4_COMMON_X${x}Y[expr {$q+1}]
    set common [get_cells -hier -filter "REF_NAME == GTYE4_COMMON && LOC == $common_site"]
    set pin [get_pins -of_objects $common -filter "REF_PIN_NAME == $common_pin"]
    set sources [all_fanin -flat -startpoints_only -to $pin]
    set expected_port [lindex $ports $q]
    if {[llength $pin] != 1 || [lsearch -exact $sources $expected_port] < 0} {
      error "$common_site/$common_pin source mismatch: $sources"
    }
    puts $ref_report "$common_site $common_pin <- $expected_port"
    for {set lane 0} {$lane < 4} {incr lane} {
      set channel_site GTYE4_CHANNEL_X${x}Y[expr {4+4*$q+$lane}]
      set channel [get_cells -hier -filter "REF_NAME == GTYE4_CHANNEL && LOC == $channel_site"]
      foreach {sink_name driver_name} {QPLL0CLK QPLL0OUTCLK QPLL0REFCLK QPLL0OUTREFCLK} {
        set sink [get_pins -of_objects $channel -filter "REF_PIN_NAME == $sink_name"]
        set drivers [get_pins -quiet -leaf -of_objects [get_nets -of_objects $sink] -filter {DIRECTION == OUT}]
        set expected_driver [get_pins -of_objects $common -filter "REF_PIN_NAME == $driver_name"]
        if {[llength $sink] != 1 || [llength $drivers] != 1 ||
            [llength $expected_driver] != 1 || [lindex $drivers 0] ne [lindex $expected_driver 0]} {
          error "$channel_site/$sink_name is not driven only by $common_site/$driver_name"
        }
        puts $ref_report "$channel_site $sink_name <- $common_site/$driver_name"
      }
    }
  }
}
close $ref_report

# Right-bank managed primitives must match the passing direct precedent in all
# shared non-metadata properties.  Left-bank differences are fully reported;
# separately require the established FireFly RX/polarity/data-width contract.
set property_report [open [file join $report_dir golden_v15_channel_properties.rpt] w]
set right_mismatches 0; set left_differences 0; set comparisons 0
foreach site $expected_channels {
  set cell [get_cells -hier -filter "REF_NAME == GTYE4_CHANNEL && LOC == $site"]
  set candidate_values [dict create]
  foreach p [list_property $cell] {
    if {![catch {get_property $p $cell} value]} {dict set candidate_values $p $value}
  }
  set golden_values [dict get $golden_properties $site]
  set per_site 0
  foreach p [dict keys $golden_values] {
    if {[all_links_metadata_property $p] || ![dict exists $candidate_values $p]} {continue}
    incr per_site; incr comparisons
    if {[dict get $candidate_values $p] ne [dict get $golden_values $p]} {
      puts $property_report "DIFF $site $p candidate={[dict get $candidate_values $p]} golden={[dict get $golden_values $p]}"
      if {[string match GTYE4_CHANNEL_X1Y* $site]} {incr right_mismatches} else {incr left_differences}
    }
  }
  if {$per_site < 1000} {close $property_report; error "Only $per_site properties compared at $site"}
  if {[string match GTYE4_CHANNEL_X0Y* $site]} {
    foreach {p expected} {ADAPT_CFG1 16'hF81C RXCDR_CFG3 16'h0012 RXDFE_GC_CFG2 16'hFFF0
      RX_DEGEN_CTRL 3'b100 RX_DFE_AGC_CFG1 2 RX_SUM_DEGEN_AVTT_OVERITE 0
      RX_SUM_VCMTUNE 4'b0011 RX_DATA_WIDTH 80 TX_DATA_WIDTH 80 RX_INT_DATAWIDTH 2 TX_INT_DATAWIDTH 2} {
      if {[get_property $p $cell] ne $expected} {close $property_report; error "$site $p mismatch"}
    }
    foreach pin_name {RXPOLARITY TXPOLARITY} {
      set net [get_nets -of_objects [get_pins $cell/$pin_name]]
      if {[get_property TYPE $net] ne "GROUND"} {close $property_report; error "$site/$pin_name not tied low"}
    }
  }
}
puts $property_report "left_differences=$left_differences right_mismatches=$right_mismatches comparisons=$comparisons"
close $property_report
if {$right_mismatches != 0} {error "$right_mismatches right-bank golden property mismatches"}
puts "PASS: independent all-links routed audit; timing/routing/DRC, participation, 112 channels, 28 commons, 12 REFCLK buffers, 28 descriptor groups, 28 dedicated common routes, 224 QPLL0 sinks"
