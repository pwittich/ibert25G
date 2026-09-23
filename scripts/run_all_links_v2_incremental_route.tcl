# Gate 2B of the single all-links-v2 timing-close attempt.  Resume only the
# exact Gate 2A placed checkpoint, run one default phys_opt_design and one
# route_design, preserve routed evidence, and stop.  Audit/bit/hardware are
# deliberately separate and unauthorized here.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set archive [file join $repo_dir build diagnostic_archive \
  all-links-v2-v1-incremental-timing-close-attempt-retry2]
set manifest_path [file join $archive gate2a_manifest.txt]
set gate2a_pass [file join $archive GATE2A_PASS]
set placed [file join $archive gt_test_all_links_v2_incremental_placed.dcp]
set expected_placed_sha 5258aa8d4cbb1ad987796b6f70de51c60ad6cd51d563805fe60075a0a8b896cf
set routed [file join $archive gt_test_all_links_v2_incremental_routed.dcp]
set report_dir [file join $archive routed_gate]
set gate2b_started [file join $archive GATE2B_STARTED]
set gate2b_recovery [file join $archive GATE2B_LICENSE_FAILURE_INVALIDATED]
set failed_log [file join $repo_dir build logs \
  run_all_links_v2_incremental_route-20260919T164609Z.log]

proc write_exclusive {path text} {
  set fh [open $path {WRONLY CREAT EXCL}]
  puts $fh $text
  close $fh
}
proc read_text {path} {
  if {![file isfile $path]} {error "Missing required file $path"}
  set fh [open $path r]
  set text [read $fh]
  close $fh
  return $text
}

if {![string match "2023.2*" [version -short]]} {
  error "All-links v2 incremental route requires Vivado 2023.2"
}
if {[file exists [file join $archive GATE2B_PASS]] ||
    [file exists [file join $archive GATE2B_FAIL]] ||
    [file exists $routed] || [file exists [file join $archive gate2b_manifest.txt]]} {
  error "Refusing to repeat or overwrite Gate 2B"
}
if {[file exists $gate2b_started]} {
  # Permit exactly one infrastructure-only restart when the first process
  # reached license checkout but phys_opt_design never began.  The exact log
  # and complete absence of implementation products/reports are mandatory.
  if {[file exists $gate2b_recovery]} {
    error "Refusing repeated Gate 2B license recovery"
  }
  set failed_text [read_text $failed_log]
  if {[string first "ERROR: \[Common 17-345\] A valid license was not found" $failed_text] < 0 ||
      [string first "phys_opt_design completed successfully" $failed_text] >= 0 ||
      ![file isdirectory $report_dir] ||
      [llength [glob -nocomplain -directory $report_dir *]] != 0} {
    error "Gate 2B state is not the exact pre-physopt license failure"
  }
  write_exclusive $gate2b_recovery \
    "first launch invalidated: exact log shows license checkout failure before phys_opt began; no implementation product or report existed; one outside-sandbox launcher restart authorized"
} elseif {[file exists $report_dir]} {
  error "Refusing unexplained Gate 2B report directory"
}
set manifest [read_text $manifest_path]
set pass_text [read_text $gate2a_pass]
set normalized_placed [file normalize $placed]
foreach required [list \
    "vivado=2023.2.2" \
    "placed_dcp=$normalized_placed" \
    "placed_sha256=$expected_placed_sha" \
    "commands=opt_design; read_checkpoint -incremental; place_design" \
    "phys_opt=false route=false bit=false hardware=false"] {
  if {[string first $required $manifest] < 0} {
    error "Gate 2A manifest lacks exact required record: $required"
  }
}
if {[string first "PASS placed_sha256=$expected_placed_sha" $pass_text] != 0} {
  error "Gate 2A pass marker does not authorize the exact placed checkpoint"
}
if {![file isfile $placed]} {error "Missing Gate 2A placed checkpoint $placed"}
set actual_placed_sha [lindex [split [exec sha256sum $placed]] 0]
if {$actual_placed_sha ne $expected_placed_sha} {
  error "Gate 2A placed checkpoint SHA-256 mismatch: $actual_placed_sha"
}

if {![file exists $gate2b_started]} {
  write_exclusive $gate2b_started \
    "single continuation from placed_sha256=$expected_placed_sha; commands=phys_opt_design; route_design"
}
file mkdir $report_dir
open_checkpoint $placed
if {[get_property PART [current_design]] ne "xcvu13p-flga2577-2-e"} {
  error "Wrong Gate 2A part"
}
if {![string equal -nocase \
    [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {
  error "Compression disabled in Gate 2A checkpoint"
}

# This is the entire implementation continuation.  No directives, retries,
# post-route physopt, synthesis, audit, bit generation, or hardware access.
phys_opt_design
route_design
write_checkpoint $routed
set routed_sha [lindex [split [exec sha256sum $routed]] 0]

set reuse [report_incremental_reuse -return_string]
set reuse_fh [open [file join $report_dir incremental_reuse_routed.rpt] \
  {WRONLY CREAT EXCL}]
puts $reuse_fh $reuse
close $reuse_fh

# This reviewed route gate emits the complete min/max timing summary and
# bounded per-clock table, route status, DRC, and all 28 bus-skew groups.  It
# also rechecks compression and established bank-placement semantics.  Catch
# its terminal classification so a timing miss still gets an explicit marker
# after all evidence and the routed checkpoint have been preserved.
set ::all_links_slr_report_dir $report_dir
set gate_rc [catch {
  source [file join $script_dir verify_all_links_v1_slr_bank_routed_closeout.tcl]
} gate_result gate_options]

set result_fh [open [file join $archive gate2b_manifest.txt] \
  {WRONLY CREAT EXCL}]
puts $result_fh "vivado=[version -short]"
puts $result_fh "gate2a_placed_sha256=$actual_placed_sha"
puts $result_fh "routed_dcp=$routed"
puts $result_fh "routed_sha256=$routed_sha"
puts $result_fh "commands=phys_opt_design; route_design"
puts $result_fh "postroute_physopt=false retry=false audit=false bit=false hardware=false"
puts $result_fh "classification=[expr {$gate_rc ? {FAIL} : {PASS}}]"
puts $result_fh "classification_detail=$gate_result"
close $result_fh

if {$gate_rc} {
  write_exclusive [file join $archive GATE2B_FAIL] \
    "FAIL routed_sha256=$routed_sha detail=$gate_result"
  return -options $gate_options $gate_result
}
write_exclusive [file join $archive GATE2B_PASS] \
  "PASS routed_sha256=$routed_sha; independent audit remains separate"
puts "PASS: all-links v2 incremental route; stopped at routed DCP for separate audit"
