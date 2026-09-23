set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
if {![info exists endpoint] || $endpoint ni {1 2}} {error "endpoint must be 1 or 2"}
set name gt_test_direct_quad_v6_f$endpoint
open_project [file join $repo_dir build $name $name.xpr]
open_run synth_1
puts "DIRECT_V6_ALL_CLOCKS"
foreach c [get_clocks] {puts "[get_property NAME $c] [get_property PERIOD $c]"}
foreach pattern {
  *u_lane/selected_meta_reg/C
  *u_lane/prbs_meta_reg*/C
  *session_meta_reg/C
  *session_sync_reg/C
} {
  puts "DIRECT_V6_PINS $pattern"
  foreach p [get_pins -hier -filter "NAME =~ $pattern"] {
    puts "$p => [get_clocks -of_objects $p]"
  }
}
puts "DIRECT_V6_ELFS"
foreach f [get_files -quiet *.elf] {
  puts "$f scoped_ref=[get_property SCOPED_TO_REF $f] scoped_cells=[get_property SCOPED_TO_CELLS $f]"
}
