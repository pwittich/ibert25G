# Syntax and generated-IP topology gate before project synthesis.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set work [file join $repo_dir build direct_all_v7_syntax]
file mkdir $work
cd $work
set sources {}
foreach name {
  managed_direct_quad_v6_wrapper direct_quad_v6_refclk_buffers direct_all_v7_quad_aggregate
  gt_test_direct_quad_v6_core gt_test_direct_all_v7_top
} {lappend sources [file join $repo_dir src ${name}.sv]}
foreach f [glob -nocomplain [file join $repo_dir build direct_all_v7_topology_wrappers *_topology.v]] {
  lappend sources $f
}
puts [exec xvlog -sv {*}$sources]

set ip_project [file join $repo_dir build direct_all_v7_ip direct_all_v7_ip.xpr]
open_project $ip_project
set channel_total 0
set common_total 0
foreach quad {221 222 223 224 225 226 227 228 229 230 231 232 233 234} {
  set ip [get_ips direct_all_v7_q${quad}_gt]
  if {[llength $ip] != 1 || [get_property IS_LOCKED $ip]} {error "Missing or locked q$quad IP"}
  set enabled [get_property CONFIG.CHANNEL_ENABLE $ip]
  if {[llength $enabled] != 4} {error "q$quad does not own four channels: $enabled"}
  incr channel_total [llength $enabled]
  incr common_total
  set expected {}
  set first [expr {4 * ($quad - 220)}]
  for {set y $first} {$y < $first + 4} {incr y} {lappend expected X1Y$y}
  if {[lsort $enabled] ne [lsort $expected]} {error "q$quad channel ownership mismatch: $enabled"}
}
if {$channel_total != 56 || $common_total != 14} {error "Expected 56 channels/14 commons"}
close_project

set core_chan [open [file join $repo_dir src gt_test_direct_quad_v6_core.sv] r]
set core [read $core_chan]
close $core_chan
set top_chan [open [file join $repo_dir src gt_test_direct_all_v7_top.sv] r]
set top_text [read $top_chan]
close $top_chan
if {![regexp {ALL_DIRECT_V7\(1'b1\)} $top_text] ||
    ![regexp {for \(genvar q = 0; q < 14; q\+\+\)} $core] ||
    ![regexp {localparam integer QUAD = 221 \+ q} $core]} {
  error "Selected v7 top does not reach the fourteen q221-q234 wrappers"
}
foreach ref {n p b e g i} {
  if {![regexp "p_rt_r0_${ref}" $core] || ![regexp "n_rt_r0_${ref}" $core]} {
    error "Missing refclk group $ref"
  }
}
if {[regexp {u_ibert_(left|right)} $core]} {error "Legacy IBERT ownership leaked into selected core"}
puts "PASS: v7 RTL syntax; reachable q221-q234 wrappers; 56 generated channels, 14 commons, six refclk groups; no legacy IBERT"
