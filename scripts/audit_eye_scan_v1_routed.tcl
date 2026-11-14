set ::all_links_audit_participation 1
set ::all_links_audit_v2_hardening 1
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
if {[info exists ::all_links_audit_candidate]} {
  set candidate $::all_links_audit_candidate
} else {
  set candidate [file join $repo_dir build gt_test_eye_scan_v1 gt_test_eye_scan_v1_routed.dcp]
}
if {[info exists ::eye_audit_input_archive]} {
  # A frozen candidate remains independently auditable after working-tree
  # validation tools evolve. Verify its verbatim input copies and artifacts.
  set archive [file normalize $::eye_audit_input_archive]
  set candidate [file normalize $candidate]
  if {[string first "$archive/" $candidate] != 0} {error "Candidate is outside its frozen input archive"}
  set old_directory [pwd]
  cd $archive
  set failed [catch {
    foreach manifest {INPUT_COPY_SHA256SUMS ARTIFACT_SHA256SUMS} {
      if {![file isfile $manifest]} {error "Missing frozen archive manifest $manifest"}
      exec sha256sum -c $manifest
    }
    set f [open ARTIFACT_SHA256SUMS r];set artifact_list [read $f];close $f
    set relative [string range $candidate [expr {[string length $archive]+1}] end]
    set expected "[lindex [exec sha256sum $candidate] 0]  $relative"
    if {[lsearch -exact [split $artifact_list \n] $expected] < 0} {error "Candidate not bound to archive artifact manifest"}
  } failure]
  cd $old_directory
  if {$failed} {error $failure}
} else {
  foreach manifest {SOURCE_SHA256SUMS IMPLEMENTATION_SHA256SUMS} {
    set path [file join $repo_dir build eye_scan_v1_reports $manifest]
    if {![file isfile $path]} {error "Missing frozen build inputs: $path"}
    exec sha256sum -c $path
  }
}

set golden [file join $repo_dir build gt_test_milestone3_v15 \
  gt_test_milestone3_v15.runs impl_1 gt_test_milestone3_top_routed.dcp]
if {[info exists ::all_links_audit_report_dir]} {
  set report_dir $::all_links_audit_report_dir
} else {
  set report_dir [file join $repo_dir build eye_scan_v1_audit]
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

# Independently compare every non-metadata GT parameter with the exact v3
# routed baseline as well, including the left bank's established settings.
set baseline [file join $repo_dir build gt_test_all_links_v3 gt_test_all_links_v3_routed.dcp]
if {![file isfile $baseline] || [lindex [exec sha256sum $baseline] 0] ne
    "ca56c79ccc90b5cf67e6d85d982238b2c3d03997b79fe45d7eccd100354fb684"} {error "V3 baseline hash mismatch"}
open_checkpoint $baseline
set baseline_properties [dict create]
foreach c [get_cells -hier -filter {REF_NAME == GTYE4_CHANNEL && IS_PRIMITIVE}] {
  set values [dict create]
  foreach p [list_property $c] {
    if {![all_links_metadata_property $p] && ![catch {get_property $p $c} value]} {
      dict set values $p $value
    }
  }
  dict set baseline_properties [get_property LOC $c] $values
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
  set sources {}
  foreach source [all_fanin -flat -startpoints_only -to $endpoints] {
    set cp [get_pins -quiet [get_property PARENT_CELL $source]/C]
    if {[llength $cp] == 1 && [lsearch -exact [get_clocks -of_objects $cp] clk_200] >= 0} {lappend sources $source}
  }
  if {![llength $sources]} {error "No management descriptor launches"}
  set_bus_skew 3.000 -from $sources -to $endpoints
}
set skew [report_bus_skew -return_string -file [file join $report_dir bus_skew.rpt]]
set expected_skew_groups [expr {[info exists ::all_links_audit_v2_hardening] &&
  $::all_links_audit_v2_hardening ? 532 : 28}]
if {[regexp -all {Slack \(MET\)} $skew] != $expected_skew_groups ||
    [string match {*VIOLATED*} $skew]} {
  error "Expected exactly $expected_skew_groups passing bus-skew groups (28 descriptor plus target CDC groups)"
}

# Synthesis has four seven-register control banks plus four local reset
# registers.  Post-opt, control bit 1 is legitimately absent because every
# wrapper controller has its runtime detector disabled.  Audit the exact six
# surviving identities plus reset, not raw pblock membership counts.
# intended 6/8/8/6 physical SLR split.  Result-copy gets timing only, no pblock.
source [file join $script_dir check_eye_scan_reset_ownership.tcl]
eye_reset_audit::initialize $report_dir
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
  set bank [get_cells -hier -quiet -filter "NAME =~ *g_bank_slr$slr && REF_NAME =~ eye_scan_v1_slr_bank*"]
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
  eye_reset_audit::check_loads $bank $reset_reg
}
eye_reset_audit::finish
set banks [get_cells -hier -quiet -filter {REF_NAME =~ eye_scan_v1_slr_bank*}]
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
  set copy_banks [get_cells -hier -quiet -filter {REF_NAME =~ eye_scan_v1_result_copy_bank*}]
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
      if {$p eq "ES_EYE_SCAN_EN" && [string equal -nocase [dict get $candidate_values $p] TRUE]} {continue}
      if {$p eq "ES_HORZ_OFFSET" && [dict get $candidate_values $p] eq "12'h800"} {continue}
      if {[string match GTYE4_CHANNEL_X1Y* $site]} {incr right_mismatches} else {incr left_differences}
    }
  }
  if {$per_site < 1000} {close $property_report; error "Only $per_site properties compared at $site"}
  if {![string equal -nocase [get_property ES_EYE_SCAN_EN $cell] TRUE] ||
      [get_property ES_HORZ_OFFSET $cell] ne "12'h800"} {error "Eye initialization absent on $site"}
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

# v3-specific routed structural checks, separate from build constraints.
foreach {pattern expected} {
  {*tx_enable_meta_reg} 28 {*tx_enable_sync_reg} 28
  {*enable_applied_meta_reg} 28 {*enable_applied_sync_reg} 28
  {*u_lane/config_ack_reg} 112
} {
  set cells [get_cells -hier -quiet -filter "NAME =~ $pattern && REF_NAME =~ FD*"]
  if {[llength $cells] != $expected} {error "V3 routed inventory $pattern = [llength $cells], expected $expected"}
}
foreach c $channels {
  set starts [all_fanin -flat -startpoints_only -only_cells -to [get_pins $c/TXELECIDLE]]
  if {[llength $starts] != 1 || ![string match {*tx_enable_sync_reg} [get_property NAME [lindex $starts 0]]]} {
    error "V3 electrical idle is not driven by the synchronized local enable on $c"
  }
}
# Request level plus two Gray tag bits must retain their timed 3-ns CDC bundle.
set tag_endpoints [get_pins -hier -quiet -filter {NAME =~ *session_tag_meta_reg*/D || NAME =~ *session_meta_reg/D}]
if {[llength $tag_endpoints] != 84} {error "V3 session bundle inventory"}
foreach pin $tag_endpoints {
  set path [get_timing_paths -quiet -from [get_clocks clk_200] -to $pin -max_paths 1]
  if {[llength $path] != 1 || [get_property SLACK $path] < 0 ||
      abs([get_property REQUIREMENT $path]-3.000)>0.001} {error "V3 session bundle timing $pin"}
}
# Independently check the receive request/enable bundle and real return stages.
set rx_endpoints [get_pins -hier -quiet -filter {NAME =~ *u_lane/enable_meta_reg/D}]
foreach pin [get_pins -hier -quiet -filter {NAME =~ *u_lane/config_sync_reg*/D}] {
  if {[regexp {config_sync_reg\[0\]/D$} [get_property NAME $pin]]} {lappend rx_endpoints $pin}
}
if {[llength $rx_endpoints] != 224} {error "V3 receive configuration bundle inventory"}
foreach pin $rx_endpoints {
  set path [get_timing_paths -quiet -from [get_clocks clk_200] -to $pin -max_paths 1]
  if {[llength $path] != 1 || [get_property SLACK $path] < 0 ||
      abs([get_property REQUIREMENT $path]-3.000)>0.001} {error "V3 RX bundle timing $pin"}
}
set return_registers [get_cells -hier -quiet -filter {
  (NAME =~ *u_config_return_slr*/*stage*_reg* || NAME =~ *u_session_return_slr*/*stage*_reg* || NAME =~ *u_observed_return_slr*/*stage*_reg*) && REF_NAME =~ FD*}]
if {[llength $return_registers] != 160} {error "V3 real return pipeline inventory"}
foreach cell $return_registers {
  set path [get_timing_paths -quiet -to [get_pins $cell/D] -max_paths 1]
  if {[llength $path] != 1 || [get_property SLACK $path] < 0 ||
      abs([get_property REQUIREMENT $path]-5.000)>0.001} {error "V3 return stage lacks ordinary 5-ns timing: $cell"}
}
set marker [file join $report_dir AUDIT_PASS]
foreach {ref expected} {eye_scan_point 28 eye_scan_drp_arbiter 28 eye_scan_controller 1} {
  set found [get_cells -hier -quiet -filter "REF_NAME =~ ${ref}*"]
  if {[llength $found] != $expected} {error "Routed eye inventory $ref=[llength $found]"}
}
set gt_comparisons 0
foreach c [get_cells -hier -filter {REF_NAME == GTYE4_CHANNEL && IS_PRIMITIVE}] {
  set site [get_property LOC $c]
  foreach {p value} [dict get $baseline_properties $site] {
    if {$p in {ES_EYE_SCAN_EN ES_HORZ_OFFSET}} {continue}
    if {[get_property $p $c] ne $value} {error "Unexpected v3-to-eye GT parameter change $site $p"}
    incr gt_comparisons
  }
  foreach pin {EYESCANRESET RXLPMEN} expected {GROUND POWER} {
    set n [get_nets -of_objects [get_pins $c/$pin]]
    if {[get_property TYPE $n] ne $expected} {error "Unexpected $site/$pin driver"}
  }
}
foreach c [get_cells -hier -quiet -filter {NAME =~ *eye_forward_stage0_reg* && REF_NAME =~ FD*}] {
  if {![regexp {eye_forward_stage0_reg\[([0-9]+)\]$} [get_property NAME $c] -> bit]} {
    error "Cannot classify eye launch boundary $c"
  }
  set expected [expr {$bit < 64 ? 10.0 : 5.0}]
  set p [get_timing_paths -quiet -to [get_pins $c/D] -max_paths 1]
  if {[llength $p] != 1 || [get_property SLACK $p] < 0 ||
      abs([get_property REQUIREMENT $p]-$expected)>0.001} {error "Wrong eye launch timing contract $c"}
}
set checked_returns 0
foreach c [get_cells -hier -quiet -filter {
  NAME =~ *g_eye_return*.u_return/stage_one_reg* || NAME =~ *g_eye_return*.u_return/stage_two_reg*}] {
  set p [get_timing_paths -quiet -to [get_pins $c/D] -max_paths 1]
  if {[llength $p] != 1 || [get_property SLACK $p] < 0 ||
      abs([get_property REQUIREMENT $p]-5.0)>0.001} {error "Eye return lacks ordinary one-cycle timing: $c"}
  incr checked_returns
}
if {$checked_returns < 512} {error "Missing routed eye return stages"}
set status_roots [get_cells -hier -quiet -filter {NAME =~ *g_status_return*.u_return && IS_PRIMITIVE == 0}]
if {[llength $status_roots] != 4} {error "Missing four matched status return roots"}
set checked_status 0
foreach c [get_cells -hier -quiet -filter {
  (NAME =~ *g_status_return*.u_return/stage_one_reg* ||
   NAME =~ *g_status_return*.u_return/stage_two_reg*) && REF_NAME =~ FD*}] {
  set p [get_timing_paths -quiet -to [get_pins $c/D] -max_paths 1]
  if {[llength $p] != 1 || [get_property SLACK $p] < 0 ||
      abs([get_property REQUIREMENT $p]-5.0)>0.001} {error "Status return lacks ordinary one-cycle timing: $c"}
  incr checked_status
}
if {$checked_status < 512} {error "Missing matched status/diagnostic return stages"}
set queued_launches [get_cells -hier -quiet -filter {NAME =~ *u_eye_drp/launch_pending_reg && REF_NAME =~ FD*}]
if {[llength $queued_launches] != 28} {error "Missing routed queued DRP launch boundaries"}
source [file join $script_dir check_eye_scan_drp_boundary.tcl]
puts "PASS: matched status returns=$checked_status, queued DRP launches=28, no combinational GT-to-eye ready path"
puts "PASS: eye-specific independent audit; GT comparisons=$gt_comparisons, timed returns=$checked_returns"
if {[file exists $marker]} {error "Refusing existing eye audit marker"}
set f [open $marker {WRONLY CREAT EXCL}]
puts $f "identity=0x00020503"
puts $f "candidate=[file normalize $candidate]"
puts $f "sha256=[lindex [exec sha256sum $candidate] 0]"
close $f
puts "PASS: independent eye v1 audit, dynamic TX electrical idle and per-lane rearm"
