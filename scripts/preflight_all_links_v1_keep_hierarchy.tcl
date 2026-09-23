set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set dcp [file join $repo_dir build gt_test_all_links_v1 gt_test_all_links_v1_synth.dcp]
set elf [file join $repo_dir build firmware_all_links_v1 gt_test_all_links_v1.elf]
set report_dir [file join $repo_dir build all_links_v1_reports keep_hierarchy]
foreach f [list $dcp $elf] {if {![file isfile $f]} {error "Missing $f"}}
file mkdir $report_dir
open_checkpoint $dcp
set ::all_links_v1_checkpoint_resume 1
source [file join $script_dir apply_all_links_v1_constraints.tcl]

set out [open [file join $report_dir locality_preflight.rpt] w]
set expected_by_family [dict create controller {6 8 8 6} engine {24 32 32 24} \
  pwrgood {24 32 32 24} reducer {1 1 1 1}]
set seen [dict create]
set root_union [dict create]
for {set slr 0} {$slr < 4} {incr slr} {
  set pb [get_pblocks all_links_v1_kh_locality_slr$slr]
  set roots [get_cells -quiet -of_objects $pb]
  set expected_total [lindex {55 73 73 55} $slr]
  if {[llength $roots] != $expected_total} {
    close $out; error "SLR$slr locality roots [llength $roots], expected $expected_total"
  }
  foreach root $roots {
    set name [get_property NAME $root]
    set ref [get_property REF_NAME $root]
    if {[dict exists $root_union $name]} {close $out; error "Overlapping root $name"}
    dict set root_union $name $slr
    if {[string match gt_prbs_test_controller* $ref]} {
      set family controller
      if {![string equal -nocase [get_property KEEP_HIERARCHY $root] yes] &&
          ![string equal -nocase [get_property KEEP_HIERARCHY $root] true]} {
        close $out; error "Unpreserved controller root $name"
      }
      if {[string equal -nocase [get_property DONT_TOUCH $root] true] ||
          [string equal -nocase [get_property DONT_TOUCH $root] yes]} {
        close $out; error "Controller DONT_TOUCH $name"
      }
    } elseif {[string match gt_lane_engine* $ref]} {
      set family engine
    } elseif {[string match direct_all_v7_quad_group_aggregate* $ref] &&
              [string match *u_quad_aggregate/g_slr* $name]} {
      set family reducer
    } elseif {[string match *gen_pwrgood_delay_inst*.delay_powergood_inst $name]} {
      set family pwrgood
    } else {
      close $out; error "Unexpected locality root $name ($ref)"
    }
    dict incr seen "$family,$slr"
  }
}
foreach family {controller engine pwrgood reducer} {
  for {set slr 0} {$slr < 4} {incr slr} {
    set actual 0
    if {[dict exists $seen "$family,$slr"]} {set actual [dict get $seen "$family,$slr"]}
    set expected [lindex [dict get $expected_by_family $family] $slr]
    if {$actual != $expected} {close $out; error "$family SLR$slr $actual, expected $expected"}
    puts $out "$family SLR$slr roots $actual"
  }
}
foreach pattern {all_links_v1_quads_slr* all_links_v1_locality_slr*} {
  if {[llength [get_pblocks -quiet $pattern]]} {close $out; error "Stale pblocks $pattern"}
}
if {[llength [get_pblocks -quiet *copy*]]} {close $out; error "Unexpected result-copy pblock"}
foreach root [get_cells -quiet -of_objects [get_pblocks all_links_v1_kh_locality_slr*]] {
  set ref [get_property REF_NAME $root]
  if {[string match GTYE4_* $ref] || [string match BUFG* $ref] ||
      [string match IBUFDS_GTE4 $ref] || [string match *reset* [string tolower $ref]] ||
      [string match *session* [string tolower [get_property NAME $root]]]} {
    close $out; error "Excluded family entered locality pblock: $root ($ref)"
  }
}
set channels [get_cells -hier -quiet -filter {REF_NAME == GTYE4_CHANNEL && IS_PRIMITIVE}]
set commons [get_cells -hier -quiet -filter {REF_NAME == GTYE4_COMMON && IS_PRIMITIVE}]
set refclks [get_cells -hier -quiet -filter {REF_NAME == IBUFDS_GTE4 && IS_PRIMITIVE && NAME =~ *u_refclk_buffers*}]
set engines [get_cells -hier -quiet -filter {REF_NAME =~ gt_lane_engine*}]
set controllers [get_cells -hier -quiet -filter {REF_NAME =~ gt_prbs_test_controller*}]
if {[llength $channels] != 112 || [llength $commons] != 28 || [llength $refclks] != 12 ||
    [llength $engines] != 112 || [llength $controllers] != 28} {
  close $out; error "Inventory channels/commons/refclks/engines/controllers=[llength $channels]/[llength $commons]/[llength $refclks]/[llength $engines]/[llength $controllers]"
}
set skew [report_bus_skew -warn_on_violation -return_string \
  -file [file join $report_dir bus_skew_preflight.rpt]]
set skew_groups [regexp -all {Slack \(MET\)|Slack \(VIOLATED\)} $skew]
if {$skew_groups != 28} {close $out; error "Bus-skew groups $skew_groups, expected 28"}
puts $out "root union [dict size $root_union]; expected 256"
puts $out "channels/commons/refclks/engines/controllers 112/28/12/112/28"
puts $out "bus-skew groups 28"
puts $out "synth DCP SHA-256 [lindex [split [exec sha256sum $dcp]] 0]"
puts $out "ELF SHA-256 [lindex [split [exec sha256sum $elf]] 0]"
puts $out "PASS: exact KEEP_HIERARCHY locality preflight"
close $out
if {[dict size $root_union] != 256} {error "Root union [dict size $root_union], expected 256"}
puts "PASS: exact all-links v1 KEEP_HIERARCHY locality preflight"
