set repo [file dirname [file dirname [file normalize [info script]]]]
open_checkpoint [file join $repo build gt_test_direct_all_v7r3 gt_test_direct_all_v7r3_synth.dcp]
source [file join $repo scripts apply_direct_all_v7_constraints.tcl]
if {[llength $rx_clocks] != 14 || [llength $tx_clocks] != 14} {
  error "Native-clock inventory changed after constraint application"
}
if {[llength $control_pipeline_d] != 28} {
  error "SLR-local control-pipeline inventory changed after constraint application"
}
set direct_all_v7_wrappers [get_cells -hier -quiet -filter {
  REF_NAME =~ managed_direct_quad_v6_wrapper*}]
if {[llength $direct_all_v7_wrappers] != 14} {
  error "Expected fourteen managed wrapper hierarchy cells, got [llength $direct_all_v7_wrappers]"
}
for {set q 0} {$q < 14} {incr q} {
  set wrapper [direct_all_v7_exact_named_cell $direct_all_v7_wrappers \
    [format {u_all_direct/g_all_direct.g_quad[%d].u_managed_direct} $q] \
    "managed wrapper for quad index $q"]
  set expected [expr {$q < 3 ? "SLR0" : $q < 7 ? "SLR1" : $q < 11 ? "SLR2" : "SLR3"}]
  if {[get_property USER_SLR_ASSIGNMENT $wrapper] ne $expected} {
    error "Quad index $q lacks expected $expected assignment"
  }
  set controller [direct_all_v7_exact_named_cell $direct_all_v7_prbs_controllers \
    [format {u_all_direct/g_all_direct.g_quad[%d].u_managed_direct/u_prbs_test_controller} $q] \
    "PRBS controller for quad index $q"]
  if {[get_property USER_SLR_ASSIGNMENT $controller] ne $expected} {
    error "PRBS controller index $q lacks expected $expected assignment"
  }
}
foreach slr {0 1 2 3} {
  set bank_registers [lindex $direct_all_v7_control_registers_by_slr $slr]
  if {[llength $bank_registers] != 7} {
    error "Control bank $slr does not contain seven preserved registers"
  }
  foreach bank_register $bank_registers {
    set bank_pblocks [get_pblocks -quiet -of_objects $bank_register]
    if {[llength $bank_pblocks] != 1 ||
        [get_property NAME [lindex $bank_pblocks 0]] ne "direct_all_v7_control_slr$slr"} {
      error "Control register [get_property NAME $bank_register] lacks expected SLR$slr pblock"
    }
  }
  set descriptor_registers [lindex $direct_all_v7_descriptor_launch_registers_by_slr $slr]
  set expected_descriptor_registers [lindex {48 64 64 48} $slr]
  if {[llength $descriptor_registers] != $expected_descriptor_registers} {
    error "Descriptor launch bank $slr does not contain $expected_descriptor_registers preserved registers"
  }
  foreach descriptor_register $descriptor_registers {
    set descriptor_cell [get_cells -quiet [list $descriptor_register]]
    if {[llength $descriptor_cell] != 1} {
      error "Descriptor register cannot be re-resolved: $descriptor_register"
    }
    set descriptor_pblocks [get_pblocks -quiet -of_objects $descriptor_cell]
    if {[llength $descriptor_pblocks] != 1 ||
        [get_property NAME [lindex $descriptor_pblocks 0]] ne "direct_all_v7_descriptor_slr$slr"} {
      error "Descriptor register [get_property NAME $descriptor_register] lacks expected SLR$slr pblock"
    }
  }
}
set direct_all_v7_groups [get_cells -hier -quiet -filter {
  REF_NAME =~ direct_all_v7_quad_group_aggregate*}]
if {[llength $direct_all_v7_groups] != 4} {
  error "Expected four registered group reducer hierarchy cells, got [llength $direct_all_v7_groups]"
}
foreach slr {0 1 2 3} {
  set group [direct_all_v7_exact_named_cell $direct_all_v7_groups \
    [format {u_all_direct/g_all_direct.u_quad_aggregate/g_slr%d} $slr] \
    "registered SLR$slr reducer hierarchy"]
  if {[get_property USER_SLR_ASSIGNMENT $group] ne "SLR$slr"} {
    error "Group $slr lacks expected SLR assignment"
  }
}
set final_reduce [direct_all_v7_exact_named_cell \
  [get_cells -hier -quiet -filter {REF_NAME == direct_all_v7_quad_aggregate}] \
  {u_all_direct/g_all_direct.u_quad_aggregate} {global quad reducer hierarchy}]
if {[get_property USER_SLR_ASSIGNMENT $final_reduce] ne "SLR1"} {
  error "Global quad reducer lacks expected SLR1 assignment"
}
puts "PASS: exact RX/TX CDC inventories and all wrapper/controller/control-bank/reducer SLR assignments apply to clean synthesis"
