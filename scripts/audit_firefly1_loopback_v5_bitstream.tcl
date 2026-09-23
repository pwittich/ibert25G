set s [file dirname [file normalize [info script]]]; set r [file dirname $s]
set argc 3
set argv [list [file join $r build gt_test_firefly1_loopback_v5 gt_test_firefly1_loopback_v5.xpr] impl_1 [file join $r build gt_test_firefly1_loopback_v5_timing_skill]]
source [file join $r skills vivado-analyze-timing scripts report-timing-health.tcl]
close_project
set d [file join $r build gt_test_firefly1_loopback_v5 gt_test_firefly1_loopback_v5_routed.dcp]
set report_dir [file join $r build gt_test_firefly1_loopback_v5_audit]
file mkdir $report_dir
open_project [file join $r build gt_test_firefly1_loopback_v5 gt_test_firefly1_loopback_v5.xpr]
report_ip_status -file [file join $report_dir ip_status.rpt]
foreach ip [get_ips -quiet] {
  if {[get_property IS_LOCKED $ip]} {error "locked IP $ip"}
}
close_project
open_checkpoint $d
check_timing -verbose -file [file join $report_dir check_timing.rpt]
report_exceptions -coverage -file [file join $report_dir exception_coverage.rpt]
if {[get_property PART [current_design]] ne "xcvu13p-flga2577-2-e"} {error "wrong part"}
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {error "compression disabled"}
report_timing_summary -file [file join $report_dir timing.rpt]
report_route_status -file [file join $report_dir routing.rpt]
report_methodology -file [file join $report_dir methodology.rpt]
if {[llength [get_methodology_violations -quiet -filter {NAME =~ TIMING-17* || NAME =~ TIMING-26*}]]} {
  error "unclocked sequential logic or GT clocks: reject hardware deployment"
}
report_cdc -details -file [file join $report_dir cdc.rpt]
report_clock_interaction -file [file join $report_dir clock_interaction.rpt]
report_clocks -file [file join $report_dir clocks.rpt]
foreach period {10.000 3.077} {
  set found 0
  foreach clk [get_clocks] {
    if {abs([get_property PERIOD $clk] - $period) < 0.001} {set found 1}
  }
  if {!$found} {error "missing required monitor clock period $period"}
}
report_bus_skew -file [file join $report_dir bus_skew.rpt]
set skew [report_bus_skew -return_string]
if {[regexp -all {Slack \(MET\)} $skew] != 3 || [string match {*VIOLATED*} $skew]} {
  error "expected three passing descriptor bus-skew constraints"
}
set descriptors [get_pins -hier -filter {
  NAME =~ */g_lane*.g_managed.u_lane/selected_meta_reg/D ||
  NAME =~ */g_lane*.g_managed.u_lane/prbs_meta_reg*/D}]
if {[llength $descriptors] != 48} {error "expected 48 timed descriptor endpoints"}
foreach pin $descriptors {
  set path [get_timing_paths -quiet -from [get_clocks clk_200] -to $pin -max_paths 1]
  if {[llength $path] != 1} {error "descriptor excluded from timing: $pin"}
  if {[get_property SLACK $path] < 0 || abs([get_property REQUIREMENT $path] - 3.000) > 0.001} {
    error "descriptor bound failed: $pin"
  }
}
# Placement can replicate descriptor sources after the pre-opt hook. Prove
# skew again using the actual routed drivers of every endpoint, rather than
# relying solely on pre-replication source names in inherited constraints.
foreach clk [get_clocks -filter {NAME =~ GTYE4_CHANNEL_RXOUTCLK*}] {
  set endpoints {}
  foreach pin [get_pins -of_objects [all_registers -clock $clk] -filter {REF_PIN_NAME == D}] {
    if {[lsearch -exact $descriptors $pin] >= 0} {lappend endpoints $pin}
  }
  if {[llength $endpoints] != 16} {error "routed skew proof lacks 16 descriptor endpoints"}
  set sources [all_fanin -flat -startpoints_only -to $endpoints]
  set_bus_skew 3.000 -from $sources -to $endpoints
}
set routed_skew [report_bus_skew -return_string]
report_bus_skew -file [file join $report_dir actual_driver_bus_skew.rpt]
if {[regexp -all {Slack \(MET\)} $routed_skew] < 3 || [string match {*VIOLATED*} $routed_skew]} {
  error "actual routed descriptor driver skew failed"
}
report_utilization -file [file join $report_dir utilization.rpt]
set c [get_cells -hier -filter {REF_NAME == GTYE4_CHANNEL && IS_PRIMITIVE}]
set sites {}; foreach x $c {set q [get_property SITE $x]; if {$q eq ""} {set q [get_property LOC $x]}; if {$q eq ""} {set q [lindex [get_sites -quiet -of_objects $x] 0]}; if {$q ne ""} {lappend sites $q}}
set expected_channels {GTYE4_CHANNEL_X0Y4 GTYE4_CHANNEL_X0Y5 GTYE4_CHANNEL_X0Y6 GTYE4_CHANNEL_X0Y7 GTYE4_CHANNEL_X0Y8 GTYE4_CHANNEL_X0Y9 GTYE4_CHANNEL_X0Y10 GTYE4_CHANNEL_X0Y11 GTYE4_CHANNEL_X0Y12 GTYE4_CHANNEL_X0Y13 GTYE4_CHANNEL_X0Y14 GTYE4_CHANNEL_X0Y15}
if {[lsort -unique $sites] ne [lsort -unique $expected_channels]} {error "FireFly-1 v5 channel ownership failure"}
set cm [get_cells -hier -filter {REF_NAME == GTYE4_COMMON && IS_PRIMITIVE}]
if {[llength $c] != 12 || [llength $cm] != 3} {error "primitive counts differ"}
foreach channel $c {
  foreach {property expected} {
    ADAPT_CFG1 16'hF81C RXCDR_CFG3 16'h0012 RXDFE_GC_CFG2 16'hFFF0
    RX_DEGEN_CTRL 3'b100 RX_DFE_AGC_CFG1 2
    RX_SUM_DEGEN_AVTT_OVERITE 0 RX_SUM_VCMTUNE 4'b0011
  } {
    if {[get_property $property $channel] ne $expected} {error "$channel differs from golden RX property $property"}
  }
  foreach name {RXPOLARITY TXPOLARITY} {
    set pin [get_pins $channel/$name]
    set net [get_nets -of_objects $pin]
    if {[get_property TYPE $net] ne "GROUND"} {error "$channel/$name is not tied low"}
  }
}
set retained [get_cells -hier -filter {NAME =~ *g_firefly1*u_managed_firefly1*g_quad*u_quad*fault_snapshot_valid_reg}]
if {[llength $retained] != 3} {error "missing per-quad first-fault retention"}
set wizard_ack [get_cells -hier -filter {NAME =~ *g_firefly1*u_prbs_test_controller/cleanup_wizard_reset_seen_reg}]
set lane_ack [get_cells -hier -filter {NAME =~ *g_firefly1*u_prbs_test_controller/cleanup_lane_reset_seen_reg*}]
if {[llength $wizard_ack] != 3 || [llength $lane_ack] != 12} {
  error "missing explicit Wizard/per-lane cleanup reset acknowledgement"
}
if {[llength [get_clocks -filter {NAME =~ GTYE4_CHANNEL_RXOUTCLK*}]] != 3} {error "missing active RX user clocks"}
set common_sites {}; foreach x $cm {set q [get_property LOC $x]; if {$q eq ""} {set q [lindex [get_sites -quiet -of_objects $x] 0]}; if {$q ne ""} {lappend common_sites $q}}
if {[lsort -unique $common_sites] ne {GTYE4_COMMON_X0Y1 GTYE4_COMMON_X0Y2 GTYE4_COMMON_X0Y3}} {error "FireFly-1 v5 COMMON ownership failure"}
set rt [report_route_status -return_string]; if {![regexp {# of nets with routing errors[. ]*:[ ]*0} $rt]} {error "routing errors"}
set t [report_timing_summary -return_string]; if {![string match {*All user specified timing constraints are met.*} $t]} {error "timing failed"}
report_drc
report_drc -file [file join $report_dir drc.rpt]
foreach v [get_drc_violations -quiet] {if {[get_property SEVERITY $v] eq "Error"} {error "DRC error $v"}}
puts "PASS: FireFly-1 v5 staged-acquisition routed audit"

set sessions [get_cells -hier -filter {NAME =~ *u_core/tx_session_active_reg}]
if {[llength $sessions] != 1} {error "missing TX session register"}
set syncs [get_cells -hier -filter {NAME =~ *u_quad/session_meta_reg || NAME =~ *u_quad/session_sync_reg}]
if {[llength $syncs] != 6} {error "missing six TX-domain session synchronizer registers"}
foreach cell $syncs {if {![get_property ASYNC_REG $cell]} {error "session CDC not marked ASYNC_REG"}}
foreach cell $syncs {
  set clocks [get_clocks -of_objects [get_pins $cell/C]]
  if {[llength $clocks] != 1 || ![string match *TXOUTCLK* [get_property NAME $clocks]]} {
    error "session synchronizer is not TX-clocked: $cell"
  }
}
set session_clock [get_clocks -of_objects [get_pins [lindex $sessions 0]/C]]
if {[get_property NAME $session_clock] ne "clk_200"} {error "session watchdog not management-clocked"}
foreach pattern {*session_remaining_ms_reg* *session_tick_reg*} {
  set counters [get_cells -hier -filter "NAME =~ $pattern && REF_NAME =~ FD*"]
  if {[llength $counters] < 1} {error "missing watchdog counter $pattern"}
  foreach cell $counters {
    if {[get_property NAME [get_clocks -of_objects [get_pins $cell/C]]] ne "clk_200"} {
      error "watchdog counter depends on a non-management clock: $cell"
    }
  }
}
foreach cell [get_cells -hier -filter {NAME =~ *u_quad/session_meta_reg}] {
  set drivers [all_fanin -flat -startpoints_only -to [get_pins $cell/D]]
  foreach p $drivers {if {[string match {*g_lane*} $p]} {error "TX session illegally depends on RX lane state"}}
}
puts "PASS: v5 independent TX session structure"
for {set q 0} {$q < 3} {incr q} {
  # Hierarchical rx_reset pins are flattened. Check actual sequential
  # endpoints reached by each quad's final reset synchronizer stage.
  set source {}
  set suffix [format {g_quad[%d].u_quad/u_lane_reset_policy/reset_pipe_reg[1]} $q]
  foreach cell [get_cells -hier -filter {NAME =~ *u_lane_reset_policy/reset_pipe_reg* && REF_NAME =~ FD*}] {
    if {[string first $suffix $cell] >= 0} {lappend source $cell}
  }
  if {[llength $source] != 1} {error "missing quad $q final reset register"}
  set endpoints [all_fanout -flat -endpoints_only -from [get_pins [lindex $source 0]/Q]]
  set actual_lanes {}
  foreach pin $endpoints {
    if {[regexp {g_lane\[([0-9]+)\]\.g_managed\.u_lane/} $pin -> n]} {
      lappend actual_lanes $n
    }
  }
  set expected_lanes {}
  for {set lane [expr {$q*4}]} {$lane < ($q+1)*4} {incr lane} {
    lappend expected_lanes $lane
    set endpoint [format {u_isolated/u_engine/u_core/g_lane[%d].g_managed.u_lane/selected_meta_reg/CE} $lane]
    if {[lsearch -exact $endpoints $endpoint] < 0} {
      error "quad $q reset does not reach lane $lane descriptor freeze enable"
    }
  }
  if {[lsort -integer -unique $actual_lanes] ne $expected_lanes} {error "quad $q reset lane ownership mismatch"}
  puts "RESET_FANOUT quad=$q lanes=$expected_lanes"
}
puts "PASS: v5 reset fan-out reaches all twelve lanes"
