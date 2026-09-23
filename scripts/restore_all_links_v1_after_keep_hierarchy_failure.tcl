set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set project_dir [file join $repo_dir build gt_test_all_links_v1]
set xpr [file join $project_dir gt_test_all_links_v1.xpr]
set canonical [file join $project_dir gt_test_all_links_v1_synth.dcp]
set baseline [file join $repo_dir build diagnostic_archive \
  all-links-v1-enumerated-leaf-locality-attempt pre_attempt_synth_run_output.dcp]
set failed_archive [file join $repo_dir build diagnostic_archive \
  all-links-v1-keep-hierarchy-locality-attempt keep_hierarchy_synth.dcp]
foreach f [list $xpr $baseline $failed_archive] {
  if {![file isfile $f]} {error "Missing required restoration evidence $f"}
}
open_project $xpr
if {[llength [get_files -quiet [file join $repo_dir constraints all_links_v1_keep_hierarchy.xdc]]]} {
  error "Failed KEEP_HIERARCHY XDC is still active in project"
}
reset_run impl_1
reset_run synth_1
file copy -force $baseline $canonical
close_project
puts "PASS: restored pre-experiment all-links synthesis checkpoint [lindex [split [exec sha256sum $canonical]] 0]; project runs reset and experimental XDC inactive"
