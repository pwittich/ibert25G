set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
if {![info exists endpoint] || $endpoint ni {1 2}} {error "endpoint must be 1 or 2"}
set name gt_test_direct_quad_v6_f${endpoint}
open_project [file join $repo_dir build $name ${name}.xpr]
if {[get_property TOP [get_filesets sources_1]] ne "${name}_top"} {error "Wrong endpoint top"}
foreach f [get_files -of_objects [get_filesets constrs_1]] {
  if {[file tail $f] eq "board_pins.xdc" || [string match *native_left* $f] ||
      [string match *managed_quad124_gt* $f]} {set_property IS_ENABLED false $f}
}
foreach f [get_files -all -quiet *.elf] {
  if {[string match gt_test_firefly1*.elf [file tail $f]]} {remove_files $f}
}
set endpoint_elf [file join $repo_dir build firmware_direct_quad_v6_f${endpoint} ${name}.elf]
set associated_elfs [get_files -all -quiet *.elf -filter {SCOPED_TO_CELLS != ""}]
if {[llength $associated_elfs] != 1 || [file normalize [lindex $associated_elfs 0]] ne [file normalize $endpoint_elf]} {
  error "Expected exactly the endpoint v6 ELF association, got $associated_elfs"
}
set board [file join $repo_dir constraints direct_quad_v6_f${endpoint}_board.xdc]
if {![llength [get_files -quiet $board]]} {add_files -fileset constrs_1 -norecurse $board}
set_property IS_ENABLED true [get_files $board]
update_compile_order -fileset sources_1
# The endpoint top port list changed to expose only the owned quad, so the
# previous clean synthesis no longer represents the intended design.
reset_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "0%"} {error "Synthesis reset failed"}
puts "PASS: v6 F$endpoint project repaired; legacy ELF/XDC disabled, rebuild required"
