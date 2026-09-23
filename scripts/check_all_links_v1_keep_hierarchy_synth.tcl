set kh_script_dir [file dirname [file normalize [info script]]]
source [file join $kh_script_dir check_all_links_v1_synth.tcl]

set controllers [get_cells -hier -quiet -filter {REF_NAME =~ gt_prbs_test_controller*}]
if {[llength $controllers] != 28} {
  error "KEEP_HIERARCHY controller count [llength $controllers], expected 28"
}
foreach cell $controllers {
  if {![string equal -nocase [get_property KEEP_HIERARCHY $cell] yes] &&
      ![string equal -nocase [get_property KEEP_HIERARCHY $cell] true]} {
    error "Controller root was not preserved: $cell KEEP_HIERARCHY=[get_property KEEP_HIERARCHY $cell]"
  }
  if {[string equal -nocase [get_property DONT_TOUCH $cell] true] ||
      [string equal -nocase [get_property DONT_TOUCH $cell] yes]} {
    error "Reviewed controller root unexpectedly has DONT_TOUCH: $cell"
  }
}
set fsm_cells [get_cells -hier -quiet -filter {
  NAME =~ *u_prbs_test_controller/state_reg* && REF_NAME =~ FD*}]
if {[llength $fsm_cells] < 140} {error "PRBS FSM inventory unexpectedly small: [llength $fsm_cells]"}
foreach cell $fsm_cells {
  if {[string tolower [get_property FSM_ENCODING $cell]] ne "none"} {
    error "PRBS FSM encoding changed on $cell: [get_property FSM_ENCODING $cell]"
  }
}
puts "PASS: exactly 28 all-links PRBS controller roots preserved with KEEP_HIERARCHY, no controller DONT_TOUCH, FSM_ENCODING=none"
