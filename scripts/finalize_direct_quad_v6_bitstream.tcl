# Remove the inherited v5 application association, then regenerate the final
# bitstream from the already routed, v6-only checkpoint.  Placement/routing is
# intentionally reused; the rejected dual-ELF bitstream is archived separately.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
source [file join $script_dir direct_quad_v6_project_utils.tcl]
if {![info exists endpoint] || $endpoint ni {1 2}} {error "endpoint must be 1 or 2"}
set name gt_test_direct_quad_v6_f${endpoint}
set project_dir [file join $repo_dir build $name]
set project [file join $project_dir ${name}.xpr]
set endpoint_elf [file join $repo_dir build firmware_direct_quad_v6_f${endpoint} ${name}.elf]
set routed [file join $project_dir ${name}_routed.dcp]
set bd [file join $project_dir ${name}.srcs sources_1 bd gt_test_milestone3_bd gt_test_milestone3_bd.bd]
foreach f [list $project $endpoint_elf $routed $bd] {if {![file isfile $f]} {error "Missing $f"}}
direct_v6_strip_inherited_elf $bd
direct_v6_assert_single_bd_elf $bd f${endpoint}
open_project $project
direct_v6_assert_single_bd_elf $bd f${endpoint}
close_project

open_checkpoint $routed
if {![string equal -nocase [get_property BITSTREAM.GENERAL.COMPRESS [current_design]] true]} {error "Compression disabled"}
if {![string match {*All user specified timing constraints are met.*} [report_timing_summary -return_string]]} {error "Routed checkpoint fails timing"}
set bit [file join $project_dir ${name}.bit]
write_bitstream -force $bit
puts "PASS: v6 F$endpoint final bitstream regenerated from routed v6-only checkpoint"
