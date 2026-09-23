# Read-only query of GT Wizard REFCLK-source configuration choices.
#
# Open the generated q221-223 proof project and report the values the 2023.2
# Wizard advertises.  This neither regenerates IP nor starts any design run.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set project [file join $repo_dir build gt_native_right221_223 gt_native_right221_223.xpr]
if {![file exists $project]} {
  error "Missing q221-223 proof project: $project"
}
open_project $project
set native_gt [get_ips -quiet native_right221_223_gt]
if {[llength $native_gt] != 1} {
  error "Expected exactly one q221-223 native Wizard IP"
}
set out [file join [file dirname $project] wizard_refclk_options.rpt]
set fh [open $out w]
foreach property {CONFIG.TX_REFCLK_SOURCE CONFIG.RX_REFCLK_SOURCE} {
  puts $fh "$property current=[get_property $property $native_gt]"
  if {[catch {set values [list_property_value $property $native_gt]} reason]} {
    puts $fh "$property choices=UNAVAILABLE: $reason"
  } else {
    puts $fh "$property choices=$values"
  }
}
close $fh
puts "Wrote $out"
