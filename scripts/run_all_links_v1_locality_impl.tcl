# Exactly one constraint-only all-links v1 implementation attempt.  This
# script resumes the hash-pinned canonical synthesis DCP, stops at routing,
# and deliberately does not generate a bitstream.

set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set name gt_test_all_links_v1
set project_dir [file join $repo_dir build $name]
set xpr [file join $project_dir ${name}.xpr]
set canonical_dcp [file join $project_dir ${name}_synth.dcp]
set elf [file join $repo_dir build firmware_all_links_v1 ${name}.elf]
set report_dir [file join $repo_dir build all_links_v1_reports locality_attempt]
set archive_dir [file join $repo_dir build diagnostic_archive \
  all-links-v1-enumerated-leaf-locality-attempt]
set expected_dcp_hash d643d10fc18e78b108b6e3bf25557218d21ee8c4ee6305246bfe90e74bbbe7d4
set expected_elf_hash 96d3ab54308b894d34f2add001c16d1aa52029bc1474aba506c3017ca6a978ae

if {![string match "2023.2*" [version -short]]} {error "Vivado 2023.2 required"}
foreach f [list $xpr $canonical_dcp $elf] {
  if {![file isfile $f]} {error "Missing required input $f"}
}
proc checked_sha256 {path expected} {
  set actual [lindex [split [exec sha256sum $path]] 0]
  if {$actual ne $expected} {error "SHA-256 mismatch for $path: $actual != $expected"}
  return $actual
}
set dcp_hash [checked_sha256 $canonical_dcp $expected_dcp_hash]
set elf_hash [checked_sha256 $elf $expected_elf_hash]
if {[file exists $archive_dir]} {
  error "Attempt archive already exists; refusing a second implementation: $archive_dir"
}
file mkdir $archive_dir
file mkdir $report_dir

open_project $xpr
if {[get_property PART [current_project]] ne "xcvu13p-flga2577-2-e"} {error "Wrong part"}
if {[get_property TOP [get_filesets sources_1]] ne "gt_test_all_links_v1_top"} {error "Wrong top"}
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
  error "Canonical synthesis run is not complete; synthesis must not be launched"
}
set run_dcp [file join [get_property DIRECTORY [get_runs synth_1]] ${name}_top.dcp]
if {![file isfile $run_dcp]} {error "Missing synthesis-run checkpoint $run_dcp"}
set prior_run_hash [lindex [split [exec sha256sum $run_dcp]] 0]
file copy $run_dcp [file join $archive_dir pre_attempt_synth_run_output.dcp]

set hook [file normalize [get_property STEPS.OPT_DESIGN.TCL.PRE [get_runs impl_1]]]
set expected_hook [file normalize [file join $script_dir apply_all_links_v1_constraints.tcl]]
if {$hook ne $expected_hook} {error "Wrong opt_design pre-hook $hook"}
set place_hook [get_property STEPS.PHYS_OPT_DESIGN.TCL.PRE [get_runs impl_1]]
if {$place_hook ne ""} {error "Unexpected existing phys_opt_design pre-hook $place_hook"}
set_property STEPS.PHYS_OPT_DESIGN.TCL.PRE \
  [file normalize [file join $script_dir verify_all_links_v1_locality_placed.tcl]] \
  [get_runs impl_1]

set strategy [get_property STRATEGY [get_runs impl_1]]
set directives {}
foreach prop {STEPS.OPT_DESIGN.ARGS.DIRECTIVE STEPS.PLACE_DESIGN.ARGS.DIRECTIVE \
    STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE} {
  lappend directives $prop [get_property $prop [get_runs impl_1]]
}

# Preserve existing routed evidence in its already-complete diagnostic archives,
# reset only implementation, then replace the generated synth-run handoff with
# the exact canonical checkpoint required for this reviewed attempt.
reset_run impl_1
file copy -force $canonical_dcp $run_dcp
set resumed_hash [checked_sha256 $run_dcp $expected_dcp_hash]

set meta [open [file join $archive_dir attempt_manifest.txt] w]
puts $meta "canonical synth DCP $canonical_dcp"
puts $meta "canonical synth SHA-256 $dcp_hash"
puts $meta "ELF $elf"
puts $meta "ELF SHA-256 $elf_hash"
puts $meta "pre-attempt generated synth-run SHA-256 $prior_run_hash"
puts $meta "implementation handoff SHA-256 $resumed_hash"
puts $meta "implementation strategy $strategy"
puts $meta "implementation directives $directives"
puts $meta "synthesis was not reset or launched"
puts $meta "hardware was not accessed"
close $meta

set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs impl_1]
set_property INCREMENTAL_CHECKPOINT {} [get_runs impl_1]
puts "ALL_LINKS_V1_LOCALITY_IMPL: launching the single route-only implementation"
launch_runs impl_1 -to_step route_design -jobs 12
wait_on_run impl_1
set progress [get_property PROGRESS [get_runs impl_1]]
set status [get_property STATUS [get_runs impl_1]]
puts "ALL_LINKS_V1_LOCALITY_IMPL: completed with progress=$progress status=$status"
if {$progress ne "100%"} {
  file copy -force [file join [get_property DIRECTORY [get_runs impl_1]] runme.log] \
    [file join $archive_dir runme.log]
  error "All-links v1 route-only implementation failed; evidence retained"
}

set run_dir [get_property DIRECTORY [get_runs impl_1]]
foreach f [glob -nocomplain -directory $run_dir *] {
  set tail [file tail $f]
  if {[file isfile $f] && ([string match *.dcp $tail] || [string match *.rpt $tail] ||
      $tail eq "runme.log" || $tail eq "vivado.pb" || $tail eq "vivado.jou")} {
    file copy -force $f [file join $archive_dir $tail]
  }
}

open_run impl_1
report_timing_summary -max_paths 100 -report_unconstrained \
  -file [file join $report_dir timing_summary_routed.rpt]
report_route_status -file [file join $report_dir route_status_routed.rpt]
report_drc -file [file join $report_dir drc_routed.rpt]
report_bus_skew -warn_on_violation -file [file join $report_dir bus_skew_routed.rpt]
report_clock_interaction -delay_type min_max \
  -file [file join $report_dir clock_interaction_routed.rpt]
write_checkpoint -force [file join $archive_dir ${name}_enumerated_locality_routed.dcp]
foreach f [glob -nocomplain -directory $report_dir *] {
  if {[file isfile $f]} {file copy -force $f [file join $archive_dir [file tail $f]]}
}

puts "ALL_LINKS_V1_LOCALITY_IMPL: route evidence archived; no bitstream generated"
