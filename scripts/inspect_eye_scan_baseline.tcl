# Read-only inspection of the hash-pinned v3 synthesis checkpoint. The sole
# temporary attribute change is in memory; never write a checkpoint or BIT.
set repo [file dirname [file dirname [file normalize [info script]]]]
set dcp [file join $repo build gt_test_all_links_v3 gt_test_all_links_v3_synth.dcp]
set expected 4cdc33364e0e53819f53a9557a4ba333b8158e7b00dd5ac6d53d58d29c1322df
if {![string match "2023.2*" [version -short]]} {error "Requires Vivado 2023.2"}
if {![file isfile $dcp] || [lindex [exec sha256sum $dcp] 0] ne $expected} {
  error "Missing or changed qualified v3 synthesis checkpoint"
}
set reports [file join $repo build eye_scan_baseline_[clock microseconds]]
if {[file exists $reports]} {error "Refusing existing reports $reports"}
file mkdir $reports
open_checkpoint $dcp
if {[get_property PART [current_design]] ne "xcvu13p-flga2577-2-e"} {error "Part mismatch"}
# The production initialization hook must refuse this historical top before
# touching any cell. Positive property probes below remain in memory only.
if {![catch {source [file join $repo scripts apply_eye_scan_initialization.tcl]} rejection] ||
    ![string match {*requires the separate gt_test_eye_scan_v1_top design*} $rejection]} {
  error "Eye initialization did not reject the preserved v3 design: $rejection"
}
set channels [lsort [get_cells -hier -filter {REF_NAME == GTYE4_CHANNEL && IS_PRIMITIVE}]]
if {[llength $channels] != 112} {error "Expected exactly 112 GTY channels"}
set properties {LOC RX_DATA_WIDTH RX_INT_DATAWIDTH RXOUT_DIV ES_EYE_SCAN_EN
  ES_ERRDET_EN ES_HORZ_OFFSET ES_PRESCALE USE_PCS_CLK_PHASE_SEL ES_CLK_PHASE_SEL}
set f [open [file join $reports channels.tsv] {WRONLY CREAT EXCL}]
puts $f [join [linsert $properties 0 CELL] \t]
set sites {}
foreach c $channels {
  set values [list $c]
  foreach p $properties {
    if {[lsearch -exact [list_property $c] $p] < 0} {error "Missing $p on $c"}
    lappend values [get_property $p $c]
  }
  puts $f [join $values \t]
  set loc [get_property LOC $c]
  lappend sites $loc
  if {![regexp {^GTYE4_CHANNEL_X[01]Y([0-9]+)$} $loc -> y] || $y < 4 || $y > 59} {
    error "Unexpected channel location $loc"
  }
  if {[get_property RX_DATA_WIDTH $c] != 80 || [get_property RX_INT_DATAWIDTH $c] != 2 ||
      ![string equal -nocase [get_property ES_EYE_SCAN_EN $c] FALSE]} {
    error "Unexpected baseline receiver/eye configuration on $c"
  }
  # RXLPMEN is a port, not an attribute: record the actual constant driver.
  set pin [get_pins $c/RXLPMEN]
  set net [get_nets -of_objects $pin]
  set drivers [get_pins -of_objects $net -filter {DIRECTION == OUT}]
  set driver_cells [get_cells -of_objects $drivers]
  if {[llength $driver_cells] != 1 || [get_property REF_NAME $driver_cells] ne "VCC"} {
    error "Expected statically enabled LPM on $c, got $driver_cells"
  }
  # Verify Vivado accepts a supported primitive property assignment and
  # readback. This is NOT a new image or permission to patch baseline DCPs.
  set original [get_property ES_EYE_SCAN_EN $c]
  set original_horizontal [get_property ES_HORZ_OFFSET $c]
  set_property ES_EYE_SCAN_EN TRUE $c
  set_property ES_HORZ_OFFSET 12'h800 $c
  if {![string equal -nocase [get_property ES_EYE_SCAN_EN $c] TRUE]} {
    error "Eye enable property did not take effect on $c"
  }
  if {[get_property ES_HORZ_OFFSET $c] ne "12'h800"} {
    error "Phase unification property did not take effect on $c"
  }
  set_property ES_EYE_SCAN_EN $original $c
  set_property ES_HORZ_OFFSET $original_horizontal $c
}
close $f
if {[llength [lsort -unique $sites]] != 112} {error "Duplicate physical channel ownership"}
close_design
if {[lindex [exec sha256sum $dcp] 0] ne $expected} {error "Baseline checkpoint changed"}
puts "PASS: eye scan baseline 112 GTYs, width80/internal2, LPM, eye disabled; enable/phase probes restored, historical-top guard passed"
puts "EYE_BASELINE_REPORTS $reports"
