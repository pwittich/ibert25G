proc apply_ibert_floorplan_m3 {ip_name wrapper_scope expected_pblocks} {
  set floorplan_files [get_files -all -quiet *${ip_name}/tcl/quad_pblock.tcl]
  if {[llength $floorplan_files] == 1} {
    set floorplan_file [get_property NAME [lindex $floorplan_files 0]]
  } elseif {[llength $floorplan_files] == 0} {
    # A run resumed from an optimized checkpoint has no IP files registered.
    set repo_dir [file dirname [file dirname [file normalize [info script]]]]
    set generated_files [glob -nocomplain [file join $repo_dir build \
      gt_test_milestone3 gt_test_milestone3.gen sources_1 ip $ip_name \
      tcl quad_pblock.tcl]]
    if {[llength $generated_files] != 1} {
      error "Expected one generated quad_pblock.tcl for $ip_name, found [llength $generated_files]"
    }
    set floorplan_file [lindex $generated_files 0]
  } else {
    error "Expected one registered quad_pblock.tcl for $ip_name, found [llength $floorplan_files]"
  }
  set pblocks_before [get_pblocks -quiet]
  current_instance $wrapper_scope
  if {[catch {source $floorplan_file} message options]} {
    current_instance
    return -options $options $message
  }
  current_instance
  set created [expr {[llength [get_pblocks -quiet]] - [llength $pblocks_before]}]
  if {$created != $expected_pblocks} {
    error "Expected $expected_pblocks pblocks for $ip_name, created $created"
  }
  puts "Applied $ip_name floorplan under $wrapper_scope: $created pblocks"
}

apply_ibert_floorplan_m3 ibert_ultrascale_gty_core_l \
  g_full_ibert.u_ibert/u_ibert_left 13
apply_ibert_floorplan_m3 ibert_ultrascale_gty_core_r \
  g_full_ibert.u_ibert/u_ibert_right 14
