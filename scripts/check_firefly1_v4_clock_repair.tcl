set r [file dirname [file dirname [file normalize [info script]]]]
open_checkpoint [file join $r build gt_test_firefly1_loopback_v4 gt_test_firefly1_loopback_v4.runs impl_1 gt_test_firefly1_loopback_v2_top_routed.dcp]
read_xdc [file join $r constraints firefly1_reference_clocks.xdc]
report_clocks -file [file join $r build gt_test_firefly1_loopback_v4_audit repaired_clocks.rpt]
report_methodology -file [file join $r build gt_test_firefly1_loopback_v4_audit repaired_methodology.rpt]
report_timing_summary -file [file join $r build gt_test_firefly1_loopback_v4_audit repaired_timing.rpt]
foreach c [get_cells -hier -filter {REF_NAME == GTYE4_CHANNEL}] {
  foreach p {TXOUTCLK RXOUTCLK} {puts "GT_CLOCK $c/$p [get_clocks -of_objects [get_pins $c/$p]]"}
}
