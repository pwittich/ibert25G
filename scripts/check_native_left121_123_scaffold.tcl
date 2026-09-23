# Static pre-build gate for the FireFly-1 native three-core experiment.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
source [file join $script_dir native_left121_123_config.tcl]
set project [file join $repo_dir build gt_native_left121_123_threecore_ip_v1 \
  gt_native_left121_123_threecore_ip.xpr]
if {![file exists $project]} { error "Missing FireFly-1 IP project: $project" }
open_project $project
foreach {quad channels master} {
  121 {X0Y4 X0Y5 X0Y6 X0Y7} X0Y4
  122 {X0Y8 X0Y9 X0Y10 X0Y11} X0Y8
  123 {X0Y12 X0Y13 X0Y14 X0Y15} X0Y12
} {
  set ip [get_ips native_left${quad}_gt]
  if {[llength $ip] != 1} { error "Missing q$quad Wizard" }
  foreach {property expected} [list \
    CONFIG.CHANNEL_ENABLE $channels CONFIG.TX_MASTER_CHANNEL $master \
    CONFIG.RX_MASTER_CHANNEL $master CONFIG.TX_LINE_RATE 25.78125 \
    CONFIG.RX_LINE_RATE 25.78125 CONFIG.TX_REFCLK_FREQUENCY 322.265625 \
    CONFIG.RX_REFCLK_FREQUENCY 322.265625 CONFIG.TX_PLL_TYPE QPLL0 \
    CONFIG.RX_PLL_TYPE QPLL0 CONFIG.TX_USER_DATA_WIDTH 80 \
    CONFIG.RX_USER_DATA_WIDTH 80] {
    set actual [get_property $property $ip]
    if {$actual ne $expected} { error "q$quad $property=$actual, expected $expected" }
  }
}
puts "PASS: FireFly-1 q121/q122/q123 Wizard scaffold matches baseline rate/PLL/width/site plan"
close_project
