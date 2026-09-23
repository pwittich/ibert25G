set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set name gt_test_all_links_v1
set project_dir [file join $repo_dir build $name]
set xpr [file join $project_dir ${name}.xpr]
set dcp [file join $project_dir ${name}_synth.dcp]
set elf [file join $repo_dir build firmware_all_links_v1 ${name}.elf]
set report_dir [file join $repo_dir build all_links_v1_reports keep_hierarchy]
set archive [file join $repo_dir build diagnostic_archive all-links-v1-keep-hierarchy-locality-attempt]
foreach f [list $xpr $dcp $elf] {if {![file isfile $f]} {error "Missing $f"}}
if {[file exists $archive]} {error "Reviewed KEEP_HIERARCHY attempt already exists: $archive"}
file mkdir $archive
file mkdir $report_dir
open_project $xpr
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Fresh synthesis is not complete"}
if {[get_property PROGRESS [get_runs impl_1]] ne "0%"} {
  error "Implementation is not fresh; refusing rerun: [get_property PROGRESS [get_runs impl_1]]"
}
set expected_hook [file normalize [file join $script_dir apply_all_links_v1_constraints.tcl]]
if {[file normalize [get_property STEPS.OPT_DESIGN.TCL.PRE [get_runs impl_1]]] ne $expected_hook} {
  error "Wrong opt_design pre-hook"
}
set_property STEPS.PLACE_DESIGN.TCL.PRE \
  [file normalize [file join $script_dir verify_all_links_v1_keep_hierarchy_opted.tcl]] [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.TCL.PRE \
  [file normalize [file join $script_dir verify_all_links_v1_keep_hierarchy_placed.tcl]] [get_runs impl_1]
set_property STEPS.WRITE_BITSTREAM.TCL.PRE \
  [file normalize [file join $script_dir verify_all_links_v1_keep_hierarchy_routed.tcl]] [get_runs impl_1]
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs impl_1]
set_property INCREMENTAL_CHECKPOINT {} [get_runs impl_1]
set manifest [open [file join $archive attempt_manifest.txt] w]
puts $manifest "synth DCP $dcp"
puts $manifest "synth DCP SHA-256 [lindex [split [exec sha256sum $dcp]] 0]"
puts $manifest "ELF $elf"
puts $manifest "ELF SHA-256 [lindex [split [exec sha256sum $elf]] 0]"
puts $manifest "strategy [get_property STRATEGY [get_runs impl_1]]"
foreach prop {STEPS.OPT_DESIGN.ARGS.DIRECTIVE STEPS.PLACE_DESIGN.ARGS.DIRECTIVE \
    STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE} {
  puts $manifest "$prop [get_property $prop [get_runs impl_1]]"
}
puts $manifest "one clean nonincremental implementation; no hardware access"
close $manifest
puts "ALL_LINKS_V1_KEEP_HIERARCHY_IMPL: launching the single reviewed implementation"
launch_runs impl_1 -to_step write_bitstream -jobs 12
set wait_failed [catch {wait_on_run impl_1} wait_detail]
set run_dir [get_property DIRECTORY [get_runs impl_1]]
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
set progress [get_property PROGRESS [get_runs impl_1]]
set status [get_property STATUS [get_runs impl_1]]
set status_file [open [file join $archive final_status.txt] w]
puts $status_file "progress=$progress"
puts $status_file "status=$status"
close $status_file
if {$wait_failed || $progress ne "100%"} {
  error "Single all-links KEEP_HIERARCHY implementation stopped/failed; archived evidence retained: $wait_detail"
}
open_run impl_1
source [file join $script_dir verify_all_links_v1_keep_hierarchy_routed.tcl]
set routed [file join $project_dir ${name}_routed.dcp]
write_checkpoint -force $routed
set bit [file join $run_dir gt_test_all_links_v1_top.bit]
if {![file isfile $bit]} {error "Missing compressed bitstream $bit"}
file copy -force $bit [file join $project_dir ${name}.bit]
file copy -force $routed [file join $archive [file tail $routed]]
file copy -force $bit [file join $archive [file tail $bit]]
puts "PASS: one clean compressed all-links KEEP_HIERARCHY implementation; independent audit required"
