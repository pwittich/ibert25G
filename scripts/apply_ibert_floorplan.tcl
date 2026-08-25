proc apply_ibert_floorplan {ip_name wrapper_scope expected_pblocks} {
  set floorplan_files [get_files -all -quiet *${ip_name}/tcl/quad_pblock.tcl]
  if {[llength $floorplan_files] != 1} {
    error "Expected one quad_pblock.tcl for $ip_name, found [llength $floorplan_files]"
  }

  set pblocks_before [get_pblocks -quiet]
  current_instance $wrapper_scope
  if {[catch {source [get_property NAME $floorplan_files]} message options]} {
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

apply_ibert_floorplan ibert_ultrascale_gty_core_l u_ibert/u_ibert_left 14
apply_ibert_floorplan ibert_ultrascale_gty_core_r u_ibert/u_ibert_right 14
