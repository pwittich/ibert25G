# Routed ownership/electrical gate for the future q221-223 native proof.
# Invoke only after a proof project has generated and routed its checkpoint.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
source [file join $script_dir native_right221_223_config.tcl]
if {![info exists native_proof_checkpoint]} {
  error "Set native_proof_checkpoint to the q221-223 routed DCP before sourcing this audit"
}
if {![file exists $native_proof_checkpoint]} {
  error "Native q221-223 routed checkpoint is missing: $native_proof_checkpoint"
}

open_checkpoint $native_proof_checkpoint
set proof_channels [get_cells -hier -filter {
  REF_NAME == GTYE4_CHANNEL && NAME =~ *native_right221_223_gt*
}]
set proof_commons [get_cells -hier -filter {
  REF_NAME == GTYE4_COMMON && NAME =~ *native_right221_223_gt*
}]
if {[llength $proof_channels] != 12 || [llength $proof_commons] != 3} {
  error "Expected 12 native proof channels and 3 commons, got [llength $proof_channels] and [llength $proof_commons]"
}
set actual_sites {}
foreach cell $proof_channels { lappend actual_sites [get_property SITE $cell] }
if {[lsort $actual_sites] ne [lsort $native_proof_channel_sites]} {
  error "Native q221-223 channel sites are [lsort $actual_sites], expected [lsort $native_proof_channel_sites]"
}
set actual_common_sites {}
foreach cell $proof_commons { lappend actual_common_sites [get_property SITE $cell] }
if {[lsort $actual_common_sites] ne [lsort $native_proof_common_sites]} {
  error "Native q221-223 common sites are [lsort $actual_common_sites], expected [lsort $native_proof_common_sites]"
}
set residual_ibert {}
foreach cell [get_cells -hier -quiet -filter {
  REF_NAME == GTYE4_CHANNEL && NAME =~ *u_ibert_right/*
}] {
  if {[lsearch -exact $native_proof_channel_sites [get_property SITE $cell]] >= 0} {
    lappend residual_ibert $cell
  }
}
if {[llength $residual_ibert] != 0} {
  error "q221-223 sites remain IBERT-owned: $residual_ibert"
}
puts "Native q221-223 routed site ownership audit passed"
close_design
