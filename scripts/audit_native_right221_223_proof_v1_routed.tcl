# Routed audit for the isolated topology proof.  It uses the generic site
# audit plus checks that all six dedicated route nets have nonzero fanout.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set native_proof_checkpoint [file join $repo_dir build gt_native_right221_223_proof_v1 \
  gt_native_right221_223_proof_v1_routed.dcp]
source [file join $script_dir audit_native_right221_223_routed.tcl]

# Emit a structural evidence report from the routed checkpoint.  This is
# deliberately a report-only first pass: the concrete GT primitive pin names
# are versioned/generated-IP details, so the subsequent assertion will be
# written against the names observed here rather than guessed.
open_checkpoint $native_proof_checkpoint
if {[get_property BITSTREAM.GENERAL.COMPRESS [current_design]] ne "TRUE"} {
  error "Native proof bitstream compression is not enabled"
}

# A generated wrapper's bit index is normalized to [0] inside each selected
# lane/COMMON wrapper.  Check the routed primitive endpoints, not only the
# source text: q221 consumes q222 through its south route, q222 locally, and
# q223 through its north route.  Each corresponding quartet must be present.
set endpoint_expectations {
  GTYE4_CHANNEL_X1Y4  GTSOUTHREFCLK0
  GTYE4_CHANNEL_X1Y5  GTSOUTHREFCLK0
  GTYE4_CHANNEL_X1Y6  GTSOUTHREFCLK0
  GTYE4_CHANNEL_X1Y7  GTSOUTHREFCLK0
  GTYE4_CHANNEL_X1Y8  GTREFCLK0
  GTYE4_CHANNEL_X1Y9  GTREFCLK0
  GTYE4_CHANNEL_X1Y10 GTREFCLK0
  GTYE4_CHANNEL_X1Y11 GTREFCLK0
  GTYE4_CHANNEL_X1Y12 GTNORTHREFCLK0
  GTYE4_CHANNEL_X1Y13 GTNORTHREFCLK0
  GTYE4_CHANNEL_X1Y14 GTNORTHREFCLK0
  GTYE4_CHANNEL_X1Y15 GTNORTHREFCLK0
  GTYE4_COMMON_X1Y1   GTSOUTHREFCLK00
  GTYE4_COMMON_X1Y2   GTREFCLK00
  GTYE4_COMMON_X1Y3   GTNORTHREFCLK00
}
foreach {site ref_pin} $endpoint_expectations {
  if {[string match "GTYE4_COMMON*" $site]} {
    set ref_name GTYE4_COMMON
  } else {
    set ref_name GTYE4_CHANNEL
  }
  set cell [get_cells -hier -quiet -filter "SITE == $site && REF_NAME == $ref_name"]
  if {[llength $cell] != 1} {
    error "Expected one primitive at $site, got [llength $cell]"
  }
  set pin [get_pins -of_objects $cell -quiet -filter "REF_PIN_NAME == $ref_pin"]
  if {[llength $pin] != 1} {
    error "Expected $ref_pin at $site, got [llength $pin] pins"
  }
  set net [get_nets -of_objects $pin -quiet]
  if {[llength $net] != 1 ||
      [string first {gtrefclk00_in[0]} [get_property NAME $net]] < 0} {
    error "$site $ref_pin is not driven by the q222 topology-wrapper refclk"
  }
}
puts "Native q221-223 dedicated q221-south/q222-local/q223-north endpoint audit passed"
set report_file [file join $repo_dir build gt_native_right221_223_proof_v1 \
  audit_native_right221_223_proof_v1_refclk_pins.rpt]
set report [open $report_file w]
puts $report "q221-223 routed dedicated-refclk pin/net inventory"
foreach cell [get_cells -hier -filter {REF_NAME == GTYE4_COMMON || REF_NAME == GTYE4_CHANNEL}] {
  set site [get_property SITE $cell]
  if {[lsearch -exact [concat $native_proof_channel_sites $native_proof_common_sites] $site] < 0} {
    continue
  }
  puts $report "CELL $cell SITE $site REF_NAME [get_property REF_NAME $cell]"
  foreach pin [get_pins -of_objects $cell -quiet -filter {REF_PIN_NAME =~ *REFCLK*}] {
    set net [get_nets -of_objects $pin -quiet]
    puts $report "  PIN [get_property REF_PIN_NAME $pin] DIR [get_property DIRECTION $pin] NET $net"
  }
}
close $report
puts "Wrote routed q221-223 dedicated-refclk inventory: $report_file"
close_design
