# Immutable preflight for the one permitted all-links-v2 post-route
# physical-optimization attempt.  This script is read-only with respect to
# the checkpoint and refuses any state other than the frozen retry2 route.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set source_dcp [file join $repo_dir build diagnostic_archive \
  all-links-v2-v1-incremental-timing-close-attempt-retry2 \
  gt_test_all_links_v2_incremental_routed.dcp]
set source_sha 6fd5e2b102f7b2fc79e4868adc66b7fca4cb737c7aa4989ff21ef74c6dc91824
set elf [file join $repo_dir build firmware_all_links_v2 gt_test_all_links_v2.elf]
set elf_sha d947fd47e684a1e0be08296d34b4de1b1e28d7c056ecabffcbfb681786730f9c
set report_dir [file join $repo_dir build all_links_v2_reports postroute_default_physopt_preflight_retry5]
set archive [file join $repo_dir build diagnostic_archive \
  all-links-v2-postroute-default-physopt-attempt]
if {[file exists $archive] || [file exists $report_dir]} {
  error "All-links-v2 post-route preflight/attempt already exists"
}
file mkdir $report_dir
foreach {path expected} [list $source_dcp $source_sha $elf $elf_sha] {
  if {![file isfile $path]} {error "Missing immutable input $path"}
  set actual [lindex [split [exec sha256sum $path]] 0]
  if {$actual ne $expected} {error "Hash mismatch for $path: $actual"}
}
if {![string match "2023.2*" [version -short]]} {error "Vivado 2023.2 required"}
open_checkpoint $source_dcp
if {[get_property PART [current_design]] ne "xcvu13p-flga2577-2-e"} {error "Wrong part"}
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {
  error "Compression disabled"
}

set timing [report_timing_summary -delay_type min_max -max_paths 100 \
  -report_unconstrained -return_string -file [file join $report_dir timing_preflight.rpt]]
set clk200_row {}
set negative_groups {}
set in_table 0
foreach line [split $timing "\n"] {
  if {[string match {*Intra Clock Table*} $line]} {set in_table 1; continue}
  if {$in_table && [string match {*Inter Clock Table*} $line]} {break}
  if {$in_table && [regexp {^\s*(\S+)\s+(-?[0-9.]+)\s+(-?[0-9.]+)\s+([0-9]+)\s+[0-9]+\s+(-?[0-9.]+)\s+(-?[0-9.]+)\s+([0-9]+)} \
      $line -> group setup_wns setup_tns setup_failed hold_whs hold_ths hold_failed]} {
    if {$setup_wns < 0 || $hold_whs < 0} {lappend negative_groups $group}
    if {$group eq "clk_200"} {
      set clk200_row [list $setup_wns $setup_tns $setup_failed $hold_whs $hold_ths $hold_failed]
    }
  }
}
if {$clk200_row ne {-0.119 -5.883 93 0.005 0.000 0}} {
  error "Frozen clk_200 state mismatch: $clk200_row"
}
if {$negative_groups ne {clk_200}} {error "Unexpected failing groups: $negative_groups"}

# Classify every failing setup endpoint.  The categories correspond to the
# architectural cones, not individual implementation-generated replicas.
set expected_counts [dict create \
  engine_copy 35 reset_distribution 31 snapshot_handshake 21 \
  descriptor_launch 3 aggregate_publication 2 session 1]
set counts [dict create]
set paths [get_timing_paths -quiet -delay_type max -slack_lesser_than 0 \
  -max_paths 1000 -nworst 1]
if {[llength $paths] != 93} {error "Expected 93 failing setup endpoints, got [llength $paths]"}
set family_out [open [file join $report_dir failing_path_families.tsv] w]
puts $family_out "family\tslack\tstartpoint\tendpoint"
foreach path $paths {
  set src [get_property STARTPOINT_PIN $path]
  set dst [get_property ENDPOINT_PIN $path]
  if {[string match */R $dst] || [string match */local_resetn_reg*/D $dst]} {
    set family reset_distribution
  } elseif {[string first "g_snapshot_cdc.u_snapshot_handshake/" $dst] >= 0 &&
            [string match */dest_hsdata_ff_reg*/CE $dst]} {
    set family snapshot_handshake
  } elseif {[string first "g_descriptor_launch\[" $dst] >= 0 &&
            ([string first "selected_launch_reg" $dst] >= 0 ||
             [string first "prbs_launch_reg" $dst] >= 0)} {
    set family descriptor_launch
  } elseif {[string first "u_quad_aggregate/diagnostics_reg" $dst] >= 0 ||
            [string first "u_local_aggregate/diagnostics_reg" $dst] >= 0} {
    set family aggregate_publication
  } elseif {[string first "/tx_session_active_reg" $dst] >= 0} {
    set family session
  } elseif {[string first "/u_engine/u_core/copy_" $dst] >= 0} {
    set family engine_copy
  } else {
    close $family_out
    error "Unclassified failing path: $src -> $dst"
  }
  dict incr counts $family
  puts $family_out "$family\t[get_property SLACK $path]\t$src\t$dst"
}
close $family_out
dict for {family expected} $expected_counts {
  if {![dict exists $counts $family] || [dict get $counts $family] != $expected} {
    error "Failing-family mismatch for $family: counts=$counts"
  }
}
if {[dict size $counts] != [dict size $expected_counts]} {
  error "Unexpected extra failing family: $counts"
}

set route [report_route_status -return_string -file [file join $report_dir route_status_preflight.rpt]]
foreach {pattern expected} {
  {# of routable nets[. ]*:[ ]*([0-9]+)} 212112
  {# of fully routed nets[. ]*:[ ]*([0-9]+)} 212112
  {# of nets with routing errors[. ]*:[ ]*([0-9]+)} 0
} {
  if {![regexp $pattern $route -> actual] || $actual != $expected} {
    error "Route-state mismatch for $pattern: $actual"
  }
}
set skew [report_bus_skew -warn_on_violation -return_string \
  -file [file join $report_dir bus_skew_preflight.rpt]]
if {[regexp -all {Slack \(MET\)} $skew] != 28 || [string match {*VIOLATED*} $skew]} {
  error "Expected 28/28 passing bus-skew groups"
}
report_drc -file [file join $report_dir drc_preflight.rpt]
foreach violation [get_drc_violations -quiet] {
  if {[get_property SEVERITY $violation] eq "Error"} {error "Error DRC $violation"}
}
source [file join $script_dir verify_all_links_v1_postroute_inventory.tcl]
set participation [get_cells -hier -quiet -filter {
  (NAME =~ */left_quad_selected_reg* || NAME =~ */right_quad_selected_reg*) && REF_NAME =~ FD*}]
if {[llength $participation] != 28} {error "Participation inventory [llength $participation], expected 28"}
set by_owner {0 0 0 0}
set physical_by_slr {0 0 0 0}
foreach cell $participation {
  set name [get_property NAME $cell]
  if {![regexp {g_bank_slr([0-3])/} $name -> owner]} {error "Cannot classify participation owner: $cell"}
  lset by_owner $owner [expr {[lindex $by_owner $owner] + 1}]
  set actual [get_property NAME [get_slrs -quiet -of_objects [get_sites -quiet -of_objects $cell]]]
  if {![regexp {SLR([0-3])} $actual -> slr]} {error "Participation cell lacks SLR: $cell"}
  lset physical_by_slr $slr [expr {[lindex $physical_by_slr $slr] + 1}]
}
if {$by_owner ne {6 8 8 6}} {error "Participation ownership split $by_owner"}

set manifest [open [file join $report_dir preflight_manifest.txt] w]
puts $manifest "PASS"
puts $manifest "vivado=[version -short]"
puts $manifest "input_dcp=$source_dcp"
puts $manifest "input_sha256=$source_sha"
puts $manifest "elf=$elf"
puts $manifest "elf_sha256=$elf_sha"
puts $manifest "pre_state=setup -0.119/-5.883 ns/93 endpoints only clk_200; hold +0.005/0.000 ns/0"
puts $manifest "route=212112/212112 fully routed; route_errors=0; drc_errors=0; bus_skew=28/28"
puts $manifest "families=$counts"
puts $manifest "participation=28 ownership 6/8/8/6; pre_physopt_physical_slr_split=$physical_by_slr"
puts $manifest "operation=exactly one plain phys_opt_design; no directive, reroute, seed change, or retry"
close $manifest
puts "PASS: immutable all-links-v2 post-route preflight and six-family proof"
