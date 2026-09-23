# Explicit opt-in for isolated diagnostic builds only. Preserve the reference
# project/products; clone completed IP runs and rebuild current top-level RTL.
# Required: target name/generics/ELF, reference project/DCP/SHA-256.
set incremental_start [clock seconds]
if {![string match "2023.2*" [version -short]]} { error "Requires Vivado 2023.2" }
foreach input [list $diagnostic_reference_project $diagnostic_reference_dcp $firmware_elf_override] {
  if {![file isfile $input]} { error "Missing incremental input: $input" }
}
set actual_hash [lindex [exec sha256sum $diagnostic_reference_dcp] 0]
if {$actual_hash ne $diagnostic_reference_sha256} { error "Reference DCP hash mismatch" }
set project_dir [file join $repo_dir build $project_name_override]
if {[file exists $project_dir]} {
  error "Diagnostic destination already exists; do not overwrite evidence: $project_dir"
}
open_project $diagnostic_reference_project
if {[get_property PART [current_project]] ne "xcvu13p-flga2577-2-e" ||
    [get_property TOP [get_filesets sources_1]] ne "gt_test_firefly1_loopback_v2_top"} {
  error "Only matching FireFly-1 projects may use this fast path"
}
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
  error "Reference implementation is incomplete"
}
set reference_gt [get_ips managed_quad124_gt]
foreach {property expected} {
  CONFIG.TX_LINE_RATE 25.78125 CONFIG.RX_LINE_RATE 25.78125
  CONFIG.TX_REFCLK_FREQUENCY 322.265625 CONFIG.RX_REFCLK_FREQUENCY 322.265625
} {
  if {[get_property $property $reference_gt] != $expected} {
    error "Reference GT configuration mismatch: $property"
  }
}
# Explicitly rebind hand-written RTL/XDC after Save As, which may copy sources.
# Generated IP/BD structure remains Vivado-owned and retains its completed runs.
set live_sources {}
foreach dir {src constraints} {
  foreach f [get_files -all] {
    set path [file normalize $f]
    if {[string first "[file normalize [file join $repo_dir $dir]]/" $path] == 0} {
      lappend live_sources [list $dir [file tail $path]]
    }
  }
}
set ip_identities {}
foreach ip [get_ips -all] {
  dict set ip_identities [get_property NAME $ip] [config_ip_cache -get_id $ip]
}
save_project_as -include_local_ip_cache $project_name_override $project_dir
if {[file normalize [get_property DIRECTORY [current_project]]] ne [file normalize $project_dir]} {
  error "Save As did not switch to the new diagnostic project"
}
foreach item $live_sources {
  lassign $item dir name
  set matching [get_files -all -quiet */$name]
  if {[llength $matching]} { remove_files $matching }
  if {$dir eq "constraints"} {
    add_files -fileset constrs_1 -norecurse [file join $repo_dir $dir $name]
  } else {
    add_files -norecurse [file join $repo_dir $dir $name]
  }
}
# Only replace our application ELF, never Vivado-owned mb_bootloop*.elf.
set old_elf {}
foreach f [get_files -all -quiet *.elf] {
  if {[string match gt_test_firefly1_loopback*.elf [file tail $f]]} { lappend old_elf $f }
}
if {[llength $old_elf]} { remove_files $old_elf }
add_files -norecurse $firmware_elf_override
set elf_object [get_files [file tail $firmware_elf_override]]
set_property SCOPED_TO_REF gt_test_milestone3_bd $elf_object
set_property SCOPED_TO_CELLS microblaze_0 $elf_object
set_property generic $top_generics_override [get_filesets sources_1]
foreach ip [get_ips -all] {
  set name [get_property NAME $ip]
  if {![dict exists $ip_identities $name] ||
      [config_ip_cache -get_id $ip] ne [dict get $ip_identities $name]} {
    error "IP identity changed during cloning: $name"
  }
}
foreach run [get_runs] {
  if {[string first "[file normalize $project_dir]/" \
      "[file normalize [get_property DIRECTORY $run]]/"] != 0} {
    error "Run still points outside diagnostic destination: $run"
  }
}
update_compile_order -fileset sources_1
reset_run synth_1
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]
set_property INCREMENTAL_CHECKPOINT {} [get_runs synth_1]
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs impl_1]
set_property INCREMENTAL_CHECKPOINT $diagnostic_reference_dcp [get_runs impl_1]
set incremental_setup_seconds [expr {[clock seconds] - $incremental_start}]
puts "INCREMENTAL_REFERENCE $diagnostic_reference_dcp SHA256=$actual_hash"
puts "INCREMENTAL_SETUP_SECONDS $incremental_setup_seconds"
foreach run [get_runs -filter {IS_SYNTHESIS}] {
  puts "REUSED_RUN_STATUS $run [get_property STATUS $run]"
}
