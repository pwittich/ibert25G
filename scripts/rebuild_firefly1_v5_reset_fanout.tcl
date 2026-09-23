set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set p [file join $repo_dir build gt_test_firefly1_loopback_v5]
open_project [file join $p gt_test_firefly1_loopback_v5.xpr]
# Parent and worker were interrupted through their attached PTY and confirmed
# exited. The run database can retain "Running" after that interruption.
set log_path [file join [get_property DIRECTORY [get_runs impl_1]] runme.log]
set stream [open $log_path r]; set prior_log [read $stream]; close $stream
if {![string match {*'place_design' was cancelled*Exiting Vivado*} $prior_log]} {
  error "expected the explicitly interrupted/exited implementation; inspect before resetting"
}
set archive [file join $repo_dir build diagnostic_archive firefly1-v5-before-reset-fanout]
if {[file exists $archive]} {error "repair already started; inspect existing runs before retry"}
file mkdir $archive
foreach name {gt_test_firefly1_loopback_v5_synth.dcp} {
  if {[file exists [file join $p $name]]} {file copy [file join $p $name] $archive}
}
foreach run {synth_1 impl_1} {
  set log [file join [get_property DIRECTORY [get_runs $run]] runme.log]
  if {[file exists $log]} {file copy $log [file join $archive ${run}.log]}
}
reset_run synth_1
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]
set_property INCREMENTAL_CHECKPOINT {} [get_runs synth_1]
close_project
source [file join $script_dir build_firefly1_loopback_v5_bitstream.tcl]
