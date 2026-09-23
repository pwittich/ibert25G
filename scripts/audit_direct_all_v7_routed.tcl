set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set name gt_test_direct_all_v7r3
set project_dir [file join $repo_dir build $name]
set candidate [file join $project_dir ${name}_routed.dcp]
set golden [file join $repo_dir build gt_test_milestone3_v15 \
  gt_test_milestone3_v15.runs impl_1 gt_test_milestone3_top_routed.dcp]
set report_dir [file join $repo_dir build direct_all_v7_audit]
file mkdir $report_dir
foreach f [list $candidate $golden] {if {![file isfile $f]} {error "Missing checkpoint $f"}}

open_project [file join $project_dir ${name}.xpr]
if {[get_property TOP [get_filesets sources_1]] ne "gt_test_direct_all_v7_top"} {error "Wrong v7 project top"}
report_ip_status -file [file join $report_dir ip_status.rpt]
foreach ip [get_ips -quiet] {if {[get_property IS_LOCKED $ip]} {error "Locked IP $ip"}}
close_project

proc direct_all_v7_metadata_property {property} {
  # Cell/module/file names necessarily differ between the full-IBERT and the
  # managed-Wizard hierarchies; none is a primitive configuration property.
  if {[string match "*NAME*" $property]} {return 1}
  if {$property in {CLASS FILE_NAME FILE_NAMES FULL_NAME ID IS_REUSED LINE_NUMBER NAME OPT_MODIFIED PARENT PBLOCK
                    REUSE_STATUS TOOL_DERIVED_CLK_NAMES UUID XILINX_JEP106_ID
                    XILINX_REPORT_XFORM PORT_SELECT PORTS SWITCH_SELECT is_du_within_envelope
                    msgon syn_noprune}} {return 1}
  if {[string match "LC_*" $property] || [string match "P_*" $property]} {return 1}
  return 0
}

# Capture every readable golden primitive property at each of the 56 physical
# sites.  The comparison below uses the intersection of properties exposed on
# both implementation styles and excludes only connection/tool metadata.
open_checkpoint $golden
set golden_properties [dict create]
for {set y 4} {$y <= 59} {incr y} {
  set site GTYE4_CHANNEL_X1Y$y
  set cell [get_cells -hier -filter "REF_NAME == GTYE4_CHANNEL && LOC == $site"]
  if {[llength $cell] != 1} {error "Golden checkpoint lacks exactly one $site"}
  set values [dict create]
  foreach property [list_property $cell] {
    if {![catch {get_property $property $cell} value]} {dict set values $property $value}
  }
  dict set golden_properties $site $values
}
close_design

open_checkpoint $candidate
if {[get_property PART [current_design]] ne "xcvu13p-flga2577-2-e"} {error "Wrong part"}
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {error "Compression disabled"}
set cleanup_controllers [get_cells -hier -quiet -filter {REF_NAME =~ gt_prbs_test_controller*}]
set cleanup_wizard [get_cells -hier -quiet -filter {
  NAME =~ *cleanup_wizard_reset_seen* && REF_NAME =~ FD*}]
set cleanup_lanes [get_cells -hier -quiet -filter {
  NAME =~ *cleanup_lane_reset_seen* && REF_NAME =~ FD*}]
set cleanup_idle_guards [get_cells -hier -quiet -filter {
  NAME =~ *post_cleanup_idle_guard* && REF_NAME =~ FD*}]
set session_meta [get_cells -hier -quiet -filter {
  NAME =~ *session_meta_reg && REF_NAME =~ FD*}]
set session_sync [get_cells -hier -quiet -filter {
  NAME =~ *session_sync_reg && REF_NAME =~ FD*}]
set session_applied_meta [get_cells -hier -quiet -filter {
  NAME =~ *session_applied_meta_reg && REF_NAME =~ FD*}]
set session_applied_sync [get_cells -hier -quiet -filter {
  NAME =~ *session_applied_sync_reg && REF_NAME =~ FD*}]
if {[llength $cleanup_controllers] != 14 || [llength $cleanup_wizard] != 14 ||
    [llength $cleanup_lanes] != 56 || [llength $cleanup_idle_guards] != 14 ||
    [llength $session_meta] != 14 || [llength $session_sync] != 14 ||
    [llength $session_applied_meta] != 14 ||
    [llength $session_applied_sync] != 14} {
  error "Cleanup structure mismatch: controllers=[llength $cleanup_controllers] wizard=[llength $cleanup_wizard] lanes=[llength $cleanup_lanes] idle_guards=[llength $cleanup_idle_guards]"
}
foreach c [concat $session_meta $session_sync $session_applied_meta $session_applied_sync] {
  if {![get_property ASYNC_REG $c]} {error "Unmarked TX-session synchronizer $c"}
}
puts "DIRECT_ALL_V7_CLEANUP: 14 Wizard and 56 lane acknowledgements plus 14 post-cleanup IDLE guards present"
puts "DIRECT_ALL_V7_SESSION: 14 TX-domain request pairs and 14 management-domain applied-ack pairs present"
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
foreach v [get_drc_violations -quiet] {if {[get_property SEVERITY $v] eq "Error"} {error "DRC error $v"}}
if {[llength [get_methodology_violations -quiet -filter {NAME =~ TIMING-17* || NAME =~ TIMING-26*}]]} {
  error "Missing sequential or GT clocks"
}

set channels [get_cells -hier -filter {REF_NAME == GTYE4_CHANNEL && IS_PRIMITIVE}]
set commons [get_cells -hier -filter {REF_NAME == GTYE4_COMMON && IS_PRIMITIVE}]
if {[llength $channels] != 56 || [llength $commons] != 14} {error "GT ownership is not exactly 56 channels/14 commons"}
set expected_channels {}; for {set y 4} {$y <= 59} {incr y} {lappend expected_channels GTYE4_CHANNEL_X1Y$y}
set expected_commons {}; for {set y 1} {$y <= 14} {incr y} {lappend expected_commons GTYE4_COMMON_X1Y$y}
set actual_channels {}; foreach c $channels {lappend actual_channels [get_property LOC $c]}
set actual_commons {}; foreach c $commons {lappend actual_commons [get_property LOC $c]}
if {[lsort $actual_channels] ne [lsort $expected_channels] ||
    [lsort $actual_commons] ne [lsort $expected_commons]} {error "Routed GT site ownership mismatch"}

set property_report [open [file join $report_dir golden_channel_properties.rpt] w]
set compared_total 0
set mismatch_total 0
foreach site $expected_channels {
  set cell [get_cells -hier -filter "REF_NAME == GTYE4_CHANNEL && LOC == $site"]
  set candidate_values [dict create]
  foreach property [list_property $cell] {
    if {![catch {get_property $property $cell} value]} {dict set candidate_values $property $value}
  }
  set golden_values [dict get $golden_properties $site]
  set compared 0
  foreach property [dict keys $golden_values] {
    if {[direct_all_v7_metadata_property $property] || ![dict exists $candidate_values $property]} {continue}
    incr compared
    if {[dict get $candidate_values $property] ne [dict get $golden_values $property]} {
      puts $property_report "DIFF $site $property candidate={[dict get $candidate_values $property]} golden={[dict get $golden_values $property]}"
      incr mismatch_total
    }
  }
  if {$compared < 1000} {close $property_report; error "Only $compared shared non-metadata properties compared at $site"}
  incr compared_total $compared
  puts $property_report "PASS $site properties=$compared"
}
puts $property_report "mismatch_total=$mismatch_total"
puts $property_report "PASS total_property_comparisons=$compared_total"
close $property_report
if {$mismatch_total != 0} {error "$mismatch_total golden non-metadata property mismatches; see golden_channel_properties.rpt"}

# Prove each common consumes the intended local/south/north dedicated route
# from the connector group's physical REFCLK0 input, without a fabric clock.
# The channels select QPLL0, so their primitive REFCLK pins are intentionally
# unused; prove both QPLL0 clock inputs of all four channels are driven directly
# by the corresponding common's hard-macro outputs.
set modes {south local north local south local north south local north local south local north}
set refs {n n n p b b b e e e g i i i}
set ref_report [open [file join $report_dir dedicated_refclk_routes.rpt] w]
for {set q 0} {$q < 14} {incr q} {
  set mode [lindex $modes $q]
  set ref [lindex $refs $q]
  set common_pin [expr {$mode eq "local" ? "GTREFCLK00" : ($mode eq "south" ? "GTSOUTHREFCLK00" : "GTNORTHREFCLK00")}]
  set common_site GTYE4_COMMON_X1Y[expr {$q+1}]
  set common [get_cells -hier -filter "REF_NAME == GTYE4_COMMON && LOC == $common_site"]
  set pin [get_pins -of_objects $common -filter "REF_PIN_NAME == $common_pin"]
  if {[llength $pin] != 1} {error "$common_site lacks exact dedicated $common_pin"}
  set sources [all_fanin -flat -startpoints_only -to $pin]
  set expected_port p_rt_r0_$ref
  if {[lsearch -exact $sources $expected_port] < 0} {error "$common_site/$common_pin is not sourced by $expected_port: $sources"}
  foreach fanin_cell [all_fanin -flat -only_cells -to $pin] {
    set fanin_ref [get_property REF_NAME $fanin_cell]
    if {$fanin_ref ni {IBUFDS_GTE4 GTYE4_COMMON}} {
      error "Fabric/unexpected element in dedicated REFCLK route to $common_site: $fanin_cell ($fanin_ref)"
    }
  }
  puts $ref_report "$common_site $common_pin <- $expected_port"
  for {set lane 0} {$lane < 4} {incr lane} {
    set channel_site GTYE4_CHANNEL_X1Y[expr {4+4*$q+$lane}]
    set channel [get_cells -hier -filter "REF_NAME == GTYE4_CHANNEL && LOC == $channel_site"]
    foreach {channel_pin common_pin_out} {QPLL0CLK QPLL0OUTCLK QPLL0REFCLK QPLL0OUTREFCLK} {
      set sink [get_pins -of_objects $channel -filter "REF_PIN_NAME == $channel_pin"]
      set net [get_nets -of_objects $sink]
      set drivers [get_pins -quiet -leaf -of_objects $net -filter {DIRECTION == OUT}]
      set expected_driver [get_pins -of_objects $common -filter "REF_PIN_NAME == $common_pin_out"]
      if {[llength $sink] != 1 || [llength $net] != 1 || [llength $expected_driver] != 1 ||
          [llength $drivers] != 1 || [lindex $drivers 0] ne [lindex $expected_driver 0]} {
        error "$channel_site/$channel_pin is not driven only by $common_site/$common_pin_out: $drivers"
      }
      puts $ref_report "$channel_site $channel_pin <- $common_site/$common_pin_out"
    }
  }
}
close $ref_report

set descriptors [get_pins -hier -filter {
  NAME =~ */g_lane*.g_managed.u_lane/selected_meta_reg/D ||
  NAME =~ */g_lane*.g_managed.u_lane/prbs_meta_reg*/D}]
if {[llength $descriptors] != 224} {error "Descriptor endpoint count [llength $descriptors], expected 224"}
foreach pin $descriptors {
  set path [get_timing_paths -quiet -from [get_clocks clk_200] -to $pin -max_paths 1]
  if {[llength $path] != 1 || [get_property SLACK $path] < 0 ||
      abs([get_property REQUIREMENT $path]-3.000) > 0.001} {error "Descriptor timing failure: $pin"}
}
set skew [report_bus_skew -return_string -file [file join $report_dir bus_skew.rpt]]
if {[regexp -all {Slack \(MET\)} $skew] != 14 || [string match {*VIOLATED*} $skew]} {
  error "Expected exactly fourteen passing descriptor bus-skew constraints"
}

foreach period {5.000 10.000 3.077} {
  set found 0
  foreach c [get_clocks] {if {abs([get_property PERIOD $c] - $period) < 0.001} {set found 1}}
  if {!$found} {error "Missing required monitor period $period"}
}
puts "PASS: independent all-direct v7 routed audit; 56 golden-matched channels, 14 dedicated common refclk routes, 112 common-to-channel QPLL0 connections"
