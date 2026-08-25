set script_dir [file dirname [file normalize [info script]]]
set repo_dir   [file dirname $script_dir]
set project    [file join $repo_dir build vu13p_ibert_25g.xpr]

open_project $project
open_run impl_1

set common [get_cells u_ibert/u_ibert_left/u_ibert_gty_core/inst/QUAD0.u_q/u_common/u_gtye4_common]
foreach port {SDM0WIDTH SDM0DATA} {
  puts "\n$port drivers:"
  foreach pin [get_pins -quiet -of_objects $common -filter "REF_PIN_NAME =~ ${port}*"] {
    set net [get_nets -quiet -of_objects $pin]
    set drivers [get_pins -quiet -leaf -of_objects $net -filter {DIRECTION == OUT}]
    puts "  $pin <- $drivers"
  }
}

set drpclk [get_pins $common/DRPCLK]
puts "\nDRPCLK clocks: [get_clocks -quiet -of_objects $drpclk]"
foreach clock [get_clocks -quiet -of_objects $drpclk] {
  puts "  $clock: period=[get_property PERIOD $clock] source=[get_property SOURCE_PINS $clock]"
}

puts "\nTesting pre-place floorplan hook in memory:"
source [file join $script_dir apply_ibert_floorplan.tcl]
puts "Total IBERT pblocks: [llength [get_pblocks -quiet]]"
