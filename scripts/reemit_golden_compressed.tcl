# Preserve historical implementation; only enable compressed configuration output.
set root [file normalize [file join [file dirname [info script]] ..]]
set dcp $root/build/vu13p_ibert_25g.runs/impl_1/top_routed.dcp
set out $root/build/golden_compressed_20260912
if {[file exists $out]} {error "Refusing to overwrite $out"}
if {[lindex [exec sha256sum $dcp] 0] ne "d16b17be6dde7fe53698a4e3779f4ae0759b8e2935e768f9a9637102a26cc618"} {error "Golden DCP hash mismatch"}
file mkdir $out
open_checkpoint $dcp
if {[get_property PART [current_design]] ne "xcvu13p-flga2577-2-e"} {error "Wrong part"}
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
if {![get_property BITSTREAM.GENERAL.COMPRESS [current_design]]} {error "Compression disabled"}
report_route_status -file $out/route.rpt
report_timing_summary -file $out/timing.rpt
report_bus_skew -file $out/bus_skew.rpt
report_drc -file $out/drc.rpt
report_clocks -file $out/clocks.rpt
report_cdc -file $out/cdc.rpt
report_methodology -file $out/methodology.rpt
foreach delay_type {max min} {
    set paths [get_timing_paths -delay_type $delay_type -max_paths 1]
    if {[llength $paths] != 1 || [get_property SLACK $paths] < 0} {error "Timing check failed"}
}
if {[llength [get_drc_violations -filter {SEVERITY == Error}]]} {error "DRC errors"}
write_bitstream $out/top.bit
puts "COMPRESSED_GOLDEN_SHA256 [exec sha256sum $out/top.bit]"
close_design
