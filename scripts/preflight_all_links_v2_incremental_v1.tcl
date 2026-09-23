# Read-only compatibility gate for the single all-links-v2 implementation that
# uses the final audited all-links-v1 route as its incremental reference.
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
  return $actual
}

if {![string match "2023.2*" [version -short]]} {
  error "All-links v2 incremental attempt requires Vivado 2023.2"
}
if {[file exists $archive]} {error "Refusing existing attempt archive $archive"}
checked_sha256 $v1_dcp $v1_sha
checked_sha256 $v2_dcp $v2_sha
checked_sha256 $v2_elf $elf_sha
file mkdir $archive
set started [open [file join $archive GATE1_STARTED] {WRONLY CREAT EXCL}]
puts $started "read-only compatibility preflight; no implementation product"
close $started

# Prove that both immutable checkpoints target the same exact part and top.
open_checkpoint $v1_dcp
set v1_part [get_property PART [current_project]]
set v1_top [get_property TOP [current_design]]
set v1_compress [get_property BITSTREAM.GENERAL.COMPRESS [current_design]]
close_design
open_checkpoint $v2_dcp
set v2_part [get_property PART [current_project]]
set v2_top [get_property TOP [current_design]]
if {$v1_part ne "xcvu13p-flga2577-2-e" || $v2_part ne $v1_part} {
  error "Checkpoint part mismatch v1=$v1_part v2=$v2_part"
}
if {$v1_top ne "gt_test_all_links_v1_top" || $v2_top ne $v1_top} {
  error "Checkpoint top mismatch v1=$v1_top v2=$v2_top"
}
if {![string equal -nocase $v1_compress true] ||
    ![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {
  error "Compression property is not true on both checkpoints"
}

# Reapply the exact established implementation-only contract to the immutable
# synthesis DCP, then optimize before attaching the routed reference.
set ::all_links_v1_checkpoint_resume 1
source [file join $script_dir check_all_links_v1_synth.tcl]
opt_design

set channels [get_cells -hier -quiet -filter {REF_NAME == GTYE4_CHANNEL && IS_PRIMITIVE}]
set commons [get_cells -hier -quiet -filter {REF_NAME == GTYE4_COMMON && IS_PRIMITIVE}]
set controllers [get_cells -hier -quiet -filter {REF_NAME =~ gt_prbs_test_controller*}]
set engines [get_cells -hier -quiet -filter {REF_NAME =~ gt_lane_engine*}]
set banks [get_cells -hier -quiet -filter {REF_NAME =~ all_links_v1_slr_bank*}]
set participation [get_cells -hier -quiet -filter {
  (NAME =~ *g_bank_slr*/left_quad_selected_reg* ||
   NAME =~ *g_bank_slr*/right_quad_selected_reg*) && REF_NAME =~ FD*}]
set refclks [get_cells -hier -quiet -filter {
  REF_NAME == IBUFDS_GTE4 && IS_PRIMITIVE && NAME =~ *u_refclk_buffers*}]
if {[llength $channels] != 112 || [llength $commons] != 28 ||
    [llength $controllers] != 28 || [llength $engines] != 112 ||
    [llength $banks] != 4 || [llength $participation] != 28 ||
    [llength $refclks] != 12} {
  error "Optimized inventory ch/common/controller/engine/bank/participation/refclk=[llength $channels]/[llength $commons]/[llength $controllers]/[llength $engines]/[llength $banks]/[llength $participation]/[llength $refclks]"
}
set participation_by_bank {0 0 0 0}
foreach c $participation {
  if {![regexp {g_bank_slr([0-3])/} [get_property NAME $c] -> slr]} {
    error "Cannot classify participation register $c"
  }
  lset participation_by_bank $slr [expr {[lindex $participation_by_bank $slr] + 1}]
}
if {$participation_by_bank ne {6 8 8 6}} {
  error "Participation ownership $participation_by_bank is not 6/8/8/6"
}

# This is deliberately the default RuntimeOptimized incremental attachment.
# No placement, physical optimization, routing, or implementation DCP write is
# allowed in this preflight process.
read_checkpoint -incremental $v1_dcp
set reuse_report [report_incremental_reuse -return_string]
set reuse_file [open [file join $archive incremental_reuse_preflight.rpt] \
  {WRONLY CREAT EXCL}]
puts $reuse_file $reuse_report
close $reuse_file
if {![regexp {Incremental Directive[ ]*\|[ ]*RuntimeOptimized} $reuse_report]} {
  error "Vivado did not retain the default RuntimeOptimized incremental flow"
}
if {![regexp {\|[ ]*Cells[ ]*\|[ ]*([0-9.]+)[ ]*\|[ ]*([0-9.]+)[ ]*\|[ ]*([0-9.]+)} \
    $reuse_report -> cell_matched cell_initial cell_current]} {
  error "Could not parse Vivado cell reuse metrics"
}
if {![regexp {\|[ ]*Nets[ ]*\|[ ]*([0-9.]+)[ ]*\|[ ]*([0-9.]+)[ ]*\|[ ]*([0-9.]+)} \
    $reuse_report -> net_matched net_initial net_current]} {
  error "Could not parse Vivado net reuse metrics"
}
set reused_instances $cell_current
set unreused_nets [expr {100.0 - $net_current}]
if {$reused_instances < 90.0} {
  error "Incremental reused instances $reused_instances% is below 90%"
}
if {$unreused_nets > 25.0} {
  error "Incremental unreused nets $unreused_nets% exceeds 25%"
}

set manifest [open [file join $archive gate1_manifest.txt] {WRONLY CREAT EXCL}]
puts $manifest "vivado=[version -short]"
puts $manifest "v1_dcp=$v1_dcp"
puts $manifest "v1_sha256=$v1_sha"
puts $manifest "v2_synth_dcp=$v2_dcp"
puts $manifest "v2_synth_sha256=$v2_sha"
puts $manifest "v2_elf=$v2_elf"
puts $manifest "v2_elf_sha256=$elf_sha"
puts $manifest "part=$v2_part"
puts $manifest "top=$v2_top"
puts $manifest "compression=true"
puts $manifest "inventories=112_channels 28_commons 28_controllers 112_engines 4_banks 12_managed_refclks"
puts $manifest "participation=28 ownership=6/8/8/6"
puts $manifest "cell_matched_percent=$cell_matched"
puts $manifest "cell_initial_reuse_percent=$cell_initial"
puts $manifest "cell_current_reuse_percent=$cell_current"
puts $manifest "net_matched_percent=$net_matched"
puts $manifest "net_initial_reuse_percent=$net_initial"
puts $manifest "net_current_reuse_percent=$net_current"
puts $manifest [format "unreused_net_percent=%.2f" $unreused_nets]
puts $manifest "implementation_products_written=false"
close $manifest
set pass [open [file join $archive GATE1_PASS] {WRONLY CREAT EXCL}]
puts $pass "PASS reused_instances=$reused_instances unreused_nets=[format %.2f $unreused_nets]"
close $pass
puts "PASS: all-links v2/v1 incremental compatibility; cells $reused_instances% reused, [format %.2f $unreused_nets]% nets unreused"
