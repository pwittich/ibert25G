set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set project_dir [file join $repo_dir build gt_test_all_links_v1]
set run_dir [file join $project_dir gt_test_all_links_v1.runs impl_1]
set report_dir [file join $repo_dir build all_links_v1_reports keep_hierarchy]
set archive [file join $repo_dir build diagnostic_archive all-links-v1-keep-hierarchy-locality-attempt]
set placed [file join $run_dir gt_test_all_links_v1_top_placed.dcp]
set synth [file join $project_dir gt_test_all_links_v1_synth.dcp]
foreach path [list $archive $placed] {
  if {![file exists $path]} {error "Missing stopped-attempt evidence $path"}
}

# Preserve generated evidence after the implementation hook deliberately makes
# the run fail.  The main driver catches this condition for future attempts;
# this one-shot helper completes the archive for the already-stopped run.
foreach f [glob -nocomplain -directory $run_dir *] {
  set tail [file tail $f]
  if {[file isfile $f] && ([string match *.dcp $tail] || [string match *.rpt $tail] ||
      $tail in {runme.log vivado.pb vivado.jou})} {
    file copy -force $f [file join $archive $tail]
  }
}
foreach f [glob -nocomplain -directory $report_dir *] {
  if {[file isfile $f]} {file copy -force $f [file join $archive [file tail $f]]}
}
file copy -force $synth [file join $archive keep_hierarchy_synth.dcp]
foreach f [list \
    [file join $repo_dir constraints all_links_v1_keep_hierarchy.xdc] \
    [file join $script_dir check_all_links_v1_keep_hierarchy_synth.tcl] \
    [file join $script_dir preflight_all_links_v1_keep_hierarchy.tcl] \
    [file join $script_dir verify_all_links_v1_keep_hierarchy_opted.tcl] \
    [file join $script_dir verify_all_links_v1_keep_hierarchy_placed.tcl]] {
  file copy -force $f [file join $archive [file tail $f]]
}

open_checkpoint $placed
set excluded {}
for {set slr 0} {$slr < 4} {incr slr} {
  foreach root [get_cells -quiet -of_objects [get_pblocks all_links_v1_kh_locality_slr$slr]] {
    set root_name [get_property NAME $root]
    regsub -all {[][{}().^$*+?|\\]} $root_name {\\&} quoted
    foreach leaf [get_cells -hier -regexp -quiet -filter {IS_PRIMITIVE} "^${quoted}/.*$"] {
      set leaf_name [get_property NAME $leaf]
      set ref [get_property REF_NAME $leaf]
      if {[string match GTYE4_* $ref] || [string match BUFG* $ref] ||
          [string match IBUFDS_GTE4 $ref] || [string match *reset_tree* $leaf_name] ||
          [string match *session* $leaf_name]} {
        lappend excluded [list $leaf_name REF_NAME=$ref]
      }
    }
  }
}
set details [open [file join $archive failure_details.txt] w]
puts $details "decision=STOPPED_BEFORE_PHYS_OPT_ROUTE"
puts $details "reason=mandatory placement containment gate failed"
puts $details "placed_dcp_sha256=[lindex [split [exec sha256sum $placed]] 0]"
puts $details "placed_summary=roots256 leaves134773 constants649 misplaced257 mixed5 duplicates0 excluded10 WNS=-1.089 bus_skew_groups28"
puts $details "excluded_count=[llength $excluded]"
foreach item $excluded {puts $details "excluded=$item"}
puts $details "no_bitstream=true"
puts $details "no_routed_audit=true"
puts $details "no_hardware_access=true"
close $details
close_design

set status_file [open [file join $archive final_status.txt] w]
puts $status_file "progress=60%"
puts $status_file "status=ERROR: placement hook failed containment; stopped before phys_opt_design"
close $status_file
puts "PASS: archived stopped all-links v1 KEEP_HIERARCHY placement attempt"
