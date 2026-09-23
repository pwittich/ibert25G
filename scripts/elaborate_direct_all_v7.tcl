set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set name gt_test_direct_all_v7r3
open_project [file join $repo_dir build $name ${name}.xpr]
if {[get_property TOP [get_filesets sources_1]] ne "gt_test_direct_all_v7_top"} {error "Wrong v7 top"}
set external_elfs {}
foreach f [get_files -all -quiet *.elf] {if {![get_property IS_GENERATED $f]} {lappend external_elfs $f}}
if {[llength $external_elfs] != 1 || ![string match *firmware_direct_all_v7/gt_test_direct_all_v7.elf [file normalize [lindex $external_elfs 0]]]} {
  error "Wrong v7 ELF association: $external_elfs"
}
synth_design -rtl -rtl_skip_mlo -name direct_all_v7_rtl
set firefly_ports [get_ports -quiet -filter {NAME =~ *_ff*}]
if {[llength $firefly_ports] != 0} {error "All-direct top exposes legacy FireFly ports: $firefly_ports"}
set wrappers [get_cells -hier -filter {REF_NAME =~ managed_direct_quad_v6_wrapper*}]
if {[llength $wrappers] != 14} {error "Expected fourteen reachable managed quad wrappers, got [llength $wrappers]"}
set channels [get_cells -hier -filter {REF_NAME == GTYE4_CHANNEL}]
set commons [get_cells -hier -filter {REF_NAME == GTYE4_COMMON}]
if {[llength $channels] != 56 || [llength $commons] != 14} {
  error "Elaborated GT ownership is [llength $channels] channels/[llength $commons] commons"
}
# Verify every common and channel uses the intended physical input without a
# fabric logic element in its REFCLK fan-in.  The wrapper transform separately
# proves QPLL0REFCLKSEL=local/south/north is exactly 1/3/5.
foreach {quad route ref} {
  221 south n 222 local n 223 north n 224 local p
  225 south b 226 local b 227 north b
  228 south e 229 local e 230 north e 231 local g
  232 south i 233 local i 234 north i
} {
  set common [get_cells -hier -filter "REF_NAME == GTYE4_COMMON && NAME =~ *g_v7_q${quad}.u_gt/*"]
  set qchannels [get_cells -hier -filter "REF_NAME == GTYE4_CHANNEL && NAME =~ *g_v7_q${quad}.u_gt/*"]
  if {[llength $common] != 1 || [llength $qchannels] != 4} {
    error "q$quad elaborated ownership is [llength $qchannels] channels/[llength $common] commons"
  }
  if {$route eq "south"} {set common_pin GTSOUTHREFCLK00}
  if {$route eq "local"} {set common_pin GTREFCLK00}
  if {$route eq "north"} {set common_pin GTNORTHREFCLK00}
  # QPLL0 is the selected PLL.  Therefore only the COMMON reference input is
  # live in the elaborated netlist; the generated per-channel refclk ports are
  # intentionally unused even though the exact wrapper transform also sets
  # them consistently for south/north topology.
  set sinks [list [get_pins $common/$common_pin]]
  foreach sink $sinks {
    set starts [all_fanin -flat -startpoints_only -to $sink]
    if {[lsearch -exact $starts p_rt_r0_${ref}] < 0} {error "q$quad $sink does not originate at p_rt_r0_$ref: $starts"}
    foreach c [all_fanin -flat -only_cells -to $sink] {
      set r [get_property REF_NAME $c]
      if {$r ni {IBUFDS_GTE4 GTYE4_COMMON GTYE4_CHANNEL}} {
        error "q$quad REFCLK fan-in contains fabric/non-input cell $c ($r)"
      }
    }
  }
}
set topology_cells [get_cells -hier -filter {REF_NAME =~ direct_all_v7_q*_gt_topology}]
set refs [lsort -unique [get_property REF_NAME $topology_cells]]
foreach quad {221 222 223 224 225 226 227 228 229 230 231 232 233 234} {
  if {[lsearch -exact $refs direct_all_v7_q${quad}_gt_topology] < 0} {error "q$quad generated hierarchy is unreachable"}
}
puts "PASS: v7 project RTL elaborates; fourteen managed/generated quads expose 56 channels/14 commons and use six fabric-free dedicated REFCLK groups"
