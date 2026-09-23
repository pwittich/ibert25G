set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set source_dcp [file join $repo_dir build diagnostic_archive \
  all-links-v2-v1-incremental-timing-close-attempt-retry2 \
  gt_test_all_links_v2_incremental_routed.dcp]
set source_sha 6fd5e2b102f7b2fc79e4868adc66b7fca4cb737c7aa4989ff21ef74c6dc91824
set preflight_dir [file join $repo_dir build all_links_v2_reports postroute_default_physopt_preflight_retry5]
set preflight [file join $preflight_dir preflight_manifest.txt]
set archive [file join $repo_dir build diagnostic_archive \
  all-links-v2-postroute-default-physopt-attempt]
if {![file isfile $preflight]} {error "Exact preflight has not passed"}
set fh [open $preflight r]; set preflight_text [read $fh]; close $fh
if {[string first "PASS\n" $preflight_text] != 0 ||
    [string first "input_sha256=$source_sha" $preflight_text] < 0} {
  error "Exact preflight manifest is invalid"
}
if {[lindex [split [exec sha256sum $source_dcp]] 0] ne $source_sha} {error "Input DCP hash changed"}
if {[file exists $archive]} {error "Exclusive post-route attempt already exists"}
file mkdir $archive
foreach f [glob -nocomplain -directory $preflight_dir *] {
  if {[file isfile $f]} {file copy $f [file join $archive preflight_[file tail $f]]}
}
set manifest [open [file join $archive attempt_manifest.txt] w]
puts $manifest "input_dcp=$source_dcp"
puts $manifest "input_sha256=$source_sha"
puts $manifest "command=phys_opt_design"
puts $manifest "prohibited=directive, -post_route, route_design, retry, seed/source/constraint/IP/synthesis changes"
close $manifest
set status_file [file join $archive final_status.txt]
open_checkpoint $source_dcp
puts "ALL_LINKS_V2_POSTROUTE: invoking sole permitted command: phys_opt_design"
if {[catch {phys_opt_design} result options]} {
  set out [open $status_file w]
  puts $out "FAIL command=$result"
  puts $out "audit=not_run bitstream=not_generated hardware=not_touched"
  close $out
  return -options $options $result
}
set output_dcp [file join $archive gt_test_all_links_v2_postroute_default_physopt.dcp]
write_checkpoint $output_dcp
set output_sha [lindex [split [exec sha256sum $output_dcp]] 0]
set hash_out [open [file join $archive output_sha256.txt] w]
puts $hash_out "$output_sha  $output_dcp"
close $hash_out
set ::all_links_slr_report_dir [file join $archive strict_gate]
file mkdir $::all_links_slr_report_dir
set outcome PASS
if {[catch {source [file join $script_dir verify_all_links_v1_slr_bank_routed_closeout.tcl]} result]} {
  set outcome "FAIL strict routed gate: $result"
}
if {$outcome eq "PASS" && [catch {source [file join $script_dir verify_all_links_v1_postroute_inventory.tcl]} result]} {
  set outcome "FAIL strict inventory gate: $result"
}
if {$outcome eq "PASS"} {
  set participation [get_cells -hier -quiet -filter {
    (NAME =~ */left_quad_selected_reg* || NAME =~ */right_quad_selected_reg*) && REF_NAME =~ FD*}]
  if {[llength $participation] != 28} {set outcome "FAIL participation inventory [llength $participation]"}
  set physical_by_slr {0 0 0 0}
  foreach cell $participation {
    set actual [get_property NAME [get_slrs -quiet -of_objects [get_sites -quiet -of_objects $cell]]]
    if {![regexp {SLR([0-3])} $actual -> slr]} {
      set outcome "FAIL participation cell lacks physical SLR: $cell"
      break
    }
    lset physical_by_slr $slr [expr {[lindex $physical_by_slr $slr] + 1}]
  }
  if {$outcome eq "PASS" && $physical_by_slr ne {6 8 8 6}} {
    set outcome "FAIL physical participation SLR split $physical_by_slr, expected 6 8 8 6"
  }
}
set out [open $status_file w]
puts $out $outcome
puts $out "input_sha256=$source_sha"
puts $out "output_sha256=$output_sha"
if {$outcome eq "PASS"} {
  puts $out "independent_audit=required bitstream=not_generated hardware=not_touched"
} else {
  puts $out "independent_audit=not_run bitstream=not_generated hardware=not_touched"
}
close $out
if {$outcome ne "PASS"} {error $outcome}
puts "PASS: one-shot all-links-v2 post-route physopt meets strict gate"
