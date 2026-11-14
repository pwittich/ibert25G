set repo [file dirname [file dirname [file normalize [info script]]]]
open_project [file join $repo build gt_test_eye_scan_v1 gt_test_eye_scan_v1.xpr]
if {[get_property PART [current_project]] ne "xcvu13p-flga2577-2-e"} {error "Part mismatch"}
synth_design -rtl -name eye_rtl -top gt_test_eye_scan_v1_top -part xcvu13p-flga2577-2-e
puts "PASS: full eye-scan v1 RTL elaboration"
close_project
