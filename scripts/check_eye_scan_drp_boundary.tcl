# Read-only structural proof on a loaded eye image. Rebuilt hierarchy need
# not retain cmd_ready port aliases, so inspect real primitive destinations.
set point_roots [get_cells -hier -quiet -filter {REF_NAME =~ eye_scan_point*}]
if {[llength $point_roots] != 28} {error "Expected 28 point sequencers"}
set point_registers [get_cells -hier -quiet -filter {NAME =~ *u_eye_point/* && REF_NAME =~ FD*}]
if {[llength $point_registers] < 3584} {error "Missing point sequencer register boundaries"}
set point_inputs [get_pins -of_objects $point_registers -filter {REF_PIN_NAME == D || REF_PIN_NAME == R || REF_PIN_NAME == CE}]
if {[llength $point_inputs] < [llength $point_registers]} {error "Missing real point register inputs"}
set starts [all_fanin -flat -startpoints_only -only_cells -to $point_inputs]
if {![llength $starts]} {error "Empty point register fanin proof"}
set direct_gt {}
foreach c $starts {
  if {[get_property REF_NAME $c] eq "GTYE4_CHANNEL"} {lappend direct_gt $c}
}
if {[llength $direct_gt]} {error "Unregistered GT output still feeds point sequencers: $direct_gt"}
puts "PASS: real point register boundary; registers=[llength $point_registers], inputs=[llength $point_inputs], startpoints=[llength $starts], direct GT outputs=0"
