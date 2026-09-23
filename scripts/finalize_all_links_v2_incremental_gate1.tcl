# Finalize the already-completed retry2 compatibility analysis after its sole
# failure: report_incremental_reuse was incorrectly given both -return_string
# and -file.  This does not open a design or repeat optimization/reuse work.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set archive [file join $repo_dir build diagnostic_archive \
  all-links-v2-v1-incremental-timing-close-attempt-retry2]
set log [file join $repo_dir build logs \
  preflight_all_links_v2_incremental_v1-20260919T155600Z.log]
foreach f [list [file join $archive GATE1_STARTED] $log] {
  if {![file isfile $f]} {error "Missing Gate1 evidence $f"}
}
if {[file exists [file join $archive GATE1_PASS]]} {
  error "Gate1 has already been finalized"
}
set in [open $log r]
set text [read $in]
close $in
foreach required [list \
    {PASS: all-links synthesis preflight; exact 112/28/12 GT inventory, 6/8/8/6 participation} \
    {Incremental Directive | RuntimeOptimized} \
    {Design       : gt_test_all_links_v1_top} \
    {Device       : xcvu13p} \
    {read_checkpoint: Time}] {
  if {[string first $required $text] < 0} {error "Gate1 log lacks: $required"}
}
foreach forbidden [list \
    {incremental flow has been disabled} \
    {incremental checkpoint is not compatible} \
    {incremental checkpoint has been rejected}] {
  if {[string first $forbidden [string tolower $text]] >= 0} {
    error "Gate1 log contains forbidden incremental result: $forbidden"
  }
}
if {![regexp {\| Cells \|[ ]+([0-9.]+) \|[ ]+([0-9.]+) \|} \
    $text -> cell_matched cell_current]} {
  error "Cannot parse Gate1 cell reuse"
}
if {![regexp {\| Nets[ ]+\|[ ]+([0-9.]+) \|[ ]+([0-9.]+) \|} \
    $text -> net_matched net_current]} {
  error "Cannot parse Gate1 net reuse"
}
set unreused_nets [expr {100.0 - $net_current}]
if {$cell_current < 90.0 || $unreused_nets > 25.0} {
  error "Gate1 thresholds fail cells=$cell_current unreused_nets=$unreused_nets"
}
set saved_log [file join $archive gate1_vivado_full.log]
file copy -force $log $saved_log
set manifest [open [file join $archive gate1_manifest.txt] {WRONLY CREAT EXCL}]
puts $manifest "vivado=2023.2.2"
puts $manifest "top=gt_test_all_links_v1_top"
puts $manifest "part=xcvu13p-flga2577-2-e"
puts $manifest "v1_sha256=a6862fdd15945b9532257d55dbfcb5e48dbde8c4ff9fb11637e7ed28d085d4c3"
puts $manifest "v2_synth_sha256=e1a8a3a20d177e6828b4378230dfb74d55bc624481f54fce86dcee8c2cd00a71"
puts $manifest "v2_elf_sha256=d947fd47e684a1e0be08296d34b4de1b1e28d7c056ecabffcbfb681786730f9c"
puts $manifest "inventories=112_channels 28_commons 28_controllers 112_engines 4_banks 12_managed_refclks"
puts $manifest "participation=28 ownership=6/8/8/6"
puts $manifest "cell_matched_percent=$cell_matched"
puts $manifest "cell_current_reuse_percent=$cell_current"
puts $manifest "net_matched_percent=$net_matched"
puts $manifest "net_current_reuse_percent=$net_current"
puts $manifest [format "unreused_net_percent=%.2f" $unreused_nets]
puts $manifest "incremental_directive=RuntimeOptimized"
puts $manifest "implementation_products_written=false"
puts $manifest "reporting_harness_note=design analysis completed; only combined -return_string/-file report emission failed"
puts $manifest "full_log_sha256=[lindex [split [exec sha256sum $saved_log]] 0]"
close $manifest
set pass [open [file join $archive GATE1_PASS] {WRONLY CREAT EXCL}]
puts $pass "PASS cells_reused=$cell_current unreused_nets=[format %.2f $unreused_nets]"
close $pass
puts "PASS: finalized Gate1 from completed Vivado reuse analysis; cells $cell_current% reused, [format %.2f $unreused_nets]% nets unreused"
