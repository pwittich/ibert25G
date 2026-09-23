set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set name gt_test_all_links_v1
set project_dir [file join $repo_dir build $name]
set xpr [file join $project_dir ${name}.xpr]
set elf [file join $repo_dir build firmware_all_links_v1 ${name}.elf]
set report_dir [file join $repo_dir build all_links_v1_reports slr_bank]
foreach f [list $xpr $elf] {if {![file isfile $f]} {error "Missing $f"}}
file mkdir $report_dir
open_project $xpr
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
  error "Fresh all-links SLR-bank synthesis is unavailable"
}
open_run synth_1

set banks [get_cells -hier -quiet -filter {REF_NAME =~ all_links_v1_slr_bank*}]
if {[llength $banks] != 4} {error "Bank root count [llength $banks], expected 4"}
set expected_counts {6 8 8 6}
for {set slr 0} {$slr < 4} {incr slr} {
  set bank [get_cells -hier -quiet -filter "NAME =~ *g_bank_slr$slr && REF_NAME =~ all_links_v1_slr_bank*"]
  if {[llength $bank] != 1} {error "Missing unique bank SLR$slr: $bank"}
  if {![get_property KEEP_HIERARCHY $bank]} {error "Bank SLR$slr lacks KEEP_HIERARCHY"}
  if {[string equal -nocase [get_property DONT_TOUCH $bank] "true"]} {error "Bank SLR$slr has forbidden DONT_TOUCH"}
  set bank_name [get_property NAME $bank]
  set ctrls [get_cells -hier -quiet -filter "NAME =~ ${bank_name}/u_control_pipeline/controls_out_reg* && REF_NAME =~ FD*"]
  set local_reset [get_cells -hier -quiet -filter "NAME == ${bank_name}/local_resetn_reg && REF_NAME =~ FD*"]
  set controllers [get_cells -hier -quiet -filter "NAME =~ ${bank_name}/*/u_prbs_test_controller && REF_NAME =~ gt_prbs_test_controller*"]
  set expected [lindex $expected_counts $slr]
  if {[llength $ctrls] != 7 || [llength $local_reset] != 1 || [llength $controllers] != $expected} {
    error "SLR$slr controls/reset/controllers [llength $ctrls]/[llength $local_reset]/[llength $controllers], expected 7/1/$expected"
  }
  set wrappers [get_cells -hier -quiet -filter "NAME =~ ${bank_name}/g_left_quad*.u_managed_left || NAME =~ ${bank_name}/g_right_quad*.u_managed_right"]
  if {[llength $wrappers] != $expected} {error "SLR$slr wrapper count [llength $wrappers], expected $expected"}
  set reset_q [get_pins -quiet -of_objects $local_reset -filter {REF_PIN_NAME == Q}]
  set reset_loads [get_pins -quiet -leaf -of_objects [get_nets -quiet -of_objects $reset_q] -filter {DIRECTION == IN}]
  if {![llength $reset_loads]} {error "SLR$slr bank reset has no synthesized loads"}
  foreach load $reset_loads {
    if {![string match "${bank_name}/*" [get_property NAME $load]]} {
      error "Bank reset has nonlocal load: $load"
    }
  }
  puts "SLR_BANK_SYNTH SLR$slr controls=7 reset=1 controllers=$expected wrappers=$expected reset_loads=[llength $reset_loads]"
}
set dont_banks [get_cells -hier -quiet -filter {REF_NAME =~ all_links_v1_slr_bank* && DONT_TOUCH == 1}]
if {[llength $dont_banks]} {error "Forbidden bank DONT_TOUCH: $dont_banks"}
report_utilization -file [file join $report_dir utilization_synth.rpt]
report_cdc -details -file [file join $report_dir cdc_synth.rpt]
report_methodology -file [file join $report_dir methodology_synth.rpt]
set dcp [file join $project_dir ${name}_synth.dcp]
write_checkpoint -force $dcp
set out [open [file join $report_dir synth_manifest.txt] w]
puts $out "DCP $dcp"
puts $out "DCP SHA-256 [lindex [split [exec sha256sum $dcp]] 0]"
puts $out "ELF SHA-256 [lindex [split [exec sha256sum $elf]] 0]"
puts $out "fresh nonincremental synthesis; four bank roots; controls 7/7/7/7; resets 1/1/1/1; controllers 6/8/8/6"
puts $out "hardware not accessed"
close $out
puts "PASS: fresh all-links v1 SLR-bank synthesis and structural preflight"
