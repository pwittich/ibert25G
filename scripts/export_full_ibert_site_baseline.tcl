# Read-only electrical baseline for the existing full mixed-ownership image.
#
# This is an oracle for the all-native migration, not a build or a constraint
# generator.  It opens a routed checkpoint, emits CSV inventories of all GTY
# channel/common sites and their key electrical properties, and does not alter
# the checkpoint or create a project.  The default is the audited full-v15
# checkpoint; override baseline_checkpoint/baseline_output_dir before sourcing
# when comparing another frozen full-image checkpoint.

set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
if {![info exists baseline_checkpoint]} {
  set baseline_checkpoint [file join $repo_dir build gt_test_milestone3_v15 \
    gt_test_milestone3_v15.runs impl_1 gt_test_milestone3_top_routed.dcp]
}
if {![info exists baseline_output_dir]} {
  set baseline_output_dir [file join $repo_dir build full_ibert_site_baseline]
}
if {![file exists $baseline_checkpoint]} {
  error "Full routed checkpoint is missing: $baseline_checkpoint"
}

proc baseline_csv {value} {
  # Keep the output one row per primitive even when Vivado returns a list.
  return "\"[string map [list \" \"\" \n { } \r { }] $value]\""
}

proc baseline_property {object property} {
  if {[catch {get_property $property $object} value]} { return "" }
  return $value
}

proc baseline_csv_row {values} {
  set encoded {}
  foreach value $values { lappend encoded [baseline_csv $value] }
  return [join $encoded ,]
}

proc baseline_owner {cell} {
  set name [get_property NAME $cell]
  if {[string match *u_managed_quad124/* $name]} { return managed_quad124 }
  if {[string match *u_ibert_left/* $name]} { return ibert_left }
  if {[string match *u_ibert_right/* $name]} { return ibert_right }
  return other
}

proc baseline_pin_nets {cell pattern} {
  set pairs {}
  foreach pin [get_pins -quiet -of_objects $cell -filter "REF_PIN_NAME =~ $pattern"] {
    set nets [get_nets -quiet -of_objects $pin]
    lappend pairs "[get_property REF_PIN_NAME $pin]=[join $nets {|}]"
  }
  return [join $pairs {;}]
}

file mkdir $baseline_output_dir
open_checkpoint $baseline_checkpoint

set channels [lsort -dictionary [get_cells -hier -filter {REF_NAME == GTYE4_CHANNEL}]]
set commons [lsort -dictionary [get_cells -hier -filter {REF_NAME == GTYE4_COMMON}]]
if {[llength $channels] != 112 || [llength $commons] != 28} {
  error "Expected 112 GTYE4_CHANNEL and 28 GTYE4_COMMON cells, got [llength $channels] and [llength $commons]"
}

set channel_file [open [file join $baseline_output_dir channels.csv] w]
puts $channel_file "owner,name,site,bel,gtrefclk_nets,qpll_nets,txoutclk_nets,rxoutclk_nets,TXOUT_DIV,RXOUT_DIV,RX_DATA_WIDTH,TX_DATA_WIDTH,ADAPT_CFG1,RXCDR_CFG3,RXDFE_GC_CFG2,RX_DEGEN_CTRL,RX_DFE_AGC_CFG1,RX_SUM_DEGEN_AVTT_OVERITE,RX_SUM_VCMTUNE"
foreach cell $channels {
  set values [list [baseline_owner $cell] [get_property NAME $cell] \
    [baseline_property $cell SITE] [baseline_property $cell BEL] \
    [baseline_pin_nets $cell {GTREFCLK*}] [baseline_pin_nets $cell {QPLL*}] \
    [baseline_pin_nets $cell {TXOUTCLK*}] [baseline_pin_nets $cell {RXOUTCLK*}]]
  foreach property {TXOUT_DIV RXOUT_DIV RX_DATA_WIDTH TX_DATA_WIDTH ADAPT_CFG1 RXCDR_CFG3 RXDFE_GC_CFG2 RX_DEGEN_CTRL RX_DFE_AGC_CFG1 RX_SUM_DEGEN_AVTT_OVERITE RX_SUM_VCMTUNE} {
    lappend values [baseline_property $cell $property]
  }
  puts $channel_file [baseline_csv_row $values]
}
close $channel_file

set common_file [open [file join $baseline_output_dir commons.csv] w]
puts $common_file "owner,name,site,bel,gtrefclk_nets,qpll0outclk_nets,qpll0outrefclk_nets,QPLL0_FBDIV,QPLL0_REFCLK_DIV"
foreach cell $commons {
  set values [list [baseline_owner $cell] [get_property NAME $cell] \
    [baseline_property $cell SITE] [baseline_property $cell BEL] \
    [baseline_pin_nets $cell {GTREFCLK*}] [baseline_pin_nets $cell {QPLL0OUTCLK*}] \
    [baseline_pin_nets $cell {QPLL0OUTREFCLK*}] \
    [baseline_property $cell QPLL0_FBDIV] [baseline_property $cell QPLL0_REFCLK_DIV]]
  puts $common_file [baseline_csv_row $values]
}
close $common_file

report_property -all -file [file join $baseline_output_dir design_properties.rpt] [current_design]
report_clock_networks -file [file join $baseline_output_dir clock_networks.rpt]
puts "Wrote full electrical baseline: $baseline_output_dir"
close_design
