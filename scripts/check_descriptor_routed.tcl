# Check each capture endpoint explicitly: an overriding clock group/false path
# must produce a hard failure, never a spurious successful timing audit.
set descriptor_pins [get_pins -hier -filter {
  NAME =~ */g_lane*.g_managed.u_lane/selected_meta_reg/D ||
  NAME =~ */g_lane*.g_managed.u_lane/prbs_meta_reg*/D}]
if {[llength $descriptor_pins] != 16} { error "Descriptor endpoint count mismatch" }
foreach p $descriptor_pins {
  set path [get_timing_paths -from [get_clocks clk_200] -to $p -max_paths 1]
  if {[llength $path] != 1} { error "Descriptor path hidden by exception: $p" }
  set requirement [get_property REQUIREMENT $path]
  set slack [get_property SLACK $path]
  if {abs($requirement - 3.000) > 0.001 || $slack < 0} {
    error "Descriptor timing failed: $p requirement=$requirement slack=$slack"
  }
  puts "DESCRIPTOR_CAPTURE $p requirement=$requirement slack=$slack"
}
report_timing -from [get_clocks clk_200] -to $descriptor_pins -max_paths 16 \
  -file [file join $report_dir descriptor_capture_timing.rpt]
report_exceptions -ignored -file [file join $report_dir ignored_exceptions.rpt]
puts "Descriptor routed audit passed: 16 timed capture endpoints"
