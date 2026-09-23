set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
source [file join $script_dir direct_all_v7_generated_support_manifest.tcl]
set name gt_test_direct_all_v7r3
set project [file join $repo_dir build $name ${name}.xpr]
set topology_dir [file join $repo_dir build direct_all_v7_topology_wrappers]
set wrappers [glob -nocomplain [file join $topology_dir *_topology.v]]
if {[llength $wrappers] != 14} {error "Expected fourteen build-local topology wrappers"}
open_project $project
set inherited_board [get_files -quiet [file join $repo_dir constraints board_pins.xdc]]
if {[llength $inherited_board] == 1} {set_property IS_ENABLED false $inherited_board}
set legacy_generated {}
foreach f [get_files -all -quiet] {
  if {[string first "/gt_native_left121_123_functional_ip_v1/" [file normalize $f]] >= 0} {
    lappend legacy_generated $f
  }
}
if {[llength $legacy_generated]} {remove_files $legacy_generated}
add_files -norecurse $wrappers
add_files -norecurse [file join $repo_dir src direct_all_v7_quad_aggregate.sv]
set support [direct_all_v7_support_manifest $repo_dir]
add_files -norecurse $support
foreach {quad xdc} [direct_all_v7_outer_xdc_manifest $repo_dir] {
  add_files -fileset constrs_1 -norecurse $xdc
  set xf [get_files $xdc]
  set_property SCOPED_TO_REF direct_all_v7_q${quad}_gt_topology $xf
  set_property PROCESSING_ORDER EARLY $xf
}
set_property top gt_test_direct_all_v7_top [get_filesets sources_1]
update_compile_order -fileset sources_1
reset_run synth_1
reset_run impl_1
close_project
open_project $project
foreach f $wrappers {
  if {[llength [get_files -quiet [file tail $f]]] != 1} {error "Missing topology wrapper $f after reopen"}
}
foreach f $support {
  set matches {}
  foreach candidate [get_files -all -quiet] {
    if {[file normalize $candidate] eq [file normalize $f]} {lappend matches $candidate}
  }
  if {[llength $matches] != 1} {error "Missing or duplicate generated support source $f after reopen: $matches"}
}
if {[get_property PROGRESS [get_runs synth_1]] ne "0%"} {error "Synthesis was not reset"}
puts "PASS: project updated with fourteen topology wrappers; synthesis reset"
