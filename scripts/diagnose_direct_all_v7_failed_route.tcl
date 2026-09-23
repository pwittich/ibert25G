set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set dcp [file join $repo_dir build gt_test_direct_all_v7r3 \
  gt_test_direct_all_v7r3.runs impl_1 gt_test_direct_all_v7_top_routed.dcp]
set out_dir [file join $repo_dir build direct_all_v7_failed_route_diagnosis]
if {![file isfile $dcp]} {error "Missing preserved failed routed checkpoint $dcp"}
file mkdir $out_dir
open_checkpoint $dcp

report_timing_summary -max_paths 100 -report_unconstrained \
  -file [file join $out_dir timing_summary_100.rpt]
report_timing -delay_type max -max_paths 200 -nworst 20 \
  -file [file join $out_dir worst_setup_200.rpt]
report_timing -delay_type min -max_paths 50 -nworst 10 \
  -file [file join $out_dir worst_hold_50.rpt]
report_bus_skew -file [file join $out_dir bus_skew.rpt]
report_route_status -file [file join $out_dir route_status.rpt]
report_drc -checks {NSTD-1 UCIO-1} -file [file join $out_dir io_drc.rpt]

set fd [open [file join $out_dir reduction_placement.tsv] w]
puts $fd "cell\tref\tslr\tloc"
set patterns [list \
  */g_all_direct.g_quad*/u_managed_direct/u_prbs_test_controller/state_reg* \
  */u_engine/u_core/tx_session_active_reg* \
  */u_engine/u_core/active_prbs_mode_reg* \
  */u_quad_aggregate*]
set seen {}
foreach pattern $patterns {
  foreach c [get_cells -hier -quiet $pattern] {
    if {[dict exists $seen $c]} {continue}
    dict set seen $c 1
    set loc [get_property LOC $c]
    set slr ""
    if {$loc ne ""} {
      set sites [get_sites -quiet $loc]
      if {[llength $sites] == 1} {set slr [get_property SLR $sites]}
    }
    puts $fd "$c\t[get_property REF_NAME $c]\t$slr\t$loc"
  }
}
close $fd

set channels [get_cells -hier -filter {REF_NAME == GTYE4_CHANNEL && IS_PRIMITIVE}]
set commons [get_cells -hier -filter {REF_NAME == GTYE4_COMMON && IS_PRIMITIVE}]
puts "DIRECT_ALL_V7_FAILED_ROUTE: channels=[llength $channels] commons=[llength $commons]"
puts "DIRECT_ALL_V7_FAILED_ROUTE: reports=$out_dir"
puts "PASS: preserved failed route diagnosed without modifying project or checkpoint"
