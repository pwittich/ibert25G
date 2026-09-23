set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
open_project [file join $repo_dir build gt_test_all_links_v1 gt_test_all_links_v1.xpr]
open_run synth_1
foreach slr {0 1 2 3} {
  set bank [get_cells -hier -quiet -filter "NAME =~ *g_bank_slr$slr && REF_NAME =~ all_links_v1_slr_bank*"]
  set bank_name [get_property NAME $bank]
  puts "BANK $slr $bank_name"
  set ctrls [get_cells -hier -quiet -filter "NAME =~ ${bank_name}/u_control_pipeline/controls_out_reg* && REF_NAME =~ FD*"]
  set reset [get_cells -hier -quiet -filter "NAME == ${bank_name}/local_resetn_reg && REF_NAME =~ FD*"]
  set controllers [get_cells -hier -quiet -filter "NAME =~ ${bank_name}/*u_prbs_test_controller* && REF_NAME =~ gt_prbs_test_controller*"]
  set reset_pins [get_pins -hier -quiet -filter "NAME =~ ${bank_name}/*resetn*"]
  puts "CTRLS $ctrls"
  puts "RESET $reset"
  puts "CONTROLLERS $controllers"
  puts "RESET_PINS $reset_pins"
}
