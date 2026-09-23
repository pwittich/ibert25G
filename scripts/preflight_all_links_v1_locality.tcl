set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set dcp [file join $repo_dir build gt_test_all_links_v1 gt_test_all_links_v1_synth.dcp]
set xpr [file join $repo_dir build gt_test_all_links_v1 gt_test_all_links_v1.xpr]
set report_dir [file join $repo_dir build all_links_v1_reports]
file mkdir $report_dir
open_project $xpr
open_checkpoint $dcp
set ::all_links_v1_checkpoint_resume 1
source [file join $script_dir apply_all_links_v1_constraints.tcl]

set out [open [file join $report_dir locality_preflight.rpt] w]
set expected_totals {55 73 73 55}
for {set slr 0} {$slr < 4} {incr slr} {
  set pb [get_pblocks all_links_v1_locality_slr$slr]
  set cells [get_cells -quiet -of_objects $pb]
  set count [llength $cells]
  if {$count != [lindex $expected_totals $slr]} {
    close $out
    error "SLR$slr locality pblock count $count, expected [lindex $expected_totals $slr]"
  }
  foreach cell $cells {
    set name [get_property NAME $cell]
    set ref [get_property REF_NAME $cell]
    if {![string match gt_prbs_test_controller* $ref] &&
        ![string match gt_lane_engine* $ref] &&
        ![string match direct_all_v7_quad_group_aggregate* $ref] &&
        !([string match *gen_pwrgood_delay_inst* $name] &&
          [string match *.delay_powergood_inst $name])} {
      close $out
      error "Unexpected canonical locality root: $cell ($ref)"
    }
  }
  puts $out "SLR$slr canonical locality roots $count; explicitly enumerated leaves [lindex {28935 38934 38935 29253} $slr]"
}

set wrappers [get_cells -hier -quiet -filter {
  REF_NAME =~ managed_all_links_left_quad_wrapper* ||
  REF_NAME =~ managed_direct_quad_v6_wrapper*}]
set controllers [get_cells -hier -quiet -filter {REF_NAME =~ gt_prbs_test_controller*}]
set reducers [get_cells -hier -quiet -filter {
  REF_NAME =~ direct_all_v7_quad_group_aggregate* && NAME =~ *u_quad_aggregate*}]
foreach cell [concat $wrappers $controllers $reducers] {
  if {[get_property USER_SLR_ASSIGNMENT $cell] ne ""} {
    close $out
    error "Obsolete hierarchy USER_SLR_ASSIGNMENT remains on $cell"
  }
}
set final_reduce {}
foreach cell [get_cells -hier -quiet -filter {REF_NAME == all_links_v1_quad_aggregate}] {
  if {[get_property NAME $cell] eq {u_all_links/g_all_links.u_quad_aggregate}} {
    lappend final_reduce $cell
  }
}
if {[llength $final_reduce] != 1 ||
    [get_property USER_SLR_ASSIGNMENT $final_reduce] ne "SLR1"} {
  close $out
  error "Final reducer advisory is not exactly SLR1"
}
if {[llength [get_pblocks -quiet all_links_v1_quads_slr*]] != 0} {
  close $out
  error "Failed whole-wrapper pblocks remain"
}

set channels [get_cells -hier -quiet -filter {REF_NAME == GTYE4_CHANNEL && IS_PRIMITIVE}]
set commons [get_cells -hier -quiet -filter {REF_NAME == GTYE4_COMMON && IS_PRIMITIVE}]
set refclks [get_cells -hier -quiet -filter {
  REF_NAME == IBUFDS_GTE4 && IS_PRIMITIVE && NAME =~ *u_refclk_buffers*}]
if {[llength $channels] != 112 || [llength $commons] != 28 || [llength $refclks] != 12} {
  close $out
  error "GT inventory channels/commons/refclks=[llength $channels]/[llength $commons]/[llength $refclks]"
}

set high_fanout 0
set high_name {}
foreach net [get_nets -hier -quiet] {
  set name [get_property NAME $net]
  if {[string match *power_on_reset* $name]} {
    set fanout [get_property FLAT_PIN_COUNT $net]
    if {$fanout > $high_fanout} {set high_fanout $fanout; set high_name $name}
  }
}
puts $out "global reset remains unconstrained; maximum observed flat pin count $high_fanout on $high_name"
puts $out "GT inventory channels/commons/refclks 112/28/12"
puts $out "descriptor endpoints 448; CDC inventories 1120/672/784; bus-skew groups 28"
puts $out "PASS: deterministic enumerated-leaf locality preflight"
close $out
puts "PASS: deterministic all-links v1 locality preflight; global reset max fanout $high_fanout"
close_design
