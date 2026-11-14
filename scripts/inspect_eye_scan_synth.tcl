set repo [file dirname [file dirname [file normalize [info script]]]]
exec sha256sum -c [file join $repo build eye_scan_v1_reports SOURCE_SHA256SUMS]
open_project [file join $repo build gt_test_eye_scan_v1 gt_test_eye_scan_v1.xpr]
open_run synth_1
puts "EYE_SYNTH_DESIGN [current_design]"
report_property [current_design]
puts "EYE_SYNTH_TOP [get_property TOP [get_filesets sources_1]]"
foreach c [get_cells -quiet u_all_links] {report_property $c}
foreach {ref expected} {eye_scan_point 28 eye_scan_drp_arbiter 28 eye_scan_controller 1} {
  puts "EYE_SYNTH_COUNT $ref [llength [get_cells -hier -quiet -filter "REF_NAME =~ ${ref}*"]] expected=$expected"
}
report_utilization -file [file join $repo build eye_scan_v1_reports synth_utilization_diagnostic.rpt]
close_project
