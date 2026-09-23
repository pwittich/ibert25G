# Preserve the stopped attempt and run the corrected placement verifier
# read-only.  This script never launches or resumes implementation.

set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set name gt_test_all_links_v1
set run_dir [file join $repo_dir build $name ${name}.runs impl_1]
set placed_dcp [file join $run_dir ${name}_top_placed.dcp]
set archive_dir [file join $repo_dir build diagnostic_archive \
  all-links-v1-enumerated-leaf-locality-attempt]
if {![file isfile $placed_dcp]} {error "Missing stopped-attempt placed DCP $placed_dcp"}
if {![file isdirectory $archive_dir]} {error "Missing attempt archive $archive_dir"}

foreach f [glob -nocomplain -directory $run_dir *] {
  set tail [file tail $f]
  if {[file isfile $f] && ([string match *.dcp $tail] || [string match *.rpt $tail] ||
      $tail eq "runme.log" || $tail eq "vivado.pb" || $tail eq "vivado.jou")} {
    file copy -force $f [file join $archive_dir $tail]
  }
}

open_checkpoint $placed_dcp
set verify_status PASS
set verify_detail {}
if {[catch {source [file join $script_dir verify_all_links_v1_locality_placed.tcl]} verify_detail]} {
  set verify_status FAIL
}
set placement_hash [lindex [split [exec sha256sum $placed_dcp]] 0]
set out [open [file join $archive_dir stopped_attempt_status.txt] w]
puts $out "implementation stopped after place_design and before phys_opt_design/route_design"
puts $out "cause: placement verification Tcl bookkeeping bug (nested dict incr misuse)"
puts $out "placed DCP SHA-256 $placement_hash"
puts $out "corrected read-only placement verification $verify_status"
puts $out "verification detail: $verify_detail"
puts $out "placer post-placement estimated WNS -1.240 ns"
puts $out "no route, bitstream, independent audit, or hardware action was performed"
close $out
close_design
if {$verify_status ne "PASS"} {error "Corrected placement verification failed: $verify_detail"}
puts "PASS: stopped-attempt evidence archived and corrected placement proof passed read-only"
