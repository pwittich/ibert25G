set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set name gt_test_direct_all_v7r3
set project [file join $repo_dir build $name ${name}.xpr]
open_project $project
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Completed clean synthesis is not present"}
if {[get_property PROGRESS [get_runs impl_1]] eq "100%"} {
  # A run can complete routing/bitgen while failing the repository's timing
  # signoff gate.  Permit resetting only that rejected case; never erase a
  # timing-clean completed implementation with this repair helper.
  open_run impl_1
  set failing_paths [get_timing_paths -quiet -slack_lesser_than 0.000 -max_paths 1]
  if {[llength $failing_paths] == 0} {
    error "Refusing to reset a timing-clean completed implementation"
  }
  puts "REPAIR_DIRECT_ALL_V7: resetting rejected completed implementation; WNS [get_property SLACK [lindex $failing_paths 0]] ns"
  close_design
}
set board [get_files -quiet [file join $repo_dir constraints board_pins.xdc]]
if {[llength $board] != 1} {error "Expected canonical board_pins.xdc in cloned project"}
set_property IS_ENABLED false $board
set obsolete [get_files -all -quiet -filter {NAME =~ *direct_all_v7_board.xdc}]
if {[llength $obsolete]} {remove_files $obsolete}
set_property USED_IN_SYNTHESIS false $board
reset_run impl_1
close_project
open_project $project
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Constraint repair invalidated completed synthesis"}
if {[get_property IS_ENABLED [get_files [file join $repo_dir constraints board_pins.xdc]]] ne "0"} {
  error "Canonical broad board constraint is still enabled"
}
if {[get_property STEPS.OPT_DESIGN.TCL.PRE [get_runs impl_1]] ne
    [file join $script_dir apply_direct_all_v7_constraints.tcl]} {
  error "All-direct implementation pre-hook is not installed"
}
puts "PASS: board XDC disabled; filtered board constraints delegated to implementation pre-hook; clean synthesis preserved"
