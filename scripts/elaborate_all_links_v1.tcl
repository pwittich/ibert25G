# RTL-only elaboration gate: no synthesis run, implementation, or bitstream.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
set xpr [file join $repo_dir build gt_test_all_links_v1 gt_test_all_links_v1.xpr]
if {![file isfile $xpr]} {error "Missing $xpr"}
open_project $xpr
if {[get_property TOP [get_filesets sources_1]] ne "gt_test_all_links_v1_top"} {
  error "Wrong all-links top"
}
set elf_files {}
foreach f [get_files -all -quiet *.elf] {
  if {![get_property IS_GENERATED $f]} {lappend elf_files $f}
}
if {[llength $elf_files] != 1 ||
    [file tail [lindex $elf_files 0]] ne "gt_test_all_links_v1.elf"} {
  error "Expected one matching all-links ELF, got $elf_files"
}
synth_design -rtl -rtl_skip_mlo -name all_links_v1_rtl
set channels [get_cells -hier -quiet -filter {REF_NAME == GTYE4_CHANNEL}]
set commons [get_cells -hier -quiet -filter {REF_NAME == GTYE4_COMMON}]
if {[llength $channels] != 112 || [llength $commons] != 28} {
  error "Expected 112 channels and 28 commons, got [llength $channels]/[llength $commons]"
}
set refbuf [get_cells -hier -quiet -filter \
  {REF_NAME == IBUFDS_GTE4 && NAME =~ *u_refclk_buffers/g_refclk*}]
if {[llength $refbuf] != 12} {
  error "Expected 12 managed-GT physical REFCLK buffers, got [llength $refbuf]"
}
if {[llength [get_cells -hier -quiet -filter \
  {REF_NAME =~ *ibert* || REF_NAME =~ *IBERT* || REF_NAME =~ *c2c* || REF_NAME =~ *C2C*}]] != 0} {
  error "Forbidden IBERT/C2C hierarchy present"
}
puts "PASS: all-links v1 RTL elaboration: 28 managed quads, 12 REFCLK buffers, no IBERT/C2C, one ELF"
