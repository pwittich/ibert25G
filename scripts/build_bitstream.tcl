set script_dir [file dirname [file normalize [info script]]]
source [file join $script_dir create_project.tcl]
generate_target all [get_ips]
export_ip_user_files -of_objects [get_ips] -no_script -sync -force -quiet
launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} { error "Synthesis failed" }
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} { error "Implementation failed" }
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
puts "Bitstream: [file join $impl_dir top.bit]"
