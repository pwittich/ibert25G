set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set source_dcp [file join $repo_dir build diagnostic_archive all-links-v1-slr-bank-closeout-continuation-retry1 gt_test_all_links_v1_routed_pre_gate.dcp]
set source_sha 4631ff396e6b18baf61a312c6beaa7d77b00f6ba267830c40367a163a222a974
set elf [file join $repo_dir build firmware_all_links_v1 gt_test_all_links_v1.elf]
set elf_sha 96d3ab54308b894d34f2add001c16d1aa52029bc1474aba506c3017ca6a978ae
set report_dir [file join $repo_dir build all_links_v1_reports postroute_default_physopt_preflight]
set archive [file join $repo_dir build diagnostic_archive all-links-v1-postroute-default-physopt-attempt]
set work [file join $repo_dir build gt_test_all_links_v1_postroute_default_physopt]
if {[file exists $archive] || [file exists $work]} {error "Post-route attempt already exists; refusing preflight"}
file mkdir $report_dir
foreach {path expected} [list $source_dcp $source_sha $elf $elf_sha] {
  if {![file isfile $path] || [lindex [split [exec sha256sum $path]] 0] ne $expected} {error "Missing or hash-mismatched input: $path"}
}
if {![string match *2023.2* [version -short]]} {error "Vivado 2023.2 required, got [version -short]"}
open_checkpoint $source_dcp
if {[get_property PART [current_design]] ne "xcvu13p-flga2577-2-e"} {error "Wrong part"}
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {error "Compression disabled"}
set timing [report_timing_summary -delay_type min_max -max_paths 100 -report_unconstrained -return_string -file [file join $report_dir timing_preflight.rpt]]
if {![regexp {Setup\s*:\s*22\s+Failing Endpoints,\s+Worst Slack\s+-0\.034ns,\s+Total Violation\s+-0\.343ns} $timing] ||
    ![regexp {Hold\s*:\s*0\s+Failing Endpoints,\s+Worst Slack\s+([0-9.]+)ns,\s+Total Violation\s+0\.000ns} $timing -> whs] || $whs < 0} {
  error "Input timing is not exact frozen state"
}
set group_failures {}
set in_table 0
foreach line [split $timing "\n"] {
  if {[string match {*Intra Clock Table*} $line]} {set in_table 1}
  if {$in_table && [regexp {^\s*(\S+)\s+(-[0-9.]+)\s+(-?[0-9.]+)\s+([0-9]+)} $line -> group wns tns failed]} {lappend group_failures $group}
  if {$in_table && [string match {*Inter Clock Table*} $line]} {break}
}
if {$group_failures ne {clk_200}} {error "Unexpected failing clock groups: $group_failures"}

set family_patterns [dict create \
  q227_drpclk_state {g_bank_slr1/g_right_quad\[3\].*q227.*DRPCLK -> .*state_reg} \
  q221_running_exact_count {g_bank_slr0/g_right_quad\[0\].*running_sync_reg\[3\]/C -> .*exact_error_counts_reg} \
  q121_drpclk_state {g_bank_slr0/g_left_quad\[0\].*q121.*DRPCLK -> .*state_reg} \
  q229_counter_state {g_bank_slr2/g_left_quad\[0\].*counter_reg\[2\]/C -> .*state_reg} \
  lane52_snapshot_capture {g_lane\[52\].*syncstages_ff_reg\[1\]/C -> .*dest_hsdata_ff_reg} \
  q?_errorfree_state {g_bank_slr2/g_right_quad\[3\].*error_free_count_reg\[1\]/C -> .*state_reg} \
  q234_drpclk_saturation {g_bank_slr3/g_right_quad\[2\].*q234.*DRPCLK -> .*exact_error_saturated_reg} \
  q221_drpclk_state {g_bank_slr0/g_right_quad\[0\].*q221.*DRPCLK -> .*state_reg}]
set expected_family_counts [dict create q227_drpclk_state 3 q221_running_exact_count 5 q121_drpclk_state 2 q229_counter_state 6 lane52_snapshot_capture 2 q?_errorfree_state 2 q234_drpclk_saturation 1 q221_drpclk_state 1]
set actual_family_counts [dict create]
set path_out [open [file join $report_dir residual_path_families.tsv] w]
puts $path_out "family\tslack\tsource\tdestination"
set failing_paths [get_timing_paths -quiet -delay_type max -slack_lesser_than 0 -max_paths 1000 -nworst 1]
if {[llength $failing_paths] != 22} {error "Expected 22 residual setup paths, got [llength $failing_paths]"}
foreach path $failing_paths {
  set src [get_property STARTPOINT_PIN $path]
  set dst [get_property ENDPOINT_PIN $path]
  set pair "$src -> $dst"
  set matches {}
  dict for {family pattern} $family_patterns {if {[regexp $pattern $pair]} {lappend matches $family}}
  if {[llength $matches] != 1} {close $path_out; error "Residual path family match [llength $matches]: $pair"}
  set family [lindex $matches 0]
  dict incr actual_family_counts $family
  puts $path_out "$family\t[get_property SLACK $path]\t$src\t$dst"
}
close $path_out
if {$actual_family_counts ne $expected_family_counts} {error "Residual family counts $actual_family_counts, expected $expected_family_counts"}
set routing [report_route_status -return_string -file [file join $report_dir route_status_preflight.rpt]]
foreach {pattern expected} {
  {# of routable nets[. ]*:[ ]*([0-9]+)} 212246
  {# of fully routed nets[. ]*:[ ]*([0-9]+)} 212246
  {# of nets with routing errors[. ]*:[ ]*([0-9]+)} 0
} {if {![regexp $pattern $routing -> value] || $value != $expected} {error "Route preflight mismatch for $pattern: $value"}}
set skew [report_bus_skew -warn_on_violation -return_string -file [file join $report_dir bus_skew_preflight.rpt]]
if {[regexp -all {Slack \(MET\)} $skew] != 28 || [string match {*VIOLATED*} $skew]} {error "Bus-skew preflight mismatch"}
report_drc -file [file join $report_dir drc_preflight.rpt]
foreach v [get_drc_violations -quiet] {if {[get_property SEVERITY $v] eq "Error"} {error "Error DRC $v"}}
source [file join $script_dir verify_all_links_v1_postroute_inventory.tcl]
set manifest [open [file join $report_dir preflight_manifest.txt] w]
puts $manifest "PASS"
puts $manifest "vivado=[version -short]"
puts $manifest "input_dcp=$source_dcp"
puts $manifest "input_sha256=$source_sha"
puts $manifest "elf=$elf"
puts $manifest "elf_sha256=$elf_sha"
puts $manifest "identity=all-links-v1 firmware 0x00020500; exact ELF association inherited from immutable synthesis/placement manifests"
puts $manifest "pre_state=clk_200 setup -0.034/-0.343 ns/22 endpoints; hold $whs/0.000 ns/0; every other clock group nonnegative"
puts $manifest "route=212246/212246 fully routed, zero route errors; drc_error=0; bus_skew=28/28 MET"
puts $manifest "residual_families=8 counts=$actual_family_counts"
puts $manifest "operation=exactly one plain phys_opt_design; no -post_route, no route_design, no retry"
close $manifest
puts "PASS: immutable routed preflight and eight-family manifest"
