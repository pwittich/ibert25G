# Implementation pre-opt hook for the separate eye image only. A fresh
# synthesis of that target must precede this hook; no historical DCP is saved
# or repurposed by this script. Routed audit must independently prove both
# permitted GT parameter differences and unchanged normal receiver settings.
if {![string match "2023.2*" [version -short]]} {error "Requires Vivado 2023.2"}
if {[get_property PART [current_design]] ne "xcvu13p-flga2577-2-e" ||
    [get_property TOP [current_design]] ne "gt_test_eye_scan_v1_top"} {
  error "Eye initialization requires the separate gt_test_eye_scan_v1_top design"
}
set channels [get_cells -hier -filter {IS_PRIMITIVE && REF_NAME == GTYE4_CHANNEL}]
set commons [get_cells -hier -filter {IS_PRIMITIVE && REF_NAME == GTYE4_COMMON}]
set expected {}
foreach x {0 1} {
  for {set y 4} {$y <= 59} {incr y} {lappend expected GTYE4_CHANNEL_X${x}Y${y}}
}
set actual {}
foreach c $channels {lappend actual [get_property LOC $c]}
if {[llength $channels] != 112 || [llength $commons] != 28 ||
    [lsort $actual] ne [lsort $expected]} {error "Eye GT ownership/topology mismatch"}
set baseline_count 0
set initialized_count 0
foreach c $channels {
  if {[get_property RX_DATA_WIDTH $c] != 80 ||
      [get_property RX_INT_DATAWIDTH $c] != 2 || [get_property RXOUT_DIV $c] != 1} {
    error "Unexpected baseline eye profile on $c"
  }
  if {[string equal -nocase [get_property ES_EYE_SCAN_EN $c] FALSE] &&
      [get_property ES_HORZ_OFFSET $c] eq "12'h000"} {
    incr baseline_count
  } elseif {[string equal -nocase [get_property ES_EYE_SCAN_EN $c] TRUE] &&
      [get_property ES_HORZ_OFFSET $c] eq "12'h800"} {
    incr initialized_count
  } else {error "Incoherent eye initialization on $c"}
}
if {$baseline_count != 112 && $initialized_count != 112} {error "Mixed eye initialization"}
# Do not alter reserved phase attributes, the reset policy or equalizer mode.
set_property ES_EYE_SCAN_EN TRUE $channels
set_property ES_HORZ_OFFSET 12'h800 $channels
foreach c $channels {
  if {![string equal -nocase [get_property ES_EYE_SCAN_EN $c] TRUE] ||
      [get_property ES_HORZ_OFFSET $c] ne "12'h800"} {
    error "Eye initialization readback failed on $c"
  }
  puts "EYE_INIT $c ES_EYE_SCAN_EN=TRUE ES_HORZ_OFFSET=12'h800"
}
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] TRUE]} {
  error "Eye bitstream compression disabled"
}
puts "PASS: separate eye image initialization for 112 GTYs; compression enforced"
