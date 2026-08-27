set script_dir [file dirname [file normalize [info script]]]
set repo_dir   [file dirname $script_dir]
set project    [file join $repo_dir build vu13p_ibert_25g.xpr]

if {![file exists $project]} {
  error "Project not found: $project"
}

open_project $project
source [file join $script_dir configure_ibert_floorplan.tcl]
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
  error "Synthesis is not complete"
}

open_run synth_1
source [file join $script_dir validate_synthesized_design.tcl]
close_design

reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
  error "Implementation failed"
}

open_run impl_1
set bitstream_compress [get_property BITSTREAM.GENERAL.COMPRESS [current_design]]
if {![string equal -nocase $bitstream_compress "TRUE"]} {
  error "Golden IBERT bitstream compression is not enabled"
}
set impl_dir [file join [get_property DIRECTORY [current_project]] vu13p_ibert_25g.runs impl_1]
set timing_rpt [file join $impl_dir top_timing_summary_routed.rpt]
if {![file exists $timing_rpt]} {
  error "Implementation completed but timing report was not found: $timing_rpt"
}
set fh [open $timing_rpt r]
set timing_text [read $fh]
close $fh
if {[regexp {Timing constraints are not met} $timing_text]} {
  error "Implementation completed and wrote a bitstream, but timing failed. See $timing_rpt"
}
puts "Timing constraints met: $timing_rpt"
puts "Bitstream compression: $bitstream_compress"
puts "Bitstream: [file join $impl_dir top.bit]"
