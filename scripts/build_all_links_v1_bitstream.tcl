set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set name gt_test_all_links_v1
set project_dir [file join $repo_dir build $name]
set project_file [file join $project_dir ${name}.xpr]
set elf [file join $repo_dir build firmware_all_links_v1 gt_test_all_links_v1.elf]
set report_dir [file join $repo_dir build all_links_v1_reports]
set reviewed_impl_resume 0
if {[llength $argv] > 1 || ([llength $argv] == 1 &&
    [lindex $argv 0] ne "resume_impl_after_reviewed_constraint_fix")} {
  error "Usage: build_all_links_v1_bitstream.tcl ?resume_impl_after_reviewed_constraint_fix?"
}
if {[llength $argv] == 1} {set reviewed_impl_resume 1}
if {![string match "2023.2*" [version -short]]} {error "All-links v1 requires Vivado 2023.2"}
foreach f [list $project_file $elf] {if {![file isfile $f]} {error "Missing $f"}}
file mkdir $report_dir
open_project $project_file
if {[get_property PART [current_project]] ne "xcvu13p-flga2577-2-e"} {error "Wrong part"}
if {[get_property TOP [get_filesets sources_1]] ne "gt_test_all_links_v1_top"} {error "Wrong top"}
set top_source [file join $repo_dir src gt_test_all_links_v1_top.sv]
set fh [open $top_source r]; set top_text [read $fh]; close $fh
if {[string first {HARDWARE_VERSION(32'h0002_0500)} $top_text] < 0} {error "Wrong all-links hardware version"}
set external_elfs {}
foreach f [get_files -all -quiet *.elf] {if {![get_property IS_GENERATED $f]} {lappend external_elfs $f}}
if {[llength $external_elfs] != 1 ||
    [file normalize [lindex $external_elfs 0]] ne [file normalize $elf] ||
    [get_property SCOPED_TO_REF [lindex $external_elfs 0]] ne "gt_test_milestone3_bd" ||
    [get_property SCOPED_TO_CELLS [lindex $external_elfs 0]] ne "microblaze_0"} {
  error "ELF association is not exact: $external_elfs"
}
set hook [file normalize [get_property STEPS.OPT_DESIGN.TCL.PRE [get_runs impl_1]]]
if {$hook ne [file normalize [file join $script_dir apply_all_links_v1_constraints.tcl]]} {
  error "Wrong implementation pre-hook: $hook"
}
report_ip_status -file [file join $report_dir ip_status_prebuild.rpt]
foreach ip [get_ips -quiet] {
  if {[get_property IS_LOCKED $ip]} {error "Locked IP before build: $ip"}
  if {[get_property UPGRADE_VERSIONS $ip] ne ""} {error "Upgradeable/non-current IP before build: $ip"}
}

set synth_dcp [file join $project_dir ${name}_synth.dcp]
set synth_progress [get_property PROGRESS [get_runs synth_1]]
# save_project_as cloned the proven v12 project including its completed run
# metadata.  A 100%-complete run is resumable only after this target's own
# synthesis preflight has written the canonical all-links checkpoint, or its
# retained run log independently proves a successful all-links synthesis.
if {$synth_progress eq "100%" && ![file isfile $synth_dcp]} {
  set run_log [file join [get_property DIRECTORY [get_runs synth_1]] runme.log]
  set is_clean_all_links 0
  if {[file isfile $run_log]} {
    set fh [open $run_log r]; set run_text [read $fh]; close $fh
    set is_clean_all_links [expr {
      [string first "synthesizing module 'gt_test_all_links_v1_top'" $run_text] >= 0 &&
      [string first "Synthesis finished with 0 errors" $run_text] >= 0
    }]
  }
  if {$is_clean_all_links} {
    puts "ALL_LINKS_V1_BUILD: resuming retained successful all-links synthesis"
  } else {
    puts "ALL_LINKS_V1_BUILD: discarding inherited completed v12 run state"
    reset_run impl_1
    reset_run synth_1
    set synth_progress [get_property PROGRESS [get_runs synth_1]]
  }
}
if {$synth_progress ni {"0%" "100%"}} {
  error "Refusing partial synthesis $synth_progress; preserve and review it"
}
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]
set_property INCREMENTAL_CHECKPOINT {} [get_runs synth_1]
if {$synth_progress eq "0%"} {
  puts "ALL_LINKS_V1_BUILD: launching clean non-incremental synthesis"
  launch_runs synth_1 -jobs 12
  wait_on_run synth_1
}
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
  error "All-links v1 synthesis failed; run evidence retained"
}
open_run synth_1
source [file join $script_dir check_all_links_v1_synth.tcl]
report_utilization -file [file join $report_dir utilization_synth.rpt]
report_cdc -details -file [file join $report_dir cdc_synth.rpt]
report_methodology -file [file join $report_dir methodology_synth.rpt]
write_checkpoint -force $synth_dcp
close_design

set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs impl_1]
set_property INCREMENTAL_CHECKPOINT {} [get_runs impl_1]
set impl_progress [get_property PROGRESS [get_runs impl_1]]
if {$reviewed_impl_resume} {
  set failed_archive [file join $repo_dir build diagnostic_archive all-links-v1-first-route-timing-failure]
  foreach f {gt_test_all_links_v1_top_routed.dcp gt_test_all_links_v1_top.bit
             gt_test_all_links_v1_top_timing_summary_routed.rpt} {
    if {![file isfile [file join $failed_archive $f]]} {
      error "Reviewed implementation resume lacks preserved failed evidence $f"
    }
  }
  if {![file isfile $synth_dcp]} {error "Reviewed implementation resume lacks canonical synth checkpoint"}
  puts "ALL_LINKS_V1_BUILD: reviewed constraint-only resume; resetting implementation only"
  reset_run impl_1
  set impl_progress [get_property PROGRESS [get_runs impl_1]]
}
if {$impl_progress ni {"0%" "100%"}} {
  error "Refusing partial implementation $impl_progress; preserve and review it"
}
if {$impl_progress eq "0%"} {
  puts "ALL_LINKS_V1_BUILD: launching clean non-incremental implementation"
  launch_runs impl_1 -to_step write_bitstream -jobs 12
  wait_on_run impl_1
}
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
  error "All-links v1 implementation failed; run evidence retained"
}
open_run impl_1
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {
  error "Bitstream compression disabled"
}
set timing [report_timing_summary -return_string -file [file join $report_dir timing_summary_routed.rpt]]
report_route_status -file [file join $report_dir route_status.rpt]
report_drc -file [file join $report_dir drc_routed.rpt]
if {![string match {*All user specified timing constraints are met.*} $timing]} {
  error "All-links v1 routed timing failed; evidence retained"
}
foreach v [get_drc_violations -quiet] {
  if {[get_property SEVERITY $v] eq "Error"} {error "Routed DRC error $v"}
}
set routed_dcp [file join $project_dir ${name}_routed.dcp]
write_checkpoint -force $routed_dcp
set run_dir [get_property DIRECTORY [get_runs impl_1]]
set generated_bit [file join $run_dir gt_test_all_links_v1_top.bit]
if {![file isfile $generated_bit]} {error "Missing generated bitstream $generated_bit"}
file copy -force $generated_bit [file join $project_dir ${name}.bit]
puts "PASS: clean compressed all-links v1 implementation; independent routed audit required"
