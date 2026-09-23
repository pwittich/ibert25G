set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
foreach {label dcp} [list \
  v1 [file join $repo_dir build diagnostic_archive all-links-v1-postroute-default-physopt-attempt gt_test_all_links_v1_postroute_default_physopt.dcp] \
  v2 [file join $repo_dir build diagnostic_archive all-links-v2-0x00020501-normal-route-timing-failure artifacts gt_test_all_links_v2_synth.dcp]] {
  open_checkpoint $dcp
  puts "IDENTITY $label current_design=[current_design] current_project=[current_project] current_fileset=[current_fileset]"
  foreach prop [list_property [current_design]] {
    if {[regexp -nocase {top|name|part|design} $prop]} {
      puts "IDENTITY $label design_property $prop=[get_property $prop [current_design]]"
    }
  }
  set roots [get_cells -quiet -hier -filter {LEVEL == 0}]
  puts "IDENTITY $label level0_count=[llength $roots] level0=$roots"
  foreach c $roots {
    puts "IDENTITY $label root name=[get_property NAME $c] ref=[get_property REF_NAME $c] orig_ref=[get_property ORIG_REF_NAME $c]"
  }
  close_design
}
