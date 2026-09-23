set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
if {![info exists endpoint] || $endpoint ni {1 2}} {error "endpoint must be 1 or 2"}
set name gt_test_direct_quad_v6_f${endpoint}
set p [file join $repo_dir build $name]
set report_dir [file join $repo_dir build ${name}_audit]
file mkdir $report_dir
open_project [file join $p ${name}.xpr]
if {[get_property TOP [get_filesets sources_1]] ne "${name}_top"} {error "Wrong endpoint"}
report_ip_status -file [file join $report_dir ip_status.rpt]
foreach ip [get_ips -quiet] {if {[get_property IS_LOCKED $ip]} {error "Locked IP $ip"}}
close_project
open_checkpoint [file join $p ${name}_routed.dcp]
if {[get_property PART [current_design]] ne "xcvu13p-flga2577-2-e"} {error "Wrong part"}
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {error "Compression disabled"}
check_timing -verbose -file [file join $report_dir check_timing.rpt]
report_timing_summary -file [file join $report_dir timing.rpt]
report_route_status -file [file join $report_dir routing.rpt]
report_methodology -file [file join $report_dir methodology.rpt]
report_cdc -details -file [file join $report_dir cdc.rpt]
report_clock_interaction -file [file join $report_dir clock_interaction.rpt]
report_clocks -file [file join $report_dir clocks.rpt]
report_exceptions -coverage -file [file join $report_dir exceptions.rpt]
report_utilization -file [file join $report_dir utilization.rpt]
report_drc -file [file join $report_dir drc.rpt]
if {[llength [get_methodology_violations -quiet -filter {NAME =~ TIMING-17* || NAME =~ TIMING-26*}]]} {error "Missing sequential or GT clocks"}
foreach v [get_drc_violations -quiet] {if {[get_property SEVERITY $v] eq "Error"} {error "DRC error $v"}}
if {![regexp {# of nets with routing errors[. ]*:[ ]*0} [report_route_status -return_string]]} {error "Routing errors"}
if {![string match {*All user specified timing constraints are met.*} [report_timing_summary -return_string]]} {error "Timing failed"}
foreach period {5.000 10.000 3.077} {
  set found 0
  foreach c [get_clocks] {if {abs([get_property PERIOD $c] - $period) < 0.001} {set found 1}}
  if {!$found} {error "Missing monitor period $period"}
}
set channels [get_cells -hier -filter {REF_NAME == GTYE4_CHANNEL && IS_PRIMITIVE}]
set commons [get_cells -hier -filter {REF_NAME == GTYE4_COMMON && IS_PRIMITIVE}]
if {[llength $channels] != 4 || [llength $commons] != 1} {error "Expected exactly four channels and one common"}
set base [expr {$endpoint == 1 ? 8 : 52}]
set common_site [expr {$endpoint == 1 ? "GTYE4_COMMON_X1Y2" : "GTYE4_COMMON_X1Y13"}]
set expected {}; for {set i $base} {$i < $base+4} {incr i} {lappend expected GTYE4_CHANNEL_X1Y$i}
set actual {}; foreach c $channels {lappend actual [get_property LOC $c]}
if {[lsort $actual] ne [lsort $expected] || [get_property LOC $commons] ne $common_site} {error "Endpoint GT ownership mismatch"}
foreach c $channels {
  set golden_rx [expr {$endpoint == 1 ?
    {ADAPT_CFG1 16'hF81C RXCDR_CFG3 16'h0012 RXDFE_GC_CFG2 16'hFFF0 RX_DEGEN_CTRL 3'b100 RX_DFE_AGC_CFG1 2 RX_SUM_DEGEN_AVTT_OVERITE 0 RX_SUM_VCMTUNE 4'b0011} :
    {ADAPT_CFG1 16'hFB1C RXCDR_CFG3 16'h0010 RXDFE_GC_CFG2 16'hFFE0 RX_DEGEN_CTRL 3'b111 RX_DFE_AGC_CFG1 4 RX_SUM_DEGEN_AVTT_OVERITE 1 RX_SUM_VCMTUNE 4'b1001 PCI3_AUTO_REALIGN FRST_SMPL PCIE_PLL_SEL_MODE_GEN4 2'h0 RX_PROGDIV_CFG 20.000 RX_PROGDIV_RATE 16'h0000 RX_WIDEMODE_CDR_GEN3 2'b01 RXCDR_CFG3_GEN2 6'h10 RXCDR_CFG3_GEN3 16'h0010 RXCDR_CFG3_GEN4 16'h0010}}]
  foreach {property value} $golden_rx {
    if {[get_property $property $c] ne $value} {error "Golden RX mismatch: $c $property"}
  }
  foreach pin {RXPOLARITY TXPOLARITY} {if {[get_property TYPE [get_nets -of_objects [get_pins $c/$pin]]] ne "GROUND"} {error "Unexpected polarity"}}
}
set group [expr {$endpoint == 1 ? "n" : "i"}]
set pinlist [expr {$endpoint == 1 ? {BH4 BH3 BG2 BG1 BG6 BG5 BF4 BF3 BG11 BG10 BJ11 BJ10 BH9 BH8 BF9 BF8} : {E2 E1 D4 D3 E6 E5 C6 C5 D9 D8 B9 B8 C11 C10 E11 E10}}]
set index 0
foreach direction {recv xmit} {
  for {set lane 0} {$lane < 4} {incr lane} {
    foreach polarity {p n} {
      set port [format {%s_%s_%s[%d]} $polarity $group $direction $lane]
      if {[get_property PACKAGE_PIN [get_ports $port]] ne [lindex $pinlist $index]} {error "Pin mapping mismatch: $port"}
      incr index
    }
  }
}
set refpins [expr {$endpoint == 1 ? {AY13 AY12} : {N11 N10}}]
foreach polarity {p n} pin $refpins {
  if {[get_property PACKAGE_PIN [get_ports ${polarity}_rt_r0_${group}]] ne $pin} {error "Reference pin mismatch"}
}
set ref_sources [all_fanin -flat -startpoints_only -to [get_pins $commons/GTREFCLK00]]
if {[lsearch -exact $ref_sources p_rt_r0_${group}] < 0} {error "COMMON does not use the endpoint local REFCLK0"}
set desc [get_pins -hier -filter {NAME =~ */g_lane*.g_managed.u_lane/selected_meta_reg/D || NAME =~ */g_lane*.g_managed.u_lane/prbs_meta_reg*/D}]
if {[llength $desc] != 16} {error "Missing descriptor endpoints"}
foreach pin $desc {
  set path [get_timing_paths -quiet -from [get_clocks clk_200] -to $pin -max_paths 1]
  if {[llength $path] != 1 || [get_property SLACK $path] < 0 || abs([get_property REQUIREMENT $path]-3.000)>0.001} {error "Descriptor is untimed or fails: $pin"}
}
report_bus_skew -file [file join $report_dir bus_skew.rpt]
set skew [report_bus_skew -return_string]
if {[regexp -all {Slack \(MET\)} $skew] != 1 || [string match {*VIOLATED*} $skew]} {error "Expected exactly one saved passing descriptor skew constraint"}
foreach {pattern count} {*cleanup_wizard_reset_seen_reg 1 *cleanup_lane_reset_seen_reg* 4 *tx_session_active_reg 1 *session_meta_reg 1 *session_sync_reg 1} {
  if {[llength [get_cells -hier -filter "NAME =~ $pattern && REF_NAME =~ FD*"]] != $count} {error "Structural gate: $pattern"}
}
set session_cells [get_cells -hier -filter {NAME =~ *session_meta_reg || NAME =~ *session_sync_reg}]
set session_clocks {}
foreach c $session_cells {
  if {![get_property ASYNC_REG $c]} {error "Unmarked session synchronizer"}
  foreach clk [get_clocks -quiet -of_objects [get_pins $c/C]] {lappend session_clocks $clk}
}
set session_clocks [lsort -unique $session_clocks]
if {[llength $session_clocks] != 1} {error "Session synchronizers do not share exactly one TX user clock: $session_clocks"}
set descriptor_clocks {}
foreach pin $desc {
  foreach clk [get_clocks -quiet -of_objects [get_pins [get_property PARENT_CELL $pin]/C]] {lappend descriptor_clocks $clk}
}
set descriptor_clocks [lsort -unique $descriptor_clocks]
if {[llength $descriptor_clocks] != 1} {error "Descriptor endpoints do not share exactly one RX user clock: $descriptor_clocks"}
if {$session_clocks eq $descriptor_clocks} {error "TX session synchronizers unexpectedly use the RX descriptor clock"}
if {![string match {*gtwiz_userclk_tx_srcclk_out*} [get_property NAME [lindex $session_clocks 0]]]} {error "Session synchronizer clock is not the GT TX user clock: $session_clocks"}
if {![string match {*gtwiz_userclk_rx_srcclk_out*} [get_property NAME [lindex $descriptor_clocks 0]]]} {error "Descriptor clock is not the GT RX user clock: $descriptor_clocks"}
set resets {}
foreach c [get_cells -hier -filter {NAME =~ *u_lane_reset_policy/reset_pipe_reg* && REF_NAME =~ FD*}] {
  if {[string equal [lindex [split $c /] end] {reset_pipe_reg[1]}]} {lappend resets $c}
}
if {[llength $resets] != 1} {error "Missing final quad reset synchronizer"}
set ends [all_fanout -flat -endpoints_only -from [get_pins [lindex $resets 0]/Q]]
set lanebase [expr {$endpoint == 1 ? 60 : 104}]
for {set lane $lanebase} {$lane < $lanebase+4} {incr lane} {
  set suffix [format {g_lane[%d].g_managed.u_lane/selected_meta_reg/CE} $lane]
  set found 0
  foreach e $ends {if {[string first $suffix $e] >= 0} {set found 1}}
  if {!$found} {error "Reset fanout misses lane $lane"}
}
puts "PASS: v6 F$endpoint independent routed audit; hardware gates not yet executed"
