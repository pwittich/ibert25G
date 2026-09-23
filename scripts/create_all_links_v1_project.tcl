# Assemble an independent unbuilt all-links source project by cloning the
# proven all-direct v12 infrastructure and adding the generated left bank.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
source [file join $script_dir all_links_v1_left_support_manifest.tcl]
set reference [file join $repo_dir build gt_test_direct_all_v7r3 gt_test_direct_all_v7r3.xpr]
set project_name gt_test_all_links_v1
set project_dir [file join $repo_dir build $project_name]
set elf [file join $repo_dir build firmware_all_links_v1 gt_test_all_links_v1.elf]
set left_ip_root [file join $repo_dir build all_links_v1_left_ip \
  all_links_v1_left_ip.srcs sources_1 ip]
if {![file isfile $reference]} {error "Missing v12 reference project $reference"}
if {![file isfile $elf]} {error "Missing matching ELF $elf"}
if {[file exists $project_dir]} {error "Refusing to overwrite $project_dir"}
open_project $reference
if {[get_property PART [current_project]] ne "xcvu13p-flga2577-2-e"} {error "Part mismatch"}
save_project_as -include_local_ip_cache $project_name $project_dir
close_project
open_project [file join $project_dir ${project_name}.xpr]

foreach f [get_files -all -quiet *.elf] {
  if {![get_property IS_GENERATED $f]} {remove_files $f}
}
foreach name {
  all_links_v1_quad_aggregate all_links_v1_slr_bank managed_all_links_left_quad_wrapper
  gt_test_all_links_v1_top
} {add_files -norecurse [file join $repo_dir src ${name}.sv]}
foreach quad {121 122 123 124 125 126 127 128 129 130 131 132 133 134} {
  set xci [file join $left_ip_root all_links_v1_q${quad}_gt all_links_v1_q${quad}_gt.xci]
  if {![file isfile $xci]} {error "Missing $xci"}
  import_ip -files $xci
}
generate_target all [get_ips all_links_v1_q*_gt]
set wrappers [glob -nocomplain [file join $repo_dir build \
  all_links_v1_left_topology_wrappers *_topology.v]]
if {[llength $wrappers] != 14} {error "Expected 14 left topology wrappers"}
add_files -norecurse $wrappers
add_files -norecurse [all_links_v1_left_support_manifest $repo_dir]
foreach {quad xdc} [all_links_v1_left_xdc_manifest $repo_dir] {
  add_files -fileset constrs_1 -norecurse $xdc
  set xf [get_files $xdc]
  set_property SCOPED_TO_REF all_links_v1_q${quad}_gt_topology $xf
  set_property PROCESSING_ORDER EARLY $xf
}
set board [get_files -quiet [file join $repo_dir constraints board_pins.xdc]]
if {[llength $board] != 1} {error "Expected canonical board_pins.xdc"}
set_property IS_ENABLED true $board
set_property STEPS.OPT_DESIGN.TCL.PRE \
  [file join $script_dir apply_all_links_v1_constraints.tcl] [get_runs impl_1]
add_files -norecurse $elf
set elf_files {}
foreach f [get_files -all -quiet *.elf] {
  if {![get_property IS_GENERATED $f]} {lappend elf_files $f}
}
if {[llength $elf_files] != 1 ||
    [file normalize [lindex $elf_files 0]] ne [file normalize $elf]} {
  error "Expected exactly matching all-links ELF, got $elf_files"
}
set_property SCOPED_TO_REF gt_test_milestone3_bd $elf_files
set_property SCOPED_TO_CELLS microblaze_0 $elf_files
set_property top gt_test_all_links_v1_top [get_filesets sources_1]
set_property generic {} [get_filesets sources_1]
update_compile_order -fileset sources_1
report_ip_status -file [file join $project_dir initial_ip_status.rpt]
puts "PASS: created independent unbuilt all-links v1 project with one matching ELF"
