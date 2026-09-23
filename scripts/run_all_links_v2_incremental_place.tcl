# Gate 2A of the single all-links-v2 timing-close attempt: attach the exact
# audited v1 routed checkpoint to the exact frozen v2 synthesis checkpoint,
# then run only default placement.  The routed continuation is a separate
# process so a workstation failure cannot silently repeat placement.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set archive [file join $repo_dir build diagnostic_archive \
  all-links-v2-v1-incremental-timing-close-attempt-retry2]
set v1_dcp [file join $repo_dir build diagnostic_archive \
  all-links-v1-postroute-default-physopt-attempt \
  gt_test_all_links_v1_postroute_default_physopt.dcp]
set v2_dcp [file join $repo_dir build diagnostic_archive \
  all-links-v2-0x00020501-normal-route-timing-failure artifacts \
  gt_test_all_links_v2_synth.dcp]
set v2_elf [file join $repo_dir build diagnostic_archive \
  all-links-v2-0x00020501-normal-route-timing-failure artifacts \
  gt_test_all_links_v2.elf]
set v1_sha a6862fdd15945b9532257d55dbfcb5e48dbde8c4ff9fb11637e7ed28d085d4c3
set v2_sha e1a8a3a20d177e6828b4378230dfb74d55bc624481f54fce86dcee8c2cd00a71
set elf_sha d947fd47e684a1e0be08296d34b4de1b1e28d7c056ecabffcbfb681786730f9c

proc checked_sha256 {path expected} {
  if {![file isfile $path]} {error "Missing immutable input $path"}
  set actual [lindex [split [exec sha256sum $path]] 0]
  if {$actual ne $expected} {error "SHA-256 mismatch for $path: $actual"}
}
proc write_text {path text} {
  set fh [open $path {WRONLY CREAT EXCL}]
  puts $fh $text
  close $fh
}

if {![string match "2023.2*" [version -short]]} {
  error "All-links v2 incremental attempt requires Vivado 2023.2"
}
foreach {path expected} [list $v1_dcp $v1_sha $v2_dcp $v2_sha $v2_elf $elf_sha] {
  checked_sha256 $path $expected
}
if {![file isfile [file join $archive GATE1_PASS]]} {
  error "Gate 1 compatibility preflight has not passed"
}
set gate2a_started [file join $archive GATE2A_STARTED]
set gate2a_resumed [file join $archive GATE2A_PREPLACE_RESUMED]
set gate2a_invalidated [file join $archive GATE2A_INTERRUPTED_JOBS_INVALIDATED]
set gate2a_approved_restart [file join $archive GATE2A_APPROVED_LAUNCHER_RESTART]
set gate2a_pass [file join $archive GATE2A_PASS]
if {[file exists $gate2a_pass]} {
  error "Refusing existing Gate 2A pass marker $gate2a_pass"
}
if {[file exists $gate2a_started]} {
  # The first process was lost while open_checkpoint was still loading.  A
  # recovery is safe only while no implementation product/report exists, and
  # it is itself single-use.  Preserve the original marker and crash log.
  foreach product [list \
      [file join $archive gt_test_all_links_v2_incremental_placed.dcp] \
      [file join $archive incremental_reuse_placed.rpt] \
      [file join $archive placed_gate] \
      [file join $archive gate2a_manifest.txt]] {
    if {[file exists $product]} {
      error "Refusing Gate 2A recovery with existing product $product"
    }
  }
  if {[file exists $gate2a_resumed]} {
    if {![file isfile $gate2a_invalidated]} {
      error "Refusing repeated Gate 2A recovery marker $gate2a_resumed"
    }
    if {[file exists $gate2a_approved_restart]} {
      error "Refusing repeated approved-launcher restart $gate2a_approved_restart"
    }
    write_text $gate2a_approved_restart \
      "single approved-launcher restart after both incomplete jobs were terminated; no implementation product existed"
  } else {
    write_text $gate2a_resumed \
      "single recovery after process loss during open_checkpoint; no opt/place product existed"
  }
} else {
  write_text $gate2a_started \
    "single default incremental implementation; stopped after place_design"
}

open_checkpoint $v2_dcp
if {[get_property PART [current_design]] ne "xcvu13p-flga2577-2-e"} {
  error "Wrong v2 part"
}
if {![string equal -nocase \
    [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {
  error "Compression disabled on v2 synthesis checkpoint"
}

# Reapply the exact established implementation-only constraints and prove the
# frozen v2 netlist before optimization or checkpoint reuse.
set ::all_links_v1_checkpoint_resume 1
source [file join $script_dir check_all_links_v1_synth.tcl]
opt_design
read_checkpoint -incremental $v1_dcp
place_design

set placed [file join $archive gt_test_all_links_v2_incremental_placed.dcp]
write_checkpoint $placed
set placed_sha [lindex [split [exec sha256sum $placed]] 0]

set reuse [report_incremental_reuse -return_string]
set reuse_fh [open [file join $archive incremental_reuse_placed.rpt] \
  {WRONLY CREAT EXCL}]
puts $reuse_fh $reuse
close $reuse_fh
if {![regexp {Incremental Directive[ ]*\|[ ]*RuntimeOptimized} $reuse]} {
  error "Vivado did not retain the default RuntimeOptimized incremental flow"
}
if {![regexp {\|[ ]*Cells[ ]*\|[ ]*([0-9.]+)[ ]*\|[ ]*([0-9.]+)[ ]*\|[ ]*([0-9.]+)} \
    $reuse -> cell_matched cell_initial cell_current]} {
  error "Could not parse placed cell reuse"
}
if {![regexp {\|[ ]*Nets[ ]*\|[ ]*([0-9.]+)[ ]*\|[ ]*([0-9.]+)[ ]*\|[ ]*([0-9.]+)} \
    $reuse -> net_matched net_initial net_current]} {
  error "Could not parse placed net reuse"
}
set unreused_nets [expr {100.0 - $net_current}]
if {$cell_current < 90.0 || $unreused_nets > 25.0} {
  error "Placed reuse threshold failed: cells=$cell_current unreused_nets=$unreused_nets"
}

# Reuse the reviewed placement semantics gate.  It proves bank boundaries,
# reset locality, publication-only controller escapes, timing coverage, and
# all 28 descriptor bus-skew groups before physical optimization is allowed.
set ::all_links_slr_report_dir [file join $archive placed_gate]
source [file join $script_dir verify_all_links_v1_slr_bank_placed_closeout.tcl]

set manifest [open [file join $archive gate2a_manifest.txt] \
  {WRONLY CREAT EXCL}]
puts $manifest "vivado=[version -short]"
puts $manifest "v1_reference_sha256=$v1_sha"
puts $manifest "v2_synth_sha256=$v2_sha"
puts $manifest "v2_elf_sha256=$elf_sha"
puts $manifest "placed_dcp=$placed"
puts $manifest "placed_sha256=$placed_sha"
puts $manifest "incremental_directive=RuntimeOptimized"
puts $manifest "cell_current_reuse_percent=$cell_current"
puts $manifest "net_current_reuse_percent=$net_current"
puts $manifest [format "unreused_net_percent=%.2f" $unreused_nets]
puts $manifest "commands=opt_design; read_checkpoint -incremental; place_design"
puts $manifest "phys_opt=false route=false bit=false hardware=false"
close $manifest
write_text [file join $archive GATE2A_PASS] \
  "PASS placed_sha256=$placed_sha cells_reused=$cell_current unreused_nets=[format %.2f $unreused_nets]"
puts "PASS: all-links v2 incremental placement; routed continuation permitted exactly once"
