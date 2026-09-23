# Read-only comparison of the passing isolated v275 and failing full-v13
# managed quad-124 routed checkpoints.  It deliberately creates no project,
# modifies no checkpoint, and writes no bitstream.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set checkpoints [list \
  v275 [file join $repo_dir build gt_test_milestone275 gt_test_milestone275.runs impl_1 gt_test_milestone25_top_routed.dcp] \
  v13 [file join $repo_dir build gt_test_milestone3_v13 gt_test_milestone3_v13.runs impl_1 gt_test_milestone3_top_routed.dcp]]

foreach {label checkpoint} $checkpoints {
  if {![file isfile $checkpoint]} { error "Missing $label checkpoint: $checkpoint" }
  open_checkpoint $checkpoint
  set channels [get_cells -hier -filter {
    REF_NAME == GTYE4_CHANNEL && NAME =~ *u_managed_quad124/*
  }]
  puts "IMAGE=$label MANAGED_CHANNELS=[llength $channels]"
  foreach channel [lsort $channels] {
    set site [get_property SITE $channel]
    puts "CHANNEL image=$label site=$site cell=$channel"
    foreach property {ADAPT_CFG1 RXCDR_CFG3 RXDFE_GC_CFG2 RX_DEGEN_CTRL
                      RX_DFE_AGC_CFG1 RX_SUM_DEGEN_AVTT_OVERITE RX_SUM_VCMTUNE} {
      puts "PROPERTY image=$label site=$site $property=[get_property $property $channel]"
    }
    foreach pin_name {RXPRBSSEL TXPRBSSEL RXPRBSERR RXPRBSLOCKED RXUSRCLK2
                      RXRESETDONE RXPMARESETDONE} {
      set pins [get_pins -quiet $channel/$pin_name]
      set nets [get_nets -quiet -of_objects $pins]
      puts "PINNET image=$label site=$site pin=$pin_name nets=[lsort $nets]"
    }
    set site_cells [get_cells -hier -quiet -filter "SITE == $site"]
    puts "SITE_OWNERS image=$label site=$site cells=[lsort $site_cells]"
  }
  set managed_nets [get_nets -hier -quiet -filter {NAME =~ *u_managed_quad124/*}]
  set shared_with_ibert {}
  foreach net $managed_nets {
    set cells [get_cells -quiet -of_objects [get_pins -quiet -of_objects $net]]
    if {[llength [get_cells -quiet $cells -filter {NAME =~ *g_full_ibert*}]]} {
      lappend shared_with_ibert $net
    }
  }
  puts "MANAGED_TO_FULL_IBERT_NETS image=$label count=[llength $shared_with_ibert] nets=[lsort $shared_with_ibert]"
  close_design
}
puts "COMPARE_V13_V275_MANAGED_QUAD_ROUTED_PASS"
